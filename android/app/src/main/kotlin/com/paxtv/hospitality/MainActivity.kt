package com.paxtv.hospitality

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.tv.TvInputManager
import android.media.tv.TvInputInfo
import android.media.AudioManager
import android.media.AudioFocusRequest
import android.media.AudioAttributes
import android.app.ActivityManager
import android.net.Uri
import android.util.Base64
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.admin.DevicePolicyManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.content.RestrictionsManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.net.NetworkInterface
import java.util.Collections
import android.widget.Toast
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager

class MainActivity : FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.paxtv.hospitality/device_info"
    private val TV_CONTROL_CHANNEL = "com.paxtv.hospitality/tv_control"
    private val EMM_CONFIG_CHANNEL = "com.paxtv.hospitality/emm_config"
    private val ACCESSIBILITY_CHANNEL = "com.paxtv.hospitality/accessibility"

    private var tvInputCallback: TvInputManager.TvInputCallback? = null
    private var nsdManager: NsdManager? = null
    private var castNsdListener: NsdManager.RegistrationListener? = null
    private var airplayNsdListener: NsdManager.RegistrationListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var flutterEngineRef: FlutterEngine? = null

    companion object {
        private const val REQUEST_CODE_SET_DEFAULT_HOME = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        setupDeviceOwnerLock()
    }

    /**
     * Requests this app to become the default Home Launcher.
     * - Android 10+ (API 29+): Uses RoleManager to show "Set as Home App" system dialog.
     * - Android < 10: Shows the standard home picker chooser dialog.
     * This mimics the behavior of apps like Nova Launcher / Microsoft Launcher.
     */
    /**
     * Requests this app to become the default Home Launcher on Android TV.
     * Triggers standard Home Chooser / Launcher Picker dialog reliably across TV versions.
     */
    private fun requestDefaultLauncherRole() {
        try {
            val isDefault = isAlreadyDefaultLauncher()
            println("====================================================")
            println("🏠 [HOME LAUNCHER CHECK]: isAlreadyDefaultLauncher = $isDefault")
            println("====================================================")

            if (isDefault) {
                println("✅ [HOME LAUNCHER STATUS]: App is ALREADY Default Home Launcher. Skipping prompt.")
                return
            }

            println("⚠️ [HOME LAUNCHER STATUS]: App is NOT Default Launcher. Triggering Home Launcher Selector...")

            // 1. Android 10+ (API 29+) RoleManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    if (!roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                        try {
                            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                            startActivityForResult(intent, REQUEST_CODE_SET_DEFAULT_HOME)
                            return
                        } catch (_: Exception) {}
                    }
                }
            }

            // 2. Fallback: Action Home Settings
            try {
                val homeSettingsIntent = Intent(android.provider.Settings.ACTION_HOME_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                if (homeSettingsIntent.resolveActivity(packageManager) != null) {
                    startActivity(homeSettingsIntent)
                    return
                }
            } catch (_: Exception) {}

            // 3. Fallback: Android TV Launcher / Main Settings Activity
            val tvSettingIntents = arrayOf(
                Intent("com.android.tv.settings.MainSettings"),
                Intent(android.provider.Settings.ACTION_SETTINGS),
                Intent(android.provider.Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS)
            )
            for (intent in tvSettingIntents) {
                try {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        return
                    }
                } catch (_: Exception) {}
            }

            // 4. Fallback: Intent Chooser
            val selectorIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(Intent.createChooser(selectorIntent, "Select Home Launcher").apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun isAlreadyDefaultLauncher(): Boolean {
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
            val resolveInfo = packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            val currentDefault = resolveInfo?.activityInfo?.packageName
            println("[LauncherCheck] currentDefaultPackage = $currentDefault, myPackage = $packageName")
            
            if (currentDefault != null && currentDefault == packageName) {
                return true
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    if (roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                        return true
                    }
                }
            }
            return false
        } catch (e: Exception) {
            return false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_SET_DEFAULT_HOME) {
            try {
                val bringToFrontIntent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(bringToFrontIntent)
            } catch (_: Exception) {}
        }
    }

    private fun setupDeviceOwnerLock() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminName = MyDeviceAdminReceiver.getComponentName(this)

            if (dpm.isDeviceOwnerApp(packageName)) {
                android.util.Log.i("HotelTV", "Device Owner detected — applying Kiosk lock policies...")
                val intentFilter = IntentFilter(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                val activityName = ComponentName(this, MainActivity::class.java)
                dpm.addPersistentPreferredActivity(adminName, intentFilter, activityName)

                dpm.setLockTaskPackages(adminName, arrayOf(packageName))
                startLockTask()

                enableAdbDebugging()
            } else {
                trySetDeviceOwnerSmartly()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun trySetDeviceOwnerSmartly() {
        val prefs = getSharedPreferences("hotel_tv_device_owner_prefs", Context.MODE_PRIVATE)
        val attempted = prefs.getBoolean("has_attempted_provisioning", false)
        if (attempted) return

        Thread {
            try {
                prefs.edit().putBoolean("has_attempted_provisioning", true).apply()
                val adminComponent = "${packageName}/.MyDeviceAdminReceiver"

                val result1 = runShellCommand("dpm set-device-owner $adminComponent")
                if (result1.contains("Success", ignoreCase = true)) {
                    android.util.Log.i("HotelTV", "Device Owner auto-provisioned successfully!")
                    runOnUiThread { setupDeviceOwnerLock() }
                    return@Thread
                }

                val result2 = runShellCommand("su -c dpm set-device-owner $adminComponent")
                if (result2.contains("Success", ignoreCase = true)) {
                    android.util.Log.i("HotelTV", "Device Owner set via su!")
                    runOnUiThread { setupDeviceOwnerLock() }
                    return@Thread
                }

                runShellCommand("pm grant $packageName android.permission.WRITE_SECURE_SETTINGS")
                val result3 = runShellCommand("dpm set-device-owner $adminComponent")
                if (result3.contains("Success", ignoreCase = true)) {
                    android.util.Log.i("HotelTV", "Device Owner set after permission grant!")
                    runOnUiThread { setupDeviceOwnerLock() }
                    return@Thread
                }
            } catch (_: Exception) {}
        }.start()
    }

    /**
     * Runs a shell command and returns the output + error as a single string.
     */
    private fun runShellCommand(command: String): String {
        return try {
            val process = ProcessBuilder("/system/bin/sh", "-c", command)
                .redirectErrorStream(true)
                .start()
            val output = process.inputStream.bufferedReader().readText()
            process.waitFor()
            android.util.Log.d("HotelTV", "CMD [$command] → $output")
            output
        } catch (e: Exception) {
            android.util.Log.e("HotelTV", "runShellCommand error: ${e.message}")
            ""
        }
    }

    /**
     * Programmatically enables ADB debugging and Developer Options.
     * Only works when this app is the Device Owner.
     * After this runs, you can connect via:
     *   adb connect [TV_IP]:5555
     * without manually enabling Developer Options on the TV.
     */
    private fun enableAdbDebugging() {
        try {
            val cr = contentResolver

            // Enable Developer Options
            android.provider.Settings.Global.putInt(
                cr,
                android.provider.Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 1
            )

            // Enable ADB over USB
            android.provider.Settings.Global.putInt(
                cr,
                android.provider.Settings.Global.ADB_ENABLED, 1
            )

            // Enable ADB over Network/WiFi (port 5555)
            android.provider.Settings.Global.putInt(
                cr,
                "adb_wifi_enabled", 1
            )

            android.util.Log.i("HotelTV", "ADB debugging enabled silently via Device Owner")
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "Failed to enable ADB: ${e.message}")
        }
    }

    private var isDemoModeInMemory: Boolean? = null

    private fun isDemoMode(): Boolean {
        if (isDemoModeInMemory != null) return isDemoModeInMemory == true
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.is_demo_mode", false)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Re-engage Kiosk (Lock Task) mode on every resume (only in Kiosk/Paid mode, NOT Demo mode).
     * Prevents users from escaping back to the TV launcher even if the app
     * was temporarily suspended.
     */
    override fun onResume() {
        super.onResume()
        ExternalLaunchTracker.onReturnedToApp()
        try {
            if (!isDemoMode() && !ExternalLaunchTracker.isRecentlyLaunchedExternal()) {
                val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                if (dpm.isDeviceOwnerApp(packageName)) {
                    startLockTask()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Mute & pause any background audio from YouTube or external cast apps
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .build()
                audioManager?.requestAudioFocus(focusRequest)
            } else {
                @Suppress("DEPRECATION")
                audioManager?.requestAudioFocus(null, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
            }
        } catch (_: Exception) {}

        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            am?.killBackgroundProcesses("com.google.android.youtube.tv")
            am?.killBackgroundProcesses("com.google.android.apps.youtube.tv")
            am?.killBackgroundProcesses("com.google.android.apps.mediashell")
            am?.killBackgroundProcesses("com.google.android.youtube")
        } catch (_: Exception) {}
    }

    private fun prepareForExternalLaunch(timeoutMs: Long = 8000L) {
        ExternalLaunchTracker.notifyExternalLaunch(timeoutMs)
        try {
            stopLockTask()
        } catch (_: Exception) {}
    }

    fun isDishTvDevice(): Boolean {
        return try {
            packageManager.getPackageInfo("com.nes.hometv.dish", 0) != null
        } catch (_: Exception) {
            false
        }
    }

    fun launchDishTvLive(): Boolean {
        prepareForExternalLaunch(30000L)
        TvButtonAccessibilityService.isWatchingLiveTv = true
        return try {
            val intent = Intent("com.nes.hometv.MAIN_ACTION").apply {
                component = ComponentName("com.nes.hometv.dish", "com.nes.hometv.activity.MainActivity")
                putExtra("key_init_open_main_tab_index", "2")
                putExtra("key_init_event_type", 0)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            startActivity(intent)

            TvButtonAccessibilityService.serviceInstance?.triggerDishTvLiveSwitch()
            true
        } catch (e: Exception) {
            android.util.Log.e("HotelTV", "Failed to launch DishTV Live: ${e.message}")
            false
        }
    }

    private fun setupTvInputCallback(flutterEngine: FlutterEngine) {
        flutterEngineRef = flutterEngine
        try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager ?: return
            tvInputCallback = object : TvInputManager.TvInputCallback() {
                override fun onInputStateChanged(inputId: String, state: Int) {
                    android.util.Log.i("HotelTV", "📺 TvInput state changed: $inputId -> state: $state")
                    runOnUiThread {
                        try {
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CONTROL_CHANNEL)
                                .invokeMethod("onTvInputStateChanged", mapOf(
                                    "inputId" to inputId,
                                    "state" to state,
                                    "inputs" to getHdmiModels()
                                ))
                        } catch (_: Exception) {}
                    }
                }
                override fun onInputAdded(inputId: String) {
                    android.util.Log.i("HotelTV", "📺 TvInput added: $inputId")
                    runOnUiThread {
                        try {
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CONTROL_CHANNEL)
                                .invokeMethod("onTvInputStateChanged", mapOf(
                                    "inputId" to inputId,
                                    "state" to 0,
                                    "inputs" to getHdmiModels()
                                ))
                        } catch (_: Exception) {}
                    }
                }
                override fun onInputRemoved(inputId: String) {
                    android.util.Log.i("HotelTV", "📺 TvInput removed: $inputId")
                    runOnUiThread {
                        try {
                            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CONTROL_CHANNEL)
                                .invokeMethod("onTvInputStateChanged", mapOf(
                                    "inputId" to inputId,
                                    "state" to 2,
                                    "inputs" to getHdmiModels()
                                ))
                        } catch (_: Exception) {}
                    }
                }
            }
            tvInputManager.registerCallback(tvInputCallback!!, android.os.Handler(android.os.Looper.getMainLooper()))
            android.util.Log.i("HotelTV", "✅ TvInputCallback successfully registered")
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ Could not register TvInputCallback: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            tvInputCallback?.let {
                (getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager)?.unregisterCallback(it)
            }
        } catch (_: Exception) {}

        try {
            castNsdListener?.let { nsdManager?.unregisterService(it) }
            airplayNsdListener?.let { nsdManager?.unregisterService(it) }
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        setupTvInputCallback(flutterEngine)

        // EMM Config Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMM_CONFIG_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getEmmConfig") {
                result.success(getEmmConfig())
            } else {
                result.notImplemented()
            }
        }

        // Accessibility Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                "openAccessibilitySettings" -> {
                    val opened = openAccessibilitySettings()
                    result.success(opened)
                }
                "requestDefaultLauncher" -> {
                    requestDefaultLauncherRole()
                    result.success(isAlreadyDefaultLauncher())
                }
                "isDefaultLauncher" -> {
                    result.success(isAlreadyDefaultLauncher())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Device Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMacAddress" -> {
                    result.success(getMacAddress())
                }
                "getAndroidId" -> {
                    result.success(getAndroidId())
                }
                "getSerialNumber" -> {
                    result.success(getSerialNumber())
                }
                "getNetworkDetails" -> {
                    result.success(getNetworkDetails())
                }
                "getTvInputs" -> {
                    result.success(getTvInputs())
                }
                "setDeviceName" -> {
                    val name = call.argument<String>("name") ?: ""
                    result.success(setDeviceDisplayName(name))
                }
                "getActualDeviceName" -> {
                    result.success(getActualDeviceName())
                }
                "isDeviceOwner" -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
                    result.success(dpm?.isDeviceOwnerApp(packageName) == true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // TV Control Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    CoroutineScope(Dispatchers.IO).launch {
                        val apps = getInstalledApps()
                        withContext(Dispatchers.Main) {
                            result.success(apps)
                        }
                    }
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("package") ?: call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(launchApp(packageName))
                    } else {
                        result.error("ERROR", "Package name is null", null)
                    }
                }
                "openSettings" -> {
                    result.success(openSettings())
                }
                "openAppDetailsSettings" -> {
                    result.success(openAppDetailsSettings())
                }
                "openHomeSettings" -> {
                    result.success(openHomeSettings())
                }
                "openWifiSettings" -> {
                    result.success(openWifiSettings())
                }
                "getWifiSignalStrength" -> {
                    result.success(getWifiSignalStrength())
                }
                "launchLiveTv", "launchDishTvLive" -> {
                    result.success(launchDishTvLive())
                }
                "launchCast" -> {
                    result.success(launchCast())
                }
                "launchHdmi" -> {
                    val model = call.argument<String>("model")
                    if (model != null) {
                        result.success(launchHdmi(model))
                    } else {
                        result.error("ERROR", "Model is null", null)
                    }
                }
                "getHdmiModels" -> {
                    result.success(getHdmiModels())
                }
                "getLiveTvInputs" -> {
                    result.success(getHdmiModels())
                }
                "launchIptv" -> {
                    result.success(launchIptv())
                }
                "clearConfig" -> {
                    result.success(true)
                }
                "exitToTvHome" -> {
                    prepareForExternalLaunch()
                    try {
                        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_HOME)
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(homeIntent)
                    } catch (_: Exception) {
                        moveTaskToBack(true)
                    }
                    result.success(true)
                }
                "setDemoMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    isDemoModeInMemory = enabled
                    result.success(true)
                }
                "isMediaOrCastActive" -> {
                    var isActive = false
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        if (audioManager?.isMusicActive == true) {
                            isActive = true
                        }
                    } catch (_: Exception) {}
                    try {
                        val fgPkg = TvButtonAccessibilityService.currentForegroundPackage?.lowercase() ?: ""
                        if (fgPkg.contains("cast") || fgPkg.contains("mediashell") || 
                            fgPkg.contains("miracast") || fgPkg.contains("youtube") || 
                            fgPkg.contains("airscreen") || fgPkg.contains("screencast") || 
                            fgPkg.contains("airplay")) {
                            isActive = true
                        }
                    } catch (_: Exception) {}
                    result.success(isActive)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Intercepts all hardware key events.
     * - HOME: Prevents TV launcher from opening; brings our app to foreground.
     * - BACK: Sends to JS WebView bridge instead of exiting app.
     * - MENU: Forwards to JS for custom handling.
     * - DPAD/ENTER/NUMBERS: Pass through to Flutter/WebView.
     */
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode

        // 0. ABSOLUTE ZERO-MS HARDWARE LOCKDOWN:
        // Consume unwanted system/launcher keys immediately so window never yields focus
        val isBlockedKey = when (keyCode) {
            KeyEvent.KEYCODE_SETTINGS, 176,   // Settings
            KeyEvent.KEYCODE_GUIDE, 172,      // TV Guide / Channels
            KeyEvent.KEYCODE_ALL_APPS, 284,   // All Apps Menu
            KeyEvent.KEYCODE_APP_SWITCH, 187, // Recent Apps
            KeyEvent.KEYCODE_TV_INPUT, 178,   // Source / Input
            183, 184, 185, 186,               // Colored keys (Red, Green, Yellow, Blue)
            5103, 5104, 5113, 5115, 5116, 5117, 5118, 5119, 5120, 5121, 5122, 5123, 5124, 5125, 5126, 5128, 5129, 5130, 5131 -> true
            else -> false
        }
        if (isBlockedKey) {
            return true
        }

        val isDemo = isDemoMode()

        // HOME / TV button:
        if (keyCode == KeyEvent.KEYCODE_HOME || keyCode == KeyEvent.KEYCODE_TV) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                if (isDemo) {
                    // In Demo Mode: notify Flutter to handle home navigation (return to app home view or exit to TV launcher)
                    flutterEngine?.dartExecutor?.let { executor ->
                        MethodChannel(executor.binaryMessenger, "com.paxtv.hospitality/back_navigation")
                            .invokeMethod("onHomePressed", null)
                    }
                    return true
                } else {
                    // Kiosk mode: block TV launcher from opening, keep our app in foreground
                    val intent = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(intent)
                    return true
                }
            }
            return true // consume the event - prevents TV launcher in kiosk mode
        }

        // BACK button: send to JS WebView bridge, do NOT exit app directly
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.paxtv.hospitality/back_navigation")
                        .invokeMethod("onBackPressed", null)
                }
            }
            return true // consume - prevents app from exiting directly
        }

        // MENU button: forward to JS for custom menu handling
        if (keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.paxtv.hospitality/back_navigation")
                        .invokeMethod("onMenuPressed", null)
                }
            }
            return true
        }

        // DPAD, ENTER, NUMBER keys: pass to Flutter/WebView
        if (keyCode == KeyEvent.KEYCODE_DPAD_CENTER ||
            keyCode == KeyEvent.KEYCODE_ENTER ||
            keyCode == KeyEvent.KEYCODE_DPAD_UP ||
            keyCode == KeyEvent.KEYCODE_DPAD_DOWN ||
            keyCode == KeyEvent.KEYCODE_DPAD_LEFT ||
            keyCode == KeyEvent.KEYCODE_DPAD_RIGHT ||
            (keyCode >= KeyEvent.KEYCODE_0 && keyCode <= KeyEvent.KEYCODE_9)
        ) {
            return window.superDispatchKeyEvent(event)
        }

        return super.dispatchKeyEvent(event)
    }

    // Prevent back button from ever closing/exiting the app
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // Do nothing - back is handled via JS bridge in dispatchKeyEvent
    }

    private fun getMacAddress(): String {
        try {
            val all = Collections.list(NetworkInterface.getNetworkInterfaces())
            for (nif in all) {
                val macBytes = nif.hardwareAddress ?: continue
                val res1 = StringBuilder()
                for (b in macBytes) {
                    res1.append(String.format("%02X:", b))
                }
                if (res1.isNotEmpty()) {
                    res1.deleteCharAt(res1.length - 1)
                }
                val mac = res1.toString()
                if (mac.isNotEmpty() && mac != "00:00:00:00:00:00" && mac != "02:00:00:00:00:00") {
                    return mac
                }
            }
        } catch (ex: Exception) {
        }
        return ""
    }

    /**
     * Reads the REAL system device name that is currently broadcasted over the network
     * and visible to mobile phones scanning via Google Cast / AirPlay / Bluetooth.
     */
    private fun getActualDeviceName(): String {
        // 1. Settings.Global device_name (Standard on Android TV / Chromecast)
        try {
            val name = android.provider.Settings.Global.getString(contentResolver, "device_name")
            if (!name.isNullOrBlank()) return name
        } catch (_: Exception) {}

        // 2. Settings.Secure bluetooth_name
        try {
            val name = android.provider.Settings.Secure.getString(contentResolver, "bluetooth_name")
            if (!name.isNullOrBlank()) return name
        } catch (_: Exception) {}

        // 3. Bluetooth Adapter name
        try {
            val bt = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (bt != null && !bt.name.isNullOrBlank()) return bt.name
        } catch (_: Exception) {}

        // 4. Fallback: Build.MODEL
        return Build.MODEL ?: ""
    }

    /**
     * Publishes mDNS / NSD network services over the local hotel Wi-Fi so that
     * Android, iOS, Windows and Mac devices scanning for Cast / AirPlay discovery
     * automatically see this TV by its room name without requiring root/ADB or system permissions.
     */
    private fun registerNsdCastService(displayName: String) {
        if (displayName.isBlank()) return
        try {
            // 1. Acquire MulticastLock so WiFi chip processes mDNS broadcast
            if (multicastLock == null) {
                val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                multicastLock = wifi?.createMulticastLock("HotelTvMulticastLock")?.apply {
                    setReferenceCounted(true)
                    acquire()
                }
            }

            if (nsdManager == null) {
                nsdManager = getSystemService(Context.NSD_SERVICE) as? NsdManager
            }
            val mgr = nsdManager ?: return

            // Unregister old Google Cast listener if any
            castNsdListener?.let {
                try { mgr.unregisterService(it) } catch (_: Exception) {}
                castNsdListener = null
            }

            // A. Register Google Cast mDNS service (_googlecast._tcp)
            val castInfo = NsdServiceInfo().apply {
                serviceName = displayName
                serviceType = "_googlecast._tcp"
                port = 8008
                setAttribute("fn", displayName)
                setAttribute("md", Build.MODEL ?: "Smart TV")
                setAttribute("id", getAndroidId())
                setAttribute("st", "1")
            }

            castNsdListener = object : NsdManager.RegistrationListener {
                override fun onServiceRegistered(service: NsdServiceInfo) {
                    android.util.Log.i("HotelTV", "✅ NSD mDNS Google Cast registered as: ${service.serviceName}")
                }
                override fun onRegistrationFailed(service: NsdServiceInfo, errorCode: Int) {
                    android.util.Log.w("HotelTV", "⚠️ NSD Cast registration failed: $errorCode")
                }
                override fun onServiceUnregistered(service: NsdServiceInfo) {
                    android.util.Log.i("HotelTV", "ℹ️ NSD Cast service unregistered")
                }
                override fun onUnregistrationFailed(service: NsdServiceInfo, errorCode: Int) {
                    android.util.Log.w("HotelTV", "⚠️ NSD Cast unregistration failed: $errorCode")
                }
            }
            mgr.registerService(castInfo, NsdManager.PROTOCOL_DNS_SD, castNsdListener)

            // Unregister old AirPlay listener if any
            airplayNsdListener?.let {
                try { mgr.unregisterService(it) } catch (_: Exception) {}
                airplayNsdListener = null
            }

            // B. Register AirPlay / Apple Screen Mirroring mDNS service (_airplay._tcp)
            val airplayInfo = NsdServiceInfo().apply {
                serviceName = displayName
                serviceType = "_airplay._tcp"
                port = 7000
                setAttribute("model", "AppleTV3,2")
                val mac = getMacAddress()
                setAttribute("deviceid", if (mac.isNotEmpty()) mac else "00:11:22:33:44:55")
            }
            airplayNsdListener = object : NsdManager.RegistrationListener {
                override fun onServiceRegistered(service: NsdServiceInfo) {
                    android.util.Log.i("HotelTV", "✅ NSD mDNS AirPlay registered as: ${service.serviceName}")
                }
                override fun onRegistrationFailed(service: NsdServiceInfo, errorCode: Int) {
                    android.util.Log.w("HotelTV", "⚠️ NSD AirPlay registration failed: $errorCode")
                }
                override fun onServiceUnregistered(service: NsdServiceInfo) {}
                override fun onUnregistrationFailed(service: NsdServiceInfo, errorCode: Int) {}
            }
            mgr.registerService(airplayInfo, NsdManager.PROTOCOL_DNS_SD, airplayNsdListener)

        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ registerNsdCastService error: ${e.message}")
        }
    }

    /**
     * Sets the Android device's display name — this is the name that appears on
     * mobile phones when they scan for cast/screen mirroring targets (Miracast, AirPlay, Chromecast).
     * Format: "TV Name (Room No)" — e.g. "Taj TV (Room 106)"
     */
    private fun setDeviceDisplayName(name: String): Boolean {
        if (name.isBlank()) return false
        var success = false

        // 1. Network Service Discovery (mDNS Cast & AirPlay broadcast over local Wi-Fi)
        // Zero permissions needed! Phones on Wi-Fi discover this name for Screen Mirroring/Cast!
        registerNsdCastService(name)

        // 2. DevicePolicyManager (If app is Device Owner, this can set Global settings directly!)
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val admin = MyDeviceAdminReceiver.getComponentName(this)
            if (dpm != null && dpm.isDeviceOwnerApp(packageName)) {
                dpm.setGlobalSetting(admin, "device_name", name)
                android.util.Log.i("HotelTV", "✅ DPM setGlobalSetting device_name to: $name")
                success = true
            }
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ DPM setGlobalSetting error: ${e.message}")
        }

        // 3. Settings.Global device_name (Requires WRITE_SECURE_SETTINGS or system privilege)
        var globalSet = false
        try {
            val res = android.provider.Settings.Global.putString(contentResolver, "device_name", name)
            if (res) {
                android.util.Log.i("HotelTV", "✅ Settings.Global device_name set to: $name")
                globalSet = true
                success = true
            }
        } catch (_: Exception) {}

        // Check if device is already effectively named or contains target name
        val currentActual = getActualDeviceName()
        val isAlreadyNamed = currentActual.equals(name, ignoreCase = true) ||
                             currentActual.contains(name, ignoreCase = true)

        if (globalSet || isAlreadyNamed) {
            val prefs = getSharedPreferences("hotel_tv_device_prefs", Context.MODE_PRIVATE)
            prefs.edit().putString("last_attempted_rename_target", name).apply()
            android.util.Log.i("HotelTV", "🎉 Device already named '$currentActual' (target: '$name'). Skipping settings UI.")
        } else {
            // Only fallback to Settings Accessibility Auto-Pilot if direct write failed AND not already named
            val prefs = getSharedPreferences("hotel_tv_device_prefs", Context.MODE_PRIVATE)
            val lastAttempted = prefs.getString("last_attempted_rename_target", "") ?: ""
            if (lastAttempted != name && !TvButtonAccessibilityService.isRenamingActive) {
                if (isAccessibilityServiceEnabled()) {
                    prefs.edit().putString("last_attempted_rename_target", name).apply()
                    TvButtonAccessibilityService.autoRenameDevice(applicationContext, name)
                } else {
                    android.util.Log.i("HotelTV", "Accessibility not enabled yet; will auto-rename once enabled.")
                    TvButtonAccessibilityService.targetRenameName = name
                }
            } else {
                android.util.Log.d("HotelTV", "Auto-rename already attempted once for target '$name'. Skipping repeated popup.")
            }
        }

        // 4. Settings.Secure bluetooth_name
        try {
            android.provider.Settings.Secure.putString(contentResolver, "bluetooth_name", name)
            android.util.Log.i("HotelTV", "✅ Settings.Secure bluetooth_name set to: $name")
            success = true
        } catch (_: Exception) {}

        // 5. Settings.System device_name
        try {
            android.provider.Settings.System.putString(contentResolver, "device_name", name)
            android.util.Log.i("HotelTV", "✅ Settings.System device_name set to: $name")
            success = true
        } catch (_: Exception) {}

        // 6. Shell Commands (Only if rooted / su available, avoiding SecurityException on standard TV OS)
        Thread {
            try {
                val suCheck = runShellCommand("which su")
                if (suCheck.contains("su")) {
                    val safeName = name.replace("'", "'\\''")
                    runShellCommand("su -c \"settings put global device_name '$safeName'\"")
                    runShellCommand("su -c \"settings put secure bluetooth_name '$safeName'\"")
                    runShellCommand("su -c \"setprop net.hostname '$safeName'\"")
                }
            } catch (_: Exception) {}
        }.start()

        // 7. Bluetooth device name
        try {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? android.bluetooth.BluetoothManager
            val adapter = bluetoothManager?.adapter
            if (adapter != null) {
                adapter.name = name
                android.util.Log.i("HotelTV", "✅ Bluetooth name set to: $name")
                success = true
            }
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ Could not set Bluetooth name: ${e.message}")
        }

        // 8. Wi-Fi Direct (P2P) name — PRIORITY for Miracast / Screen Mirroring discovery
        try {
            val wifiMgr = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val wifiP2pManager = applicationContext.getSystemService(Context.WIFI_P2P_SERVICE)
                    as? android.net.wifi.p2p.WifiP2pManager
            if (wifiP2pManager != null && (wifiMgr?.isWifiEnabled == true)) {
                val channel = wifiP2pManager.initialize(applicationContext, mainLooper, null)
                val method = wifiP2pManager.javaClass.getMethod(
                    "setDeviceName",
                    android.net.wifi.p2p.WifiP2pManager.Channel::class.java,
                    String::class.java,
                    android.net.wifi.p2p.WifiP2pManager.ActionListener::class.java
                )
                fun attemptSetP2pName(retriesLeft: Int) {
                    try {
                        method.invoke(
                            wifiP2pManager,
                            channel,
                            name,
                            object : android.net.wifi.p2p.WifiP2pManager.ActionListener {
                                override fun onSuccess() {
                                    android.util.Log.i("HotelTV", "✅ Wi-Fi Direct (Miracast) name set to: $name")
                                }
                                override fun onFailure(reason: Int) {
                                    if (reason == 2 && retriesLeft > 0) { // 2 = BUSY: Channel binder connecting
                                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                                            attemptSetP2pName(retriesLeft - 1)
                                        }, 1000)
                                    }
                                }
                            }
                        )
                    } catch (e: Exception) {
                        android.util.Log.w("HotelTV", "⚠️ Wi-Fi Direct invoke error: ${e.message}")
                    }
                }
                // Delay 800ms before first invocation so channel initialization finishes
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    attemptSetP2pName(3)
                }, 800)
                success = true
            }
        } catch (e: Exception) {
            android.util.Log.w("HotelTV", "⚠️ Wi-Fi Direct setDeviceName error: ${e.message}")
        }

        return success
    }

    private fun getAndroidId(): String {
        return try {
            android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            ) ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    private fun getSerialNumber(): String {
        // Primary: Secure Android ID (Present on 100% of Android devices across all versions 4.4 to 16+)
        val androidId = getAndroidId()
        if (androidId.isNotEmpty() && androidId != "unknown") {
            return androidId
        }

        // Fallback: Factory Hardware Serial Number
        try {
            val c = Class.forName("android.os.SystemProperties")
            val get = c.getMethod("get", String::class.java)

            val propSerial = get.invoke(c, "ro.serialno") as? String
            if (!propSerial.isNullOrEmpty() && propSerial != "unknown") {
                return propSerial
            }

            val bootSerial = get.invoke(c, "ro.boot.serialno") as? String
            if (!bootSerial.isNullOrEmpty() && bootSerial != "unknown") {
                return bootSerial
            }
        } catch (_: Exception) {}

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    val serial = Build.getSerial()
                    if (!serial.isNullOrEmpty() && serial != "unknown") {
                        return serial
                    }
                } catch (_: SecurityException) {}
            }
        } catch (_: Exception) {}

        try {
            @Suppress("DEPRECATION")
            val serial = Build.SERIAL
            if (!serial.isNullOrEmpty() && serial != "unknown") {
                return serial
            }
        } catch (_: Exception) {}

        return ""
    }
    private fun isHardwareHdmiInput(input: android.media.tv.TvInputInfo): Boolean {
        val idLower = input.id.lowercase()
        if (idLower.contains("tuner") ||
            idLower.contains("composite") ||
            idLower.contains("component") ||
            idLower.contains("vga") ||
            idLower.contains("dvi") ||
            idLower.contains("google.android.videos") ||
            idLower.contains("livetv") ||
            idLower.contains("zee5") ||
            idLower.contains("play.movies") ||
            idLower.contains("netflix") ||
            idLower.contains("preview")) {
            return false
        }
        return input.type == android.media.tv.TvInputInfo.TYPE_HDMI ||
               input.isPassthroughInput ||
               idLower.contains("hdmi")
    }

    private fun isValidDeviceName(name: String?): Boolean {
        if (name.isNullOrBlank()) return false
        val trimmed = name.trim()
        val lower = trimmed.lowercase()
        if (lower.startsWith("hdmi") || 
            lower == "tv" || 
            lower.startsWith("com.") || 
            lower.contains("hw") || 
            lower.contains("/") ||
            lower.contains("google play") ||
            lower.contains("shop")) {
            return false
        }
        return trimmed.length >= 2
    }

    /**
     * Auto-detects connected HDMI CEC device names (e.g., Tata Play, Dish TV, PlayStation, Fire TV)
     * using reflection to support all TV OEM ROMs and Android TV versions safely without crashing.
     */
    private fun getCecDeviceNameForInput(input: TvInputInfo, portNumber: Int): String? {
        // 1. Check TvInputInfo.getHdmiDeviceInfo() reflection
        try {
            val getHdmiDeviceInfoMethod = input.javaClass.getMethod("getHdmiDeviceInfo")
            val hdmiDeviceInfo = getHdmiDeviceInfoMethod.invoke(input)
            if (hdmiDeviceInfo != null) {
                val getDisplayNameMethod = hdmiDeviceInfo.javaClass.getMethod("getDisplayName")
                val name = getDisplayNameMethod.invoke(hdmiDeviceInfo)?.toString()?.trim()
                if (isValidDeviceName(name)) {
                    return name
                }
            }
        } catch (_: Exception) {}

        // 2. Check HdmiControlManager connected devices reflection
        try {
            val hdmiControlManager = getSystemService("hdmi_control")
            if (hdmiControlManager != null) {
                val listMethods = listOf("getConnectedDevicesList", "getAllDeviceInfo", "getDeviceList")
                for (methodName in listMethods) {
                    try {
                        val method = hdmiControlManager.javaClass.getMethod(methodName)
                        val list = method.invoke(hdmiControlManager) as? List<*>
                        if (list != null) {
                            for (item in list) {
                                if (item == null) continue
                                val portId = try {
                                    item.javaClass.getMethod("getPortId").invoke(item) as? Int ?: -1
                                } catch (_: Exception) { -1 }

                                if (portId == portNumber || portNumber <= 0) {
                                    val name = try {
                                        item.javaClass.getMethod("getDisplayName").invoke(item)?.toString()?.trim()
                                    } catch (_: Exception) { null }
                                    if (isValidDeviceName(name)) {
                                        return name
                                    }
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }

                // Check TV client device list
                try {
                    val getTvClientMethod = hdmiControlManager.javaClass.getMethod("getTvClient")
                    val tvClient = getTvClientMethod.invoke(hdmiControlManager)
                    if (tvClient != null) {
                        val devListMethod = tvClient.javaClass.getMethod("getDeviceList")
                        val list = devListMethod.invoke(tvClient) as? List<*>
                        if (list != null) {
                            for (item in list) {
                                if (item == null) continue
                                val portId = try {
                                    item.javaClass.getMethod("getPortId").invoke(item) as? Int ?: -1
                                } catch (_: Exception) { -1 }

                                if (portId == portNumber || portNumber <= 0) {
                                    val name = try {
                                        item.javaClass.getMethod("getDisplayName").invoke(item)?.toString()?.trim()
                                    } catch (_: Exception) { null }
                                    if (isValidDeviceName(name)) {
                                        return name
                                    }
                                }
                            }
                        }
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}

        return null
    }

    private fun isHdmiPortPhysicallyConnected(portNumber: Int): Boolean {
        // 1. Check if an active CEC device is connected to this port
        try {
            val hdmiControlManager = getSystemService("hdmi_control")
            if (hdmiControlManager != null) {
                val listMethods = listOf("getConnectedDevicesList", "getAllDeviceInfo", "getDeviceList")
                for (methodName in listMethods) {
                    try {
                        val method = hdmiControlManager.javaClass.getMethod(methodName)
                        val list = method.invoke(hdmiControlManager) as? List<*>
                        if (list != null) {
                            for (item in list) {
                                if (item == null) continue
                                val portId = try {
                                    item.javaClass.getMethod("getPortId").invoke(item) as? Int ?: -1
                                } catch (_: Exception) { -1 }

                                val physAddr = try {
                                    item.javaClass.getMethod("getPhysicalAddress").invoke(item) as? Int ?: -1
                                } catch (_: Exception) { -1 }

                                val calcPort = if (physAddr > 0) (physAddr ushr 12) and 0x0F else -1

                                if (portId == portNumber || calcPort == portNumber) {
                                    return true
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

        // 2. Check HdmiControlManager.getPortInfo() / getHdmiPortList() via reflection
        try {
            val hdmiControlManager = getSystemService("hdmi_control")
            if (hdmiControlManager != null) {
                val listMethods = listOf("getPortInfo", "getHdmiPortList")
                for (methodName in listMethods) {
                    try {
                        val method = hdmiControlManager.javaClass.getMethod(methodName)
                        val list = method.invoke(hdmiControlManager) as? List<*>
                        if (list != null) {
                            for (portInfo in list) {
                                if (portInfo == null) continue
                                val pId = try {
                                    portInfo.javaClass.getMethod("getId").invoke(portInfo) as? Int ?: -1
                                } catch (_: Exception) { -1 }
                                if (pId == portNumber) {
                                    val isConn = try {
                                        portInfo.javaClass.getMethod("isConnected").invoke(portInfo) as? Boolean ?: false
                                    } catch (_: Exception) { false }
                                    if (isConn) return true
                                }
                            }
                        }
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}

        // 3. Check Linux kernel port-specific DRM sysfs status (NEVER check generic switch/hdmi/state)
        try {
            val specificPaths = listOf(
                "/sys/class/drm/card0-HDMI-A-$portNumber/status",
                "/sys/class/drm/card0-HDMI-A-${portNumber - 1}/status",
                "/sys/devices/platform/display/hdmi/hdmi_$portNumber/status"
            )
            for (path in specificPaths) {
                val file = java.io.File(path)
                if (file.exists() && file.canRead()) {
                    val content = file.readText().trim()
                    if (content.equals("connected", ignoreCase = true) || content == "1") {
                        return true
                    }
                }
            }
        } catch (_: Exception) {}

        return false
    }

    private fun getDeviceTypeName(type: Int?): String? {
        return when (type) {
            1 -> "Set-top Box / DTH"
            4 -> "Playback Device / Console"
            5 -> "Audio System"
            else -> null
        }
    }

    private fun getConnectedDeviceAndPortName(input: TvInputInfo, hdmiSequentialIndex: Int): Pair<String, String> {
        val portName = "HDMI $hdmiSequentialIndex"
        val portNum = hdmiSequentialIndex

        // 1. Check CEC Broadcasted Display Name (Tata Play, Dish TV, Apple TV, etc.)
        var deviceName = getCecDeviceNameForInput(input, portNum)

        // 2. Check TvInputInfo.loadCustomLabel (User or OS renamed label)
        if (deviceName.isNullOrBlank()) {
            val customLabel = try { input.loadCustomLabel(this)?.toString()?.trim() } catch (_: Exception) { null }
            if (isValidDeviceName(customLabel)) {
                deviceName = customLabel
            }
        }

        // 3. Check TvInputInfo.loadLabel
        if (deviceName.isNullOrBlank()) {
            val rawLabel = try { input.loadLabel(this)?.toString()?.trim() } catch (_: Exception) { null }
            if (isValidDeviceName(rawLabel)) {
                deviceName = rawLabel
            }
        }

        return Pair(deviceName ?: "", portName)
    }

    private fun getTvInputs(): List<String> {
        val inputs = mutableListOf<String>()
        try {
            val tvInputManager = applicationContext.getSystemService(Context.TV_INPUT_SERVICE) as? android.media.tv.TvInputManager
            if (tvInputManager != null) {
                val inputList = tvInputManager.tvInputList.filter { isHardwareHdmiInput(it) }
                val sortedList = inputList.sortedBy { it.id }
                var hdmiIndex = 1
                for (input in sortedList) {
                    inputs.add("HDMI $hdmiIndex")
                    hdmiIndex++
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return inputs.distinct().toList()
    }

    private fun getNetworkDetails(): Map<String, String> {
        val resultMap = mutableMapOf<String, String>()
        
        // 1. Primary Method: ConnectivityManager (Works for Wi-Fi AND Ethernet/Emulator)
        try {
            val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
            if (cm != null) {
                val activeNetwork = cm.activeNetwork
                if (activeNetwork != null) {
                    val linkProps = cm.getLinkProperties(activeNetwork)
                    if (linkProps != null) {
                        // Gateway
                        for (route in linkProps.routes) {
                            if (route.isDefaultRoute && route.gateway != null) {
                                resultMap["gateway"] = route.gateway!!.hostAddress ?: ""
                            }
                        }
                        // DNS
                        if (linkProps.dnsServers.isNotEmpty()) {
                            resultMap["dns"] = linkProps.dnsServers.first().hostAddress ?: ""
                        }
                        // Subnet Mask
                        for (linkAddress in linkProps.linkAddresses) {
                            val addr = linkAddress.address
                            if (addr is java.net.Inet4Address && !addr.isLoopbackAddress) {
                                val prefix = linkAddress.prefixLength
                                val mask = -1 shl (32 - prefix)
                                val sn = String.format("%d.%d.%d.%d", 
                                    mask ushr 24 and 0xff, 
                                    mask ushr 16 and 0xff, 
                                    mask ushr 8 and 0xff, 
                                    mask and 0xff)
                                resultMap["subnet"] = sn
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. Fallback Method: WifiManager (If ConnectivityManager fails)
        if (!resultMap.containsKey("gateway") || resultMap["gateway"].isNullOrBlank()) {
            try {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                val dhcpInfo = wifiManager?.dhcpInfo
                if (dhcpInfo != null) {
                    val gw = formatIpAddress(dhcpInfo.gateway)
                    val sn = formatIpAddress(dhcpInfo.netmask)
                    val dn = formatIpAddress(dhcpInfo.dns1)
                    
                    if (gw != "0.0.0.0") resultMap["gateway"] = gw
                    if (sn != "0.0.0.0") resultMap["subnet"] = sn
                    if (dn != "0.0.0.0") resultMap["dns"] = dn
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // 3. Fallback Method: NetworkInterface (Best for Subnet Mask on Ethernet/Emulator)
        if (!resultMap.containsKey("subnet") || resultMap["subnet"].isNullOrBlank()) {
            try {
                val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
                for (intf in interfaces) {
                    for (addr in intf.interfaceAddresses) {
                        val ip = addr.address
                        if (!ip.isLoopbackAddress && ip is java.net.Inet4Address) {
                            val prefix = addr.networkPrefixLength
                            val mask = -1 shl (32 - prefix)
                            val sn = String.format("%d.%d.%d.%d", 
                                mask ushr 24 and 0xff, 
                                mask ushr 16 and 0xff, 
                                mask ushr 8 and 0xff, 
                                mask and 0xff)
                            resultMap["subnet"] = sn
                        }
                    }
                }
            } catch (e: Exception) {}
        }
        
        return resultMap
    }

    private fun formatIpAddress(ip: Int): String {
        return String.format(
            java.util.Locale.US,
            "%d.%d.%d.%d",
            ip and 0xff,
            ip shr 8 and 0xff,
            ip shr 16 and 0xff,
            ip shr 24 and 0xff
        )
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val appsList = mutableListOf<Map<String, Any>>()
        val pm = packageManager
        val addedPackages = mutableSetOf<String>()

        val leanbackIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LEANBACK_LAUNCHER)
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PackageManager.MATCH_ALL
        } else {
            0
        }
        val leanbackInfos = pm.queryIntentActivities(leanbackIntent, flags)

        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launcherInfos = pm.queryIntentActivities(launcherIntent, flags)

        val combinedInfos = (leanbackInfos + launcherInfos)

        for (resolveInfo in combinedInfos) {
            try {
                val packageName = resolveInfo.activityInfo.packageName
                if (packageName == context.packageName) continue
                if (addedPackages.contains(packageName)) continue
                addedPackages.add(packageName)

                val appName = resolveInfo.loadLabel(pm).toString()
                val iconDrawable = resolveInfo.loadIcon(pm)
                val base64Icon = drawableToBase64(iconDrawable)

                val appInfo = mapOf(
                    "name" to appName,
                    "packageName" to packageName,
                    "icon" to base64Icon
                )
                appsList.add(appInfo)
            } catch (e: Exception) {
            }
        }
        return appsList
    }

    private fun drawableToBase64(drawable: Drawable): String {
        return try {
            val targetSize = 72
            val bmp = Bitmap.createBitmap(targetSize, targetSize, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)

            val outputStream = ByteArrayOutputStream()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                bmp.compress(Bitmap.CompressFormat.WEBP_LOSSY, 75, outputStream)
            } else {
                @Suppress("DEPRECATION")
                bmp.compress(Bitmap.CompressFormat.WEBP, 75, outputStream)
            }
            val byteArray = outputStream.toByteArray()
            bmp.recycle()
            "data:image/webp;base64," + Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }

    private fun launchApp(packageName: String): Boolean {
        prepareForExternalLaunch()
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return if (intent != null) {
            // Remove FLAG_ACTIVITY_NEW_TASK so the app launches in OUR task stack.
            // This ensures pressing the BACK button returns to our app, not the TV Home Screen.
            intent.flags = intent.flags and Intent.FLAG_ACTIVITY_NEW_TASK.inv()
            startActivity(intent)
            true
        } else {
            try {
                val storeIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$packageName")).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(storeIntent)
                true
            } catch (_: Exception) {
                try {
                    val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$packageName")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(webIntent)
                    true
                } catch (_: Exception) {
                    Toast.makeText(applicationContext, "App is not installed on this TV", Toast.LENGTH_SHORT).show()
                    false
                }
            }
        }
    }

    private fun openSettings(): Boolean {
        ExternalLaunchTracker.notifyAuthorizedSettingsLaunch()
        prepareForExternalLaunch()
        val tvSettingIntents = listOf(
            Intent(android.provider.Settings.ACTION_SETTINGS),
            Intent("com.android.tv.settings.MainSettings"),
            Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.MainSettings"),
            Intent().setClassName("com.google.android.tv.settings", "com.google.android.tv.settings.MainSettings"),
            Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.SettingsActivity"),
            Intent().setClassName("com.google.android.tv.settings", "com.google.android.tv.settings.SettingsActivity")
        )
        for (intent in tvSettingIntents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {}
        }
        return false
    }

    private fun openAppDetailsSettings(): Boolean {
        prepareForExternalLaunch()
        return try {
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun openHomeSettings(): Boolean {
        prepareForExternalLaunch()
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
                if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                    startActivityForResult(intent, REQUEST_CODE_SET_DEFAULT_HOME)
                    return true
                }
            }

            try {
                val homeSettingsIntent = Intent(android.provider.Settings.ACTION_HOME_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                if (homeSettingsIntent.resolveActivity(packageManager) != null) {
                    startActivity(homeSettingsIntent)
                    return true
                }
            } catch (_: Exception) {}

            val selectorIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(Intent.createChooser(selectorIntent, "Select Home Launcher").apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
            true
        } catch (_: Exception) {
            openSettings()
        }
    }

    private fun launchIptv(): Boolean {
        try {
            // Placeholder: When user selects IPTV, this is triggered.
            // Currently returns true safely. Can be extended to launch an explicit IPTV player app intent.
            // val intent = packageManager.getLaunchIntentForPackage("com.example.iptv")
            // startActivity(intent)
            println("IPTV Launched from Native Android")
            return true
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    private fun openWifiSettings(): Boolean {
        ExternalLaunchTracker.notifyAuthorizedSettingsLaunch()
        prepareForExternalLaunch()
        val pm = packageManager
        val intentsToTry = listOf(
            Intent(android.provider.Settings.ACTION_WIFI_SETTINGS),
            Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS),
            Intent("android.settings.WIFI_SETTINGS"),
            Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.connectivity.NetworkActivity"),
            Intent().setClassName("com.google.android.tv.settings", "com.google.android.tv.settings.connectivity.NetworkActivity"),
            Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.MainSettings"),
            Intent().setClassName("com.google.android.tv.settings", "com.google.android.tv.settings.MainSettings"),
            Intent(android.provider.Settings.ACTION_SETTINGS)
        )
        for (intent in intentsToTry) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(pm) != null) {
                    startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        return false
    }

    private fun getWifiSignalStrength(): Map<String, Any> {
        val resultMap = mutableMapOf<String, Any>()
        try {
            val cm = applicationContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
            if (cm != null) {
                val activeNetwork = cm.activeNetwork
                val capabilities = cm.getNetworkCapabilities(activeNetwork)
                if (capabilities != null) {
                    if (capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET)) {
                        resultMap["connected"] = true
                        resultMap["type"] = "ethernet"
                        resultMap["level"] = 4
                        return resultMap
                    }
                    if (capabilities.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                        var level = 3
                        if (wifiManager != null) {
                            val wifiInfo = wifiManager.connectionInfo
                            if (wifiInfo != null) {
                                val rssi = wifiInfo.rssi
                                level = android.net.wifi.WifiManager.calculateSignalLevel(rssi, 5)
                            }
                        }
                        resultMap["connected"] = true
                        resultMap["type"] = "wifi"
                        resultMap["level"] = level
                        return resultMap
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        resultMap["connected"] = false
        resultMap["type"] = "none"
        resultMap["level"] = 0
        return resultMap
    }

    private fun launchCast(): Boolean {
        prepareForExternalLaunch()
        return try {
            val intent = Intent("android.settings.CAST_SETTINGS").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                val intent = Intent("android.settings.WIFI_DISPLAY_SETTINGS").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    private var lastLaunchHdmiTime: Long = 0

    private fun launchHdmi(port: String): Boolean {
        prepareForExternalLaunch()
        val now = System.currentTimeMillis()
        if (now - lastLaunchHdmiTime < 2000) {
            return true
        }
        lastLaunchHdmiTime = now

        val pTrim = port.trim()
        if (pTrim.equals("Live", ignoreCase = true) || 
            pTrim.equals("Live TV", ignoreCase = true) || 
            pTrim.equals("LiveTV", ignoreCase = true) || 
            pTrim.contains("dish", ignoreCase = true)) {
            return launchDishTvLive()
        }

        return try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            val allInputs = tvInputManager?.tvInputList ?: emptyList()
            val hdmiInputs = allInputs.filter { isHardwareHdmiInput(it) }.sortedBy { it.id }

            if (isDishTvDevice() && hdmiInputs.isEmpty()) {
                return launchDishTvLive()
            }
            var resolvedId: String? = null
            var displayName = port.trim()

            // 1. Exact match with any registered input ID
            val exactMatch = allInputs.firstOrNull { it.id.equals(port.trim(), ignoreCase = true) }
            if (exactMatch != null) {
                resolvedId = exactMatch.id
            }

            // 2. Hardware pin matching (e.g. HW8, HW7, HW6)
            if (resolvedId == null) {
                val hwMatch = Regex("HW([0-9]+)", RegexOption.IGNORE_CASE).find(port)
                if (hwMatch != null) {
                    val hwNum = hwMatch.groupValues[1]
                    val match = allInputs.firstOrNull { it.id.contains("HW$hwNum", ignoreCase = true) }
                    if (match != null) {
                        resolvedId = match.id
                    }
                }
            }

            // 3. Sequential HDMI port index matching (e.g. "HDMI 1", "HDMI 2", "HDMI 3")
            if (resolvedId == null) {
                val hdmiNumMatch = Regex("HDMI\\s*([1-9])", RegexOption.IGNORE_CASE).find(port)
                val seqIndex = hdmiNumMatch?.groupValues?.get(1)?.toIntOrNull()
                if (seqIndex != null && seqIndex in 1..hdmiInputs.size) {
                    resolvedId = hdmiInputs[seqIndex - 1].id
                    displayName = "HDMI $seqIndex"
                } else if (seqIndex != null) {
                    // Match input ID containing this digit (e.g. HW8 for HDMI 8)
                    val match = hdmiInputs.firstOrNull { it.id.contains("$seqIndex") }
                    if (match != null) {
                        resolvedId = match.id
                    }
                }
            }

            // 4. Substring or normalized label matching
            if (resolvedId == null) {
                val normalizedPort = port.lowercase().replace(" ", "").replace("-", "").replace("_", "")
                val match = allInputs.firstOrNull { info ->
                    val normId = info.id.lowercase().replace(" ", "").replace("-", "").replace("_", "")
                    val normLabel = (info.loadLabel(this)?.toString() ?: "").lowercase().replace(" ", "").replace("-", "").replace("_", "")
                    val normCustom = (try { info.loadCustomLabel(this)?.toString() } catch (_: Exception) { "" } ?: "").lowercase().replace(" ", "").replace("-", "").replace("_", "")
                    normId == normalizedPort || normLabel == normalizedPort || normCustom == normalizedPort ||
                    normId.contains(normalizedPort) || normLabel.contains(normalizedPort) || normalizedPort.contains(normId)
                }
                if (match != null) {
                    resolvedId = match.id
                }
            }

            // 5. Safe Fallback: NEVER pass an unresolved arbitrary string into the TV input framework!
            // If resolvedId is not a valid registered input, fallback to the first active hardware HDMI input.
            if (resolvedId == null || allInputs.none { it.id == resolvedId }) {
                resolvedId = hdmiInputs.firstOrNull()?.id ?: allInputs.firstOrNull()?.id
            }

            val finalTargetId = resolvedId
            if (finalTargetId.isNullOrBlank()) {
                if (isDishTvDevice()) {
                    return launchDishTvLive()
                }
                Toast.makeText(applicationContext, "No TV inputs available", Toast.LENGTH_SHORT).show()
                return false
            }

            // Resolve friendly display name
            val targetInput = allInputs.firstOrNull { it.id == finalTargetId }
            if (targetInput != null) {
                val hdmiIdx = hdmiInputs.indexOf(targetInput)
                if (hdmiIdx >= 0) {
                    val portNum = hdmiIdx + 1
                    val cecName = getCecDeviceNameForInput(targetInput, portNum)
                    displayName = if (!cecName.isNullOrBlank()) cecName else "HDMI $portNum"
                } else {
                    val custom = try { targetInput.loadCustomLabel(this)?.toString() } catch (_: Exception) { null }
                    val label = targetInput.loadLabel(this)?.toString()
                    displayName = if (!custom.isNullOrBlank()) custom else (if (!label.isNullOrBlank()) label else "TV Input")
                }
            }

            Toast.makeText(applicationContext, "Opening $displayName...", Toast.LENGTH_SHORT).show()

            val targetUri: Uri = try {
                android.media.tv.TvContract.buildChannelUriForPassthroughInput(finalTargetId)
            } catch (_: Exception) {
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(finalTargetId)}")
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = targetUri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                try {
                    val fallbackIntent = Intent("android.intent.action.VIEW_TV_INPUT").apply {
                        data = targetUri
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(fallbackIntent)
                    true
                } catch (_: Exception) {
                    // Try launching standard TV app
                    val tvAppPackages = listOf("com.android.tv", "com.google.android.tv", "com.mediatek.tvinput", "com.mediatek.tv")
                    for (pkg in tvAppPackages) {
                        val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                        if (launchIntent != null) {
                            startActivity(launchIntent)
                            return true
                        }
                    }
                    Toast.makeText(applicationContext, "$displayName is not connected", Toast.LENGTH_SHORT).show()
                    false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(applicationContext, "Cannot open TV input", Toast.LENGTH_SHORT).show()
            false
        }
    }

    private fun getHdmiModels(): List<Map<String, String>> {
        val inputsList = mutableListOf<Map<String, String>>()
        try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            if (tvInputManager != null) {
                val inputList = tvInputManager.tvInputList.filter { isHardwareHdmiInput(it) }
                // Sort ascending by ID (e.g. HW6, HW7, HW8 -> HDMI 1, HDMI 2, HDMI 3)
                val sortedList = inputList.sortedBy { it.id }
                var hdmiIndex = 1

                for (input in sortedList) {
                    val id = input.id
                    val portNum = hdmiIndex
                    val portName = "HDMI $portNum"
                    hdmiIndex++

                    // 1. Hardware Input State from TvInputManager (Universal Android TV API)
                    val inputState = try {
                        tvInputManager.getInputState(id)
                    } catch (_: Exception) {
                        TvInputManager.INPUT_STATE_DISCONNECTED
                    }

                    // 2. Check CEC broadcasted device name (e.g., Tata Play, Apple TV, Fire TV, PS5)
                    val cecName = getCecDeviceNameForInput(input, portNum)
                    
                    // 3. Fallback physical connection check
                    val isPhysicallyConnectedFallback = isHdmiPortPhysicallyConnected(portNum)

                    // inputState == 0 (CONNECTED): Cable plugged in & active signal present
                    // inputState == 1 (CONNECTED_STANDBY): Cable plugged in, device in standby
                    // inputState == 2 (DISCONNECTED): No cable connected
                    val hasSignal = (inputState == TvInputManager.INPUT_STATE_CONNECTED) || (!cecName.isNullOrBlank())
                    val isConnected = hasSignal || (inputState == TvInputManager.INPUT_STATE_CONNECTED_STANDBY) || isPhysicallyConnectedFallback

                    val statusString = when {
                        hasSignal -> "ACTIVE"
                        isConnected -> "STANDBY"
                        else -> "DISCONNECTED"
                    }

                    val deviceName = if (!cecName.isNullOrBlank()) {
                        cecName
                    } else if (hasSignal) {
                        "Active HDMI ($portName)"
                    } else if (isConnected) {
                        "Standby Device"
                    } else {
                        ""
                    }

                    inputsList.add(mapOf(
                        "id" to id,
                        "label" to portName,
                        "name" to deviceName,
                        "deviceName" to deviceName,
                        "portName" to portName,
                        "model" to id,
                        "value" to id,
                        "type" to "HDMI",
                        "isConnected" to isConnected.toString(),
                        "hasSignal" to hasSignal.toString(),
                        "status" to statusString,
                        "state" to inputState.toString()
                    ))
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return inputsList
    }

    private fun getEmmConfig(): Map<String, String> {
        val configMap = mutableMapOf<String, String>()
        try {
            val myRestrictionsMgr = getSystemService(Context.RESTRICTIONS_SERVICE) as RestrictionsManager
            val appRestrictions = myRestrictionsMgr.applicationRestrictions
            if (appRestrictions != null) {
                if (appRestrictions.containsKey("license_key")) {
                    configMap["license_key"] = appRestrictions.getString("license_key") ?: ""
                }
                if (appRestrictions.containsKey("room_no")) {
                    configMap["room_no"] = appRestrictions.getString("room_no") ?: ""
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return configMap
    }

    private fun prefixLengthToSubnetMask(prefixLength: Int): String {
        if (prefixLength <= 0 || prefixLength > 32) return "255.255.255.0"
        val mask = -0x1 shl (32 - prefixLength)
        return String.format(
            java.util.Locale.US,
            "%d.%d.%d.%d",
            (mask shr 24) and 0xff,
            (mask shr 16) and 0xff,
            (mask shr 8) and 0xff,
            mask and 0xff
        )
    }

    private fun intToIp(ipAddress: Int): String {
        return String.format(
            java.util.Locale.US,
            "%d.%d.%d.%d",
            ipAddress and 0xff,
            ipAddress shr 8 and 0xff,
            ipAddress shr 16 and 0xff,
            ipAddress shr 24 and 0xff
        )
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        try {
            val accessibilityEnabled = android.provider.Settings.Secure.getInt(
                contentResolver,
                android.provider.Settings.Secure.ACCESSIBILITY_ENABLED, 0
            )
            if (accessibilityEnabled == 1) {
                val services = android.provider.Settings.Secure.getString(
                    contentResolver,
                    android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                )
                if (services != null) {
                    val myService1 = "$packageName/com.paxtv.hospitality.TvButtonAccessibilityService"
                    val myService2 = "$packageName/.TvButtonAccessibilityService"
                    val myService3 = "$packageName/"
                    return services.contains(myService1, ignoreCase = true) ||
                           services.contains(myService2, ignoreCase = true) ||
                           services.contains(myService3, ignoreCase = true)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    private fun isTvDevice(): Boolean {
        return try {
            val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? android.app.UiModeManager
            if (uiModeManager?.currentModeType == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION) {
                return true
            }
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)
        } catch (_: Exception) {
            false
        }
    }

    private fun openAccessibilitySettings(): Boolean {
        prepareForExternalLaunch()
        val pm = packageManager
        val sdkVersion = Build.VERSION.SDK_INT
        val isTv = isTvDevice()

        val intentsToTry = mutableListOf<Intent>()

        // 1. Android TV Main Settings (Proven stable across TV OS 9 to 16+ without OEM trampoline crash)
        if (isTv) {
            intentsToTry.add(Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.MainSettings"))
            intentsToTry.add(Intent().setClassName("com.google.android.tv.settings", "com.google.android.tv.settings.MainSettings"))
            intentsToTry.add(Intent("android.settings.SETTINGS"))
            intentsToTry.add(Intent(android.provider.Settings.ACTION_SETTINGS))
        }

        // 2. Mobile / Framework Accessibility Intents (Mobile / Tablet devices)
        if (!isTv) {
            intentsToTry.add(Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS))
            intentsToTry.add(Intent("android.settings.ACCESSIBILITY_SETTINGS"))
        }

        // 3. Fallback TV OEM Activities
        if (isTv && sdkVersion >= Build.VERSION_CODES.R) {
            intentsToTry.add(Intent("android.settings.ACCESSIBILITY_TV_OEM_LINK").setPackage("com.android.tv.settings"))
            intentsToTry.add(Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.oemlink.AccessibilitySettingsActivity"))
            intentsToTry.add(Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.oemlink.AccessibilityServiceActivity"))
        }

        // 4. General Settings Fallbacks (All SDK versions)
        intentsToTry.add(Intent(android.provider.Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS))
        intentsToTry.add(Intent().setClassName("com.android.settings", "com.android.settings.AccessibilitySettings"))
        intentsToTry.add(Intent().setClassName("com.android.settings", "com.android.settings.Settings\$AccessibilitySettingsActivity"))
        intentsToTry.add(Intent().setClassName("com.android.settings", "com.android.settings.Settings"))

        // 5. Package Manager Launch Intent Fallbacks
        val settingsPackages = listOf(
            "com.android.tv.settings",
            "com.google.android.tv.settings",
            "com.android.settings",
            "com.tcl.tv.settings",
            "com.xiaomi.mitv.settings",
            "com.sony.dtv.settings"
        )
        for (pkg in settingsPackages) {
            try {
                val launchIntent = pm.getLaunchIntentForPackage(pkg)
                if (launchIntent != null) {
                    intentsToTry.add(launchIntent)
                }
            } catch (_: Exception) {}
        }

        // Safe execution loop: Try each intent in order of priority
        for (intent in intentsToTry) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(pm) != null) {
                    startActivity(intent)
                    android.util.Log.i("HotelTV", "Successfully launched settings intent [SDK $sdkVersion, isTv=$isTv]: $intent")
                    return true
                }
            } catch (e: Exception) {
                android.util.Log.w("HotelTV", "Failed to launch settings intent: $intent - ${e.message}")
            }
        }

        android.util.Log.e("HotelTV", "No valid settings activity could be resolved on this device [SDK $sdkVersion, isTv=$isTv].")
        return false
    }
}



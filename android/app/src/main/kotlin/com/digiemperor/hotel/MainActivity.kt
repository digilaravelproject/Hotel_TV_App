package com.digiemperor.hotel

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.tv.TvInputManager
import android.media.tv.TvInputInfo
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
import java.io.ByteArrayOutputStream
import java.net.NetworkInterface
import java.util.Collections
import android.widget.Toast

class MainActivity : FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.digiemperor.hotel/device_info"
    private val TV_CONTROL_CHANNEL = "com.digiemperor.hotel/tv_control"
    private val EMM_CONFIG_CHANNEL = "com.digiemperor.hotel/emm_config"
    private val ACCESSIBILITY_CHANNEL = "com.digiemperor.hotel/accessibility"

    companion object {
        private const val REQUEST_CODE_SET_DEFAULT_HOME = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
            if (resultCode == RESULT_OK) {
                Toast.makeText(this, "Hotel TV App set as default launcher!", Toast.LENGTH_SHORT).show()
            }
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

    /**
     * Re-engage Kiosk (Lock Task) mode on every resume.
     * Prevents users from escaping back to the TV launcher even if the app
     * was temporarily suspended.
     */
    override fun onResume() {
        super.onResume()
        try {
            if (!ExternalLaunchTracker.isRecentlyLaunchedExternal()) {
                val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                if (dpm.isDeviceOwnerApp(packageName)) {
                    startLockTask()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun prepareForExternalLaunch() {
        ExternalLaunchTracker.notifyExternalLaunch()
        try {
            stopLockTask()
        } catch (_: Exception) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
                else -> {
                    result.notImplemented()
                }
            }
        }

        // TV Control Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    result.success(getInstalledApps())
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName != null) {
                        result.success(launchApp(packageName))
                    } else {
                        result.error("ERROR", "Package name is null", null)
                    }
                }
                "openSettings" -> {
                    result.success(openSettings())
                }
                "openWifiSettings" -> {
                    result.success(openWifiSettings())
                }
                "getWifiSignalStrength" -> {
                    result.success(getWifiSignalStrength())
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
                "clearConfig" -> {
                    result.success(true)
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

        // HOME / TV button: block TV launcher from opening, keep our app in foreground
        if (keyCode == KeyEvent.KEYCODE_HOME || keyCode == KeyEvent.KEYCODE_TV) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                // Bring our app to front if it somehow went to background
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(intent)
            }
            return true // consume the event - prevents TV launcher
        }

        // BACK button: send to JS WebView bridge, do NOT exit app
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.digiemperor.hotel/back_navigation")
                        .invokeMethod("onBackPressed", null)
                }
            }
            return true // consume - prevents app from exiting
        }

        // MENU button: forward to JS for custom menu handling
        if (keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.digiemperor.hotel/back_navigation")
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

    private fun getNetworkDetails(): Map<String, String> {
        val resultMap = mutableMapOf<String, String>()
        try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
            val dhcpInfo = wifiManager?.dhcpInfo
            if (dhcpInfo != null) {
                resultMap["gateway"] = formatIpAddress(dhcpInfo.gateway)
                resultMap["subnet"] = formatIpAddress(dhcpInfo.netmask)
                resultMap["dns"] = formatIpAddress(dhcpInfo.dns1)
            }
        } catch (e: Exception) {
            e.printStackTrace()
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
        val leanbackInfos = pm.queryIntentActivities(leanbackIntent, 0)

        val launcherIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val launcherInfos = pm.queryIntentActivities(launcherIntent, 0)

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
        val bitmap = if (drawable is BitmapDrawable) {
            drawable.bitmap
        } else {
            val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 128
            val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 128
            val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)
            bmp
        }
        val outputStream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        val byteArray = outputStream.toByteArray()
        return "data:image/png;base64," + Base64.encodeToString(byteArray, Base64.NO_WRAP)
    }

    private fun launchApp(packageName: String): Boolean {
        prepareForExternalLaunch()
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } else {
            false
        }
    }

    private fun openSettings(): Boolean {
        prepareForExternalLaunch()
        return try {
            val intent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun openWifiSettings(): Boolean {
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
        val now = System.currentTimeMillis()
        if (now - lastLaunchHdmiTime < 2000) {
            return true
        }
        lastLaunchHdmiTime = now

        var displayName = port
        if (displayName.contains("/")) {
            displayName = displayName.substringAfterLast('/')
        }
        displayName = displayName.replace("_", " ").trim()

        return try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            var resolvedId: String? = null

            var isConnected = false

            val normalizedPort = port.lowercase().replace(" ", "").replace("-", "").replace("_", "")

            if (tvInputManager != null) {
                for (info in tvInputManager.tvInputList) {
                    val id = info.id
                    val label = info.loadLabel(this)?.toString() ?: id
                    val normId = id.lowercase().replace(" ", "").replace("-", "").replace("_", "")
                    val normLabel = label.lowercase().replace(" ", "").replace("-", "").replace("_", "")

                    if (normId == normalizedPort || normLabel == normalizedPort ||
                        normId.contains(normalizedPort) || normLabel.contains(normalizedPort) ||
                        (normalizedPort.isNotEmpty() && (normalizedPort.contains(normId) || normalizedPort.contains(normLabel)))) {
                        resolvedId = id
                        if (label.isNotEmpty()) displayName = label
                        break
                    }
                }
            }

            // Fallback match if no exact normalized ID matched
            if (resolvedId == null && tvInputManager != null && tvInputManager.tvInputList.isNotEmpty()) {
                val match = tvInputManager.tvInputList.firstOrNull { info ->
                    val normId = info.id.lowercase().replace(" ", "").replace("-", "").replace("_", "")
                    val normLabel = (info.loadLabel(this)?.toString() ?: "").lowercase().replace(" ", "").replace("-", "").replace("_", "")
                    normId.contains(normalizedPort) || normLabel.contains(normalizedPort)
                } ?: tvInputManager.tvInputList.firstOrNull { info ->
                    info.type == TvInputInfo.TYPE_HDMI || info.type == TvInputInfo.TYPE_TUNER || info.type == TvInputInfo.TYPE_COMPOSITE
                } ?: tvInputManager.tvInputList.firstOrNull()

                if (match != null) {
                    resolvedId = match.id
                    displayName = match.loadLabel(this)?.toString() ?: match.id
                }
            }

            // Note: Some custom TV boards (e.g. MediaTek/Realtek/MStar AOSP) return TvInputManager.INPUT_STATE_DISCONNECTED (2)
            // even when cable is physically connected. So we do NOT block intent launch here; instead we let Android TV Intent open it.
            val finalTargetId = resolvedId ?: port
            Toast.makeText(applicationContext, "Opening $displayName...", Toast.LENGTH_SHORT).show()

            val targetUri: Uri = if (finalTargetId.startsWith("content://")) {
                Uri.parse(finalTargetId)
            } else if (finalTargetId.contains("/")) {
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(finalTargetId)}")
            } else {
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(finalTargetId)}")
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = targetUri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            try {
                startActivity(intent)
                true
            } catch (e: Exception) {
                // If direct URI fails, fallback to TV Input Intent safely
                try {
                    val fallbackIntent = Intent("android.intent.action.VIEW_TV_INPUT").apply {
                        data = targetUri
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(fallbackIntent)
                    true
                } catch (_: Exception) {
                    Toast.makeText(applicationContext, "$displayName is not connected", Toast.LENGTH_LONG).show()
                    false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(applicationContext, "$displayName is not connected", Toast.LENGTH_LONG).show()
            false
        }
    }

    private fun getHdmiModels(): List<Map<String, String>> {
        val inputsList = mutableListOf<Map<String, String>>()
        try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            if (tvInputManager != null) {
                val inputList = tvInputManager.tvInputList
                var hdmiIndex = 1
                var avIndex = 1
                var tunerIndex = 1

                for (input in inputList) {
                    val id = input.id
                    
                    // Exclude non-hardware / virtual app inputs (like Google Play Movies & TV, etc.)
                    val isHardwareInput = input.type == TvInputInfo.TYPE_HDMI ||
                                          input.type == TvInputInfo.TYPE_TUNER ||
                                          input.type == TvInputInfo.TYPE_COMPOSITE ||
                                          input.type == TvInputInfo.TYPE_COMPONENT ||
                                          input.type == TvInputInfo.TYPE_DISPLAY_PORT ||
                                          input.type == TvInputInfo.TYPE_VGA ||
                                          input.type == TvInputInfo.TYPE_DVI ||
                                          input.isPassthroughInput

                    if (!isHardwareInput) {
                        continue
                    }

                    var rawLabel = try { input.loadLabel(this)?.toString() } catch(e: Exception) { null }
                    
                    // Filter out unwanted virtual package labels
                    if (rawLabel != null && (rawLabel.contains("Google Play", ignoreCase = true) || rawLabel.contains("Shop", ignoreCase = true))) {
                        rawLabel = null
                    }

                    val label = if (!rawLabel.isNullOrEmpty() && !rawLabel.contains("com.") && !rawLabel.contains("/") && !rawLabel.contains("HW")) {
                        rawLabel
                    } else {
                        when (input.type) {
                            TvInputInfo.TYPE_HDMI -> {
                                val name = "HDMI $hdmiIndex"
                                hdmiIndex++
                                name
                            }
                            TvInputInfo.TYPE_TUNER -> {
                                val name = if (tunerIndex == 1) "Live TV (Tuner)" else "Live TV $tunerIndex"
                                tunerIndex++
                                name
                            }
                            TvInputInfo.TYPE_COMPOSITE -> {
                                val name = if (avIndex == 1) "AV Input" else "AV $avIndex"
                                avIndex++
                                name
                            }
                            TvInputInfo.TYPE_COMPONENT -> "Component"
                            TvInputInfo.TYPE_DISPLAY_PORT -> "DisplayPort"
                            TvInputInfo.TYPE_VGA -> "VGA"
                            TvInputInfo.TYPE_DVI -> "DVI"
                            else -> {
                                if (input.isPassthroughInput) {
                                    val name = "HDMI $hdmiIndex"
                                    hdmiIndex++
                                    name
                                } else {
                                    "TV Port"
                                }
                            }
                        }
                    }

                    val state = try {
                        tvInputManager.getInputState(id)
                    } catch (e: Exception) {
                        TvInputManager.INPUT_STATE_CONNECTED
                    }

                    val isConnected = (state == TvInputManager.INPUT_STATE_CONNECTED || state == TvInputManager.INPUT_STATE_CONNECTED_STANDBY || state == 0)

                    inputsList.add(mapOf(
                        "id" to id,
                        "label" to label,
                        "name" to label,
                        "model" to id,
                        "value" to id,
                        "type" to when(input.type) {
                            TvInputInfo.TYPE_HDMI -> "HDMI"
                            TvInputInfo.TYPE_TUNER -> "TUNER"
                            TvInputInfo.TYPE_COMPOSITE -> "AV"
                            else -> "HARDWARE"
                        },
                        "isConnected" to isConnected.toString()
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
                    val myService1 = "$packageName/com.digiemperor.hotel.TvButtonAccessibilityService"
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



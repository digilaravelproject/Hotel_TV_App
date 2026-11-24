package com.paxtv.hospitality

import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.content.RestrictionsManager
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.view.KeyEvent
import android.widget.Toast
import com.paxtv.hospitality.helpers.CastDiscoveryHelper
import com.paxtv.hospitality.helpers.HdmiInputHelper
import com.paxtv.hospitality.helpers.KioskPolicyHelper
import com.paxtv.hospitality.helpers.SystemSettingsHelper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.paxtv.hospitality/device_info"
    private val TV_CONTROL_CHANNEL = "com.paxtv.hospitality/tv_control"
    private val EMM_CONFIG_CHANNEL = "com.paxtv.hospitality/emm_config"
    private val ACCESSIBILITY_CHANNEL = "com.paxtv.hospitality/accessibility"

    private lateinit var kioskHelper: KioskPolicyHelper
    private lateinit var hdmiHelper: HdmiInputHelper
    private lateinit var castHelper: CastDiscoveryHelper
    private lateinit var settingsHelper: SystemSettingsHelper

    private var isDemoModeInMemory: Boolean = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        kioskHelper = KioskPolicyHelper(this)
        hdmiHelper = HdmiInputHelper(this)
        castHelper = CastDiscoveryHelper(this)
        settingsHelper = SystemSettingsHelper(this)

        kioskHelper.setupDeviceOwnerLock()
    }

    private fun isDemoMode(): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.is_demo_mode", isDemoModeInMemory)
        } catch (_: Exception) {
            isDemoModeInMemory
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

        val tvControlChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_CONTROL_CHANNEL)
        hdmiHelper.setupTvInputCallback(tvControlChannel)

        // 1. EMM Config Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMM_CONFIG_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getEmmConfig") {
                result.success(getEmmConfig())
            } else {
                result.notImplemented()
            }
        }

        // 2. Accessibility Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACCESSIBILITY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityEnabled" -> result.success(settingsHelper.isAccessibilityServiceEnabled())
                "openAccessibilitySettings" -> result.success(settingsHelper.openAccessibilitySettings())
                "requestDefaultLauncher" -> {
                    kioskHelper.requestDefaultLauncherRole()
                    result.success(kioskHelper.isAlreadyDefaultLauncher())
                }
                "isDefaultLauncher" -> result.success(kioskHelper.isAlreadyDefaultLauncher())
                else -> result.notImplemented()
            }
        }

        // 3. Device Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getMacAddress" -> result.success(castHelper.getMacAddress())
                "getAndroidId" -> result.success(settingsHelper.getAndroidId())
                "getSerialNumber" -> result.success(settingsHelper.getSerialNumber())
                "getTvInputs" -> result.success(hdmiHelper.getHdmiModels().map { it["label"] ?: "" })
                "setDeviceName" -> {
                    val name = call.argument<String>("name") ?: ""
                    result.success(castHelper.setDeviceDisplayName(name, settingsHelper.getAndroidId()))
                }
                "getActualDeviceName" -> result.success(castHelper.getActualDeviceName())
                "isDeviceOwner" -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
                    result.success(dpm?.isDeviceOwnerApp(packageName) == true)
                }
                else -> result.notImplemented()
            }
        }

        // 4. TV Control Channel
        tvControlChannel.setMethodCallHandler { call, result ->
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
                "openSettings" -> result.success(settingsHelper.openSettings())
                "openAppDetailsSettings" -> result.success(settingsHelper.openAppDetailsSettings())
                "openHomeSettings" -> {
                    prepareForExternalLaunch()
                    kioskHelper.requestDefaultLauncherRole()
                    result.success(true)
                }
                "openWifiSettings" -> result.success(settingsHelper.openWifiSettings())
                "getWifiSignalStrength" -> result.success(settingsHelper.getWifiSignalStrength())
                "launchCast" -> result.success(launchCast())
                "launchHdmi" -> {
                    val model = call.argument<String>("model")
                    if (model != null) {
                        result.success(hdmiHelper.launchHdmi(model))
                    } else {
                        result.error("ERROR", "Model is null", null)
                    }
                }
                "getHdmiModels", "getLiveTvInputs" -> result.success(hdmiHelper.getHdmiModels())
                "launchIptv" -> result.success(true)
                "clearConfig" -> result.success(true)
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
                    isDemoModeInMemory = call.argument<Boolean>("enabled") ?: false
                    result.success(true)
                }
                "isMediaOrCastActive" -> {
                    var isActive = false
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        if (audioManager?.isMusicActive == true) isActive = true
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
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode
        val isDemo = isDemoMode()

        if (keyCode == KeyEvent.KEYCODE_HOME || keyCode == KeyEvent.KEYCODE_TV) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                if (isDemo) {
                    flutterEngine?.dartExecutor?.let { executor ->
                        MethodChannel(executor.binaryMessenger, "com.paxtv.hospitality/back_navigation")
                            .invokeMethod("onHomePressed", null)
                    }
                    return true
                } else {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    startActivity(intent)
                    return true
                }
            }
            return true
        }

        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.paxtv.hospitality/back_navigation")
                        .invokeMethod("onBackPressed", null)
                }
            }
            return true
        }

        if (keyCode == KeyEvent.KEYCODE_MENU) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.paxtv.hospitality/back_navigation")
                        .invokeMethod("onMenuPressed", null)
                }
            }
            return true
        }

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

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {}

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == KioskPolicyHelper.REQUEST_CODE_SET_DEFAULT_HOME) {
            try {
                val bringToFrontIntent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(bringToFrontIntent)
            } catch (_: Exception) {}
        }
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

        for (resolveInfo in (leanbackInfos + launcherInfos)) {
            try {
                val packageName = resolveInfo.activityInfo.packageName
                if (packageName == context.packageName) continue
                if (addedPackages.contains(packageName)) continue
                addedPackages.add(packageName)

                val appName = resolveInfo.loadLabel(pm).toString()
                val iconDrawable = resolveInfo.loadIcon(pm)
                val base64Icon = drawableToBase64(iconDrawable)

                appsList.add(mapOf(
                    "name" to appName,
                    "packageName" to packageName,
                    "icon" to base64Icon
                ))
            } catch (_: Exception) {}
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
        } catch (_: Exception) {
            ""
        }
    }

    private fun launchApp(packageName: String): Boolean {
        prepareForExternalLaunch()
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        return if (intent != null) {
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
                Toast.makeText(applicationContext, "App is not installed on this TV", Toast.LENGTH_SHORT).show()
                false
            }
        }
    }

    private fun launchCast(): Boolean {
        prepareForExternalLaunch()
        return try {
            val intent = Intent("android.settings.CAST_SETTINGS").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                val intent = Intent("android.settings.WIFI_DISPLAY_SETTINGS").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } catch (_: Exception) {
                false
            }
        }
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
        } catch (_: Exception) {}
        return configMap
    }
}

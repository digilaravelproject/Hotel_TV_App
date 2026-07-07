package com.digiemperor.hotel

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.media.tv.TvInputManager
import android.net.Uri
import android.util.Base64
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.net.NetworkInterface
import java.util.Collections

class MainActivity : FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.digiemperor.hotel/device_info"
    private val TV_CONTROL_CHANNEL = "com.digiemperor.hotel/tv_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Device Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getMacAddress") {
                val mac = getMacAddress()
                result.success(mac)
            } else {
                result.notImplemented()
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
                "clearConfig" -> {
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode

        if (keyCode == KeyEvent.KEYCODE_BACK) {
            flutterEngine?.dartExecutor?.let { executor ->
                MethodChannel(executor.binaryMessenger, "com.digiemperor.hotel/back_handler")
                    .invokeMethod("onBackPressed", null)
            }
            return true
        }

        if (keyCode == KeyEvent.KEYCODE_DPAD_CENTER ||
            keyCode == KeyEvent.KEYCODE_ENTER ||
            keyCode == KeyEvent.KEYCODE_DPAD_UP ||
            keyCode == KeyEvent.KEYCODE_DPAD_DOWN ||
            keyCode == KeyEvent.KEYCODE_DPAD_LEFT ||
            keyCode == KeyEvent.KEYCODE_DPAD_RIGHT
        ) {
            return window.superDispatchKeyEvent(event)
        }
        return super.dispatchKeyEvent(event)
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

    private fun getInstalledApps(): List<Map<String, Any>> {
        val appsList = mutableListOf<Map<String, Any>>()
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(intent, 0)
        for (resolveInfo in resolveInfos) {
            try {
                val packageName = resolveInfo.activityInfo.packageName
                if (packageName == packageName) {
                    // Skip our own app to avoid relaunching self
                    if (packageName == context.packageName) continue
                }

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

    private fun launchHdmi(port: String): Boolean {
        return try {
            val inputId = if (port.lowercase().contains("hdmi")) {
                val num = port.filter { it.isDigit() }
                "com.sony.dtv.hardware.hdmi$num"
            } else {
                port
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("content://android.media.tv/passthrough/$inputId")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun getHdmiModels(): Map<String, String> {
        val inputsMap = mutableMapOf<String, String>()
        try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            if (tvInputManager != null) {
                val inputList = tvInputManager.tvInputList
                for (input in inputList) {
                    if (input.isPassthroughInput) {
                        val id = input.id
                        val label = input.loadLabel(this).toString()
                        inputsMap[label] = id
                    }
                }
            }
        } catch (e: Exception) {
        }

        if (inputsMap.isEmpty()) {
            inputsMap["HDMI 1"] = "HDMI1"
            inputsMap["HDMI 2"] = "HDMI2"
            inputsMap["HDMI 3"] = "HDMI3"
            inputsMap["HDMI 4"] = "HDMI4"
        }
        return inputsMap
    }
}

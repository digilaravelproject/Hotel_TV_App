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
import android.content.ComponentName
import android.content.IntentFilter
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setupDeviceOwnerLock()
    }

    private fun setupDeviceOwnerLock() {
        try {
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminName = ComponentName(this, MyDeviceAdminReceiver::class.java)

            if (dpm.isDeviceOwnerApp(packageName)) {
                // 1. Force this app as the permanent Home Launcher (bypasses launcher picker)
                val intentFilter = IntentFilter(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                val activityName = ComponentName(this, MainActivity::class.java)
                dpm.addPersistentPreferredActivity(adminName, intentFilter, activityName)

                // 2. Lock task packages (disable notification drawer, status bar, recent apps, etc.)
                dpm.setLockTaskPackages(adminName, arrayOf(packageName))
                startLockTask() // Starts Kiosk mode
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
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

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val keyCode = event.keyCode

        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                flutterEngine?.dartExecutor?.let { executor ->
                    MethodChannel(executor.binaryMessenger, "com.digiemperor.hotel/back_navigation")
                        .invokeMethod("onBackPressed", null)
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

    private fun launchCast(): Boolean {
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

        return try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            var isConnected = false
            var displayName = port
            if (displayName.contains("/")) {
                displayName = displayName.substringAfterLast('/')
            }
            displayName = displayName.replace("_", " ").trim()

            if (tvInputManager != null) {
                for (info in tvInputManager.tvInputList) {
                    val id = info.id
                    val label = info.loadLabel(this)?.toString() ?: id
                    if (id.equals(port, ignoreCase = true) || label.equals(port, ignoreCase = true) || id.contains(port, ignoreCase = true)) {
                        if (label.isNotEmpty()) displayName = label
                        val state = try { tvInputManager.getInputState(id) } catch (e: Exception) { TvInputManager.INPUT_STATE_DISCONNECTED }
                        isConnected = (state == TvInputManager.INPUT_STATE_CONNECTED || state == TvInputManager.INPUT_STATE_CONNECTED_STANDBY)
                        break
                    }
                }
            }

            if (!isConnected) {
                Toast.makeText(applicationContext, "$displayName is not connected", Toast.LENGTH_LONG).show()
                return false
            }

            Toast.makeText(applicationContext, "Opening $displayName...", Toast.LENGTH_SHORT).show()

            val targetUri: Uri = if (port.startsWith("content://")) {
                Uri.parse(port)
            } else if (port.contains("/")) {
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(port)}")
            } else if (port.lowercase().contains("hdmi") || port.lowercase().contains("av")) {
                var resolvedId: String? = null
                try {
                    if (tvInputManager != null) {
                        for (info in tvInputManager.tvInputList) {
                            val id = info.id
                            val label = info.loadLabel(this)?.toString() ?: ""
                            if (id.contains(port, ignoreCase = true) || label.contains(port, ignoreCase = true)) {
                                resolvedId = id
                                break
                            }
                        }
                    }
                } catch (e: Exception) {}

                val finalId = resolvedId ?: port
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(finalId)}")
            } else {
                Uri.parse("content://android.media.tv/passthrough/${Uri.encode(port)}")
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = targetUri
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(applicationContext, "$port is not connected", Toast.LENGTH_LONG).show()
            false
        }
    }

    private fun getHdmiModels(): List<Map<String, String>> {
        val inputsList = mutableListOf<Map<String, String>>()
        try {
            val tvInputManager = getSystemService(Context.TV_INPUT_SERVICE) as? TvInputManager
            if (tvInputManager != null) {
                val inputList = tvInputManager.tvInputList
                for (input in inputList) {
                    val id = input.id
                    var label = try { input.loadLabel(this)?.toString() } catch(e: Exception) { null }
                    if (label.isNullOrEmpty()) {
                        label = when (input.type) {
                            TvInputInfo.TYPE_HDMI -> "HDMI (${id.substringAfterLast('/')})"
                            TvInputInfo.TYPE_TUNER -> "Live TV (Tuner)"
                            TvInputInfo.TYPE_DISPLAY_PORT -> "DisplayPort"
                            TvInputInfo.TYPE_COMPOSITE -> "AV / Composite"
                            TvInputInfo.TYPE_COMPONENT -> "Component"
                            TvInputInfo.TYPE_VGA -> "VGA"
                            TvInputInfo.TYPE_DVI -> "DVI"
                            else -> if (input.isPassthroughInput) "Passthrough Input" else id
                        }
                    }

                    val state = try {
                        tvInputManager.getInputState(id)
                    } catch (e: Exception) {
                        TvInputManager.INPUT_STATE_CONNECTED
                    }

                    val isConnected = (state == TvInputManager.INPUT_STATE_CONNECTED || state == TvInputManager.INPUT_STATE_CONNECTED_STANDBY)

                    inputsList.add(mapOf(
                        "id" to id,
                        "label" to label,
                        "name" to label,
                        "model" to id,
                        "value" to id,
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

    private fun getAndroidId(): String {
        return try {
            android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ANDROID_ID) ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    private fun getSerialNumber(): String {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            try {
                val serial = android.os.Build.getSerial()
                if (serial != android.os.Build.UNKNOWN) {
                    return serial
                }
            } catch (e: SecurityException) {
                e.printStackTrace()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        
        try {
            val serial = android.os.Build.SERIAL
            if (serial != android.os.Build.UNKNOWN) {
                return serial
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        
        return ""
    }

    private fun getNetworkDetails(): Map<String, String> {
        val details = mutableMapOf<String, String>()
        
        // 1. Query ConnectivityManager default link properties
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? android.net.ConnectivityManager
            if (cm != null) {
                val activeNetwork = cm.activeNetwork
                if (activeNetwork != null) {
                    val linkProperties = cm.getLinkProperties(activeNetwork)
                    if (linkProperties != null) {
                        for (route in linkProperties.routes) {
                            if (route.isDefaultRoute && route.gateway != null) {
                                val gw = route.gateway?.hostAddress
                                if (!gw.isNullOrEmpty()) details["gateway"] = gw
                                break
                            }
                        }
                        val dnsServers = linkProperties.dnsServers
                        if (dnsServers.isNotEmpty()) {
                            val dns = dnsServers[0].hostAddress
                            if (!dns.isNullOrEmpty()) details["dns"] = dns
                        }
                        for (linkAddr in linkProperties.linkAddresses) {
                            val addr = linkAddr.address
                            if (addr is java.net.Inet4Address && !addr.isLoopbackAddress) {
                                val prefixLength = linkAddr.prefixLength
                                details["subnet"] = prefixLengthToSubnetMask(prefixLength)
                                break
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // 2. WifiManager DhcpInfo fallback
        if (details["gateway"].isNullOrEmpty() || details["dns"].isNullOrEmpty()) {
            try {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                val dhcpInfo = wifiManager?.dhcpInfo
                if (dhcpInfo != null) {
                    if (dhcpInfo.gateway != 0 && details["gateway"].isNullOrEmpty()) details["gateway"] = intToIp(dhcpInfo.gateway)
                    if (dhcpInfo.netmask != 0 && details["subnet"].isNullOrEmpty()) details["subnet"] = intToIp(dhcpInfo.netmask)
                    if (dhcpInfo.dns1 != 0 && details["dns"].isNullOrEmpty()) details["dns"] = intToIp(dhcpInfo.dns1)
                }
            } catch (e: Exception) {}
        }

        // 3. Dynamic IP-based derivation fallback if network link doesn't expose route (e.g. Ethernet / Emulator)
        val ip = getMacAddress().let { "" } // Trigger interface scan if needed
        val activeIp = getLocalIpAddress()
        if (activeIp.isNotEmpty()) {
            val parts = activeIp.split(".")
            if (parts.size == 4) {
                if (details["gateway"].isNullOrEmpty()) {
                    details["gateway"] = "${parts[0]}.${parts[1]}.${parts[2]}.1"
                }
                if (details["subnet"].isNullOrEmpty()) {
                    details["subnet"] = "255.255.255.0"
                }
                if (details["dns"].isNullOrEmpty()) {
                    details["dns"] = "8.8.8.8"
                }
            }
        }

        return details
    }

    private fun getLocalIpAddress(): String {
        try {
            val en = NetworkInterface.getNetworkInterfaces()
            while (en.hasMoreElements()) {
                val intf = en.nextElement()
                val enumIpAddr = intf.inetAddresses
                while (enumIpAddr.hasMoreElements()) {
                    val inetAddress = enumIpAddr.nextElement()
                    if (!inetAddress.isLoopbackAddress && inetAddress is java.net.Inet4Address) {
                        return inetAddress.hostAddress ?: ""
                    }
                }
            }
        } catch (ex: Exception) {}
        return ""
    }

    private fun prefixLengthToSubnetMask(prefixLength: Int): String {
        val mask = -0x1 shl (32 - prefixLength)
        return String.format("%d.%d.%d.%d",
            (mask shr 24) and 0xff,
            (mask shr 16) and 0xff,
            (mask shr 8) and 0xff,
            mask and 0xff)
    }

    private fun intToIp(ipAddress: Int): String {
        return String.format("%d.%d.%d.%d",
            ipAddress and 0xff,
            ipAddress shr 8 and 0xff,
            ipAddress shr 16 and 0xff,
            ipAddress shr 24 and 0xff)
    }
}


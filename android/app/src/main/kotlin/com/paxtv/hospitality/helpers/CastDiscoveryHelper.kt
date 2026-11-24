package com.paxtv.hospitality.helpers

import android.app.admin.DevicePolicyManager
import android.bluetooth.BluetoothManager
import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import com.paxtv.hospitality.MyDeviceAdminReceiver
import com.paxtv.hospitality.TvButtonAccessibilityService
import java.net.NetworkInterface
import java.util.Collections

class CastDiscoveryHelper(private val context: Context) {

    private var nsdManager: NsdManager? = null
    private var castNsdListener: NsdManager.RegistrationListener? = null
    private var airplayNsdListener: NsdManager.RegistrationListener? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    fun getMacAddress(): String {
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
        } catch (_: Exception) {}
        return ""
    }

    fun getActualDeviceName(): String {
        try {
            val name = Settings.Global.getString(context.contentResolver, "device_name")
            if (!name.isNullOrBlank()) return name
        } catch (_: Exception) {}

        try {
            val name = Settings.Secure.getString(context.contentResolver, "bluetooth_name")
            if (!name.isNullOrBlank()) return name
        } catch (_: Exception) {}

        try {
            @Suppress("DEPRECATION")
            val bt = android.bluetooth.BluetoothAdapter.getDefaultAdapter()
            if (bt != null && !bt.name.isNullOrBlank()) return bt.name
        } catch (_: Exception) {}

        return Build.MODEL ?: ""
    }

    fun registerNsdCastService(displayName: String, androidId: String) {
        if (displayName.isBlank()) return
        try {
            if (multicastLock == null) {
                val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                multicastLock = wifi?.createMulticastLock("HotelTvMulticastLock")?.apply {
                    setReferenceCounted(true)
                    acquire()
                }
            }

            if (nsdManager == null) {
                nsdManager = context.getSystemService(Context.NSD_SERVICE) as? NsdManager
            }
            val mgr = nsdManager ?: return

            castNsdListener?.let {
                try { mgr.unregisterService(it) } catch (_: Exception) {}
                castNsdListener = null
            }

            // Google Cast mDNS service (_googlecast._tcp)
            val castInfo = NsdServiceInfo().apply {
                serviceName = displayName
                serviceType = "_googlecast._tcp"
                port = 8008
                setAttribute("fn", displayName)
                setAttribute("md", Build.MODEL ?: "Smart TV")
                setAttribute("id", androidId)
                setAttribute("st", "1")
            }

            castNsdListener = object : NsdManager.RegistrationListener {
                override fun onServiceRegistered(service: NsdServiceInfo) {
                    Log.i("HotelTV", "✅ NSD mDNS Google Cast registered as: ${service.serviceName}")
                }
                override fun onRegistrationFailed(service: NsdServiceInfo, errorCode: Int) {
                    Log.w("HotelTV", "⚠️ NSD Cast registration failed: $errorCode")
                }
                override fun onServiceUnregistered(service: NsdServiceInfo) {}
                override fun onUnregistrationFailed(service: NsdServiceInfo, errorCode: Int) {}
            }
            mgr.registerService(castInfo, NsdManager.PROTOCOL_DNS_SD, castNsdListener)

            airplayNsdListener?.let {
                try { mgr.unregisterService(it) } catch (_: Exception) {}
                airplayNsdListener = null
            }

            // AirPlay / Apple Screen Mirroring mDNS service (_airplay._tcp)
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
                    Log.i("HotelTV", "✅ NSD mDNS AirPlay registered as: ${service.serviceName}")
                }
                override fun onRegistrationFailed(service: NsdServiceInfo, errorCode: Int) {}
                override fun onServiceUnregistered(service: NsdServiceInfo) {}
                override fun onUnregistrationFailed(service: NsdServiceInfo, errorCode: Int) {}
            }
            mgr.registerService(airplayInfo, NsdManager.PROTOCOL_DNS_SD, airplayNsdListener)
        } catch (e: Exception) {
            Log.w("HotelTV", "⚠️ registerNsdCastService error: ${e.message}")
        }
    }

    fun setDeviceDisplayName(name: String, androidId: String): Boolean {
        if (name.isBlank()) return false
        var success = false

        registerNsdCastService(name, androidId)

        // Device Policy Manager
        try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val admin = MyDeviceAdminReceiver.getComponentName(context)
            if (dpm != null && dpm.isDeviceOwnerApp(context.packageName)) {
                dpm.setGlobalSetting(admin, "device_name", name)
                Log.i("HotelTV", "✅ DPM setGlobalSetting device_name to: $name")
                success = true
            }
        } catch (e: Exception) {
            Log.w("HotelTV", "⚠️ DPM setGlobalSetting error: ${e.message}")
        }

        // Settings.Global
        var globalSet = false
        try {
            Settings.Global.putString(context.contentResolver, "device_name", name)
            Log.i("HotelTV", "✅ Settings.Global device_name set to: $name")
            globalSet = true
            success = true
        } catch (_: Exception) {}

        // Accessibility Auto-Pilot Fallback
        if (!globalSet) {
            val currentActual = getActualDeviceName()
            if (currentActual != name) {
                TvButtonAccessibilityService.autoRenameDevice(context.applicationContext, name)
            }
        }

        // Bluetooth Name
        try {
            val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter = bluetoothManager?.adapter
            if (adapter != null) {
                adapter.name = name
                Log.i("HotelTV", "✅ Bluetooth name set to: $name")
                success = true
            }
        } catch (_: Exception) {}

        // Wi-Fi Direct (P2P)
        try {
            val wifiMgr = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val wifiP2pManager = context.applicationContext.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
            if (wifiP2pManager != null && (wifiMgr?.isWifiEnabled == true)) {
                val channel = wifiP2pManager.initialize(context.applicationContext, context.mainLooper, null)
                val method = wifiP2pManager.javaClass.getMethod(
                    "setDeviceName",
                    WifiP2pManager.Channel::class.java,
                    String::class.java,
                    WifiP2pManager.ActionListener::class.java
                )
                fun attemptSetP2pName(retriesLeft: Int) {
                    try {
                        method.invoke(
                            wifiP2pManager,
                            channel,
                            name,
                            object : WifiP2pManager.ActionListener {
                                override fun onSuccess() {
                                    Log.i("HotelTV", "✅ Wi-Fi Direct name set to: $name")
                                }
                                override fun onFailure(reason: Int) {
                                    if (reason == 2 && retriesLeft > 0) {
                                        Handler(Looper.getMainLooper()).postDelayed({
                                            attemptSetP2pName(retriesLeft - 1)
                                        }, 1000)
                                    }
                                }
                            }
                        )
                    } catch (_: Exception) {}
                }
                Handler(Looper.getMainLooper()).postDelayed({ attemptSetP2pName(3) }, 800)
                success = true
            }
        } catch (_: Exception) {}

        return success
    }
}

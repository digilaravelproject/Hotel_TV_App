package com.paxtv.hospitality.helpers

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.paxtv.hospitality.ExternalLaunchTracker
import java.net.Inet4Address
import java.net.NetworkInterface

class SystemSettingsHelper(private val context: Context) {

    fun getAndroidId(): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID) ?: ""
        } catch (_: Exception) {
            ""
        }
    }

    fun getSerialNumber(): String {
        val androidId = getAndroidId()
        if (androidId.isNotEmpty() && androidId != "unknown") return androidId

        try {
            val c = Class.forName("android.os.SystemProperties")
            val get = c.getMethod("get", String::class.java)
            val propSerial = get.invoke(c, "ro.serialno") as? String
            if (!propSerial.isNullOrEmpty() && propSerial != "unknown") return propSerial

            val bootSerial = get.invoke(c, "ro.boot.serialno") as? String
            if (!bootSerial.isNullOrEmpty() && bootSerial != "unknown") return bootSerial
        } catch (_: Exception) {}

        return ""
    }

    fun getWifiSignalStrength(): Int {
        return try {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val info = wifi?.connectionInfo
            if (info != null && info.networkId != -1) {
                @Suppress("DEPRECATION")
                WifiManager.calculateSignalLevel(info.rssi, 5)
            } else {
                -1
            }
        } catch (_: Exception) {
            -1
        }
    }

    fun openSettings(): Boolean {
        ExternalLaunchTracker.notifyExternalLaunch()
        return try {
            val intent = Intent(Settings.ACTION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun openWifiSettings(): Boolean {
        ExternalLaunchTracker.notifyExternalLaunch()
        return try {
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            openSettings()
        }
    }

    fun openAppDetailsSettings(): Boolean {
        ExternalLaunchTracker.notifyExternalLaunch()
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val accessibilityEnabled = Settings.Secure.getInt(context.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0)
            if (accessibilityEnabled == 1) {
                val services = Settings.Secure.getString(context.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
                if (services != null) {
                    val myService = "${context.packageName}/com.paxtv.hospitality.TvButtonAccessibilityService"
                    services.contains(myService, ignoreCase = true) || services.contains("${context.packageName}/", ignoreCase = true)
                } else false
            } else false
        } catch (_: Exception) {
            false
        }
    }

    fun openAccessibilitySettings(): Boolean {
        ExternalLaunchTracker.notifyExternalLaunch()
        val intents = listOf(
            Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.MainSettings"),
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
            Intent(Settings.ACTION_SETTINGS)
        )
        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.resolveActivity(context.packageManager) != null) {
                    context.startActivity(intent)
                    return true
                }
            } catch (_: Exception) {}
        }
        return false
    }
}

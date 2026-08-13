package com.digiemperor.hotel

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.content.pm.PackageManager
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class TvButtonAccessibilityService : AccessibilityService() {

    private var lastRelaunchTime: Long = 0
    private val TAG = "TvAccessibilityService"

    // Common Android TV system launcher package names
    private val knownLauncherPackages = setOf(
        "com.google.android.tvlauncher",
        "com.google.android.apps.tv.launcherx",
        "com.android.tv.launcher",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.katniss",
        "com.amazon.tv.launcher",
        "com.cyanogenmod.trebuchet",
        "com.mstar.tv.tvplayer.ui",
        "com.mediatek.wwtv.tvcenter"
    )

    // Settings packages that must NEVER be misidentified as a Launcher
    private val ignoredSettingsPackages = setOf(
        "com.android.tv.settings",
        "com.google.android.tv.settings",
        "com.android.settings",
        "com.tcl.tv.settings",
        "com.xiaomi.mitv.settings",
        "com.sony.dtv.settings"
    )

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return

            // If the package is our own app, do nothing
            if (packageName == applicationContext.packageName) {
                return
            }

            // If user or app intentionally opened an external activity (Settings, Wi-Fi, Cast, HDMI), do NOT auto-relaunch
            if (ExternalLaunchTracker.isRecentlyLaunchedExternal()) {
                Log.d(TAG, "Ignoring window change ($packageName) because external activity was launched recently.")
                return
            }

            // Check if the foreground window belongs to a system Home Launcher
            if (isSystemLauncherPackage(packageName)) {
                val currentTime = SystemClock.elapsedRealtime()
                // Debounce re-launch to avoid loops (minimum 800ms between auto-relaunches)
                if (currentTime - lastRelaunchTime > 800) {
                    lastRelaunchTime = currentTime
                    Log.i(TAG, "Detected System Default Launcher ($packageName) in foreground. Relaunching Hotel TV App...")
                    bringAppToFront()
                }
            }
        }
    }

    private fun isSystemLauncherPackage(pkgName: String): Boolean {
        // Never treat settings as launcher
        if (ignoredSettingsPackages.contains(pkgName)) {
            return false
        }

        if (knownLauncherPackages.contains(pkgName)) {
            return true
        }
        try {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            val resolveInfos = packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
            for (info in resolveInfos) {
                val launcherPkg = info.activityInfo.packageName
                if (launcherPkg != applicationContext.packageName && !ignoredSettingsPackages.contains(launcherPkg) && launcherPkg == pkgName) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking launcher package: ${e.message}")
        }
        return false
    }

    private fun bringAppToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring MainActivity to front: ${e.message}")
        }
    }

    override fun onInterrupt() {
        // Handle interrupt
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false

        // Intercept Home button or TV key events to bring Hotel TV App to front
        if (event.keyCode == KeyEvent.KEYCODE_HOME || event.keyCode == KeyEvent.KEYCODE_TV) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                bringAppToFront()
            }
            return true // Consume both ACTION_DOWN and ACTION_UP so OS never opens default home
        }
        return super.onKeyEvent(event)
    }
}


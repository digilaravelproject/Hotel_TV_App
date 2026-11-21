package com.paxtv.hospitality

import android.accessibilityservice.AccessibilityService
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.SystemClock
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class TvButtonAccessibilityService : AccessibilityService() {

    private var lastRelaunchTime: Long = 0
    private val TAG = "TvAccessibilityService"

    companion object {
        @Volatile
        var currentForegroundPackage: String? = null
    }

    // Common Android TV system launcher package names
    private val knownLauncherPackages = setOf(
        "com.google.android.tvlauncher",
        "com.google.android.apps.tv.launcherx",
        "com.android.tv.launcher",
        "com.android.launcher",
        "com.android.launcher3",
        "com.google.android.katniss",
        "com.google.android.apps.mediashell",
        "com.google.android.backdrop",
        "com.smartdevice.livetv",
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
            currentForegroundPackage = packageName

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

    private fun getActivePackage(): String? {
        val current = currentForegroundPackage
        if (!current.isNullOrBlank()) return current
        return try {
            rootInActiveWindow?.packageName?.toString()
        } catch (_: Exception) {
            null
        }
    }

    private fun isYouTubeOrCastPackage(pkgName: String?): Boolean {
        if (pkgName.isNullOrBlank()) return false
        val pkg = pkgName.lowercase()
        return pkg.contains("youtube") ||
               pkg.contains("mediashell") ||
               pkg.contains("chromecast") ||
               pkg.contains("airscreen") ||
               pkg.contains("airplay") ||
               pkg.contains("miracast") ||
               pkg.contains("screencast") ||
               pkg.contains("wfd") ||
               pkg == "com.google.android.apps.mediashell" ||
               pkg == "com.google.android.youtube.tv" ||
               pkg == "com.google.android.apps.youtube.tv" ||
               pkg == "com.google.android.youtube" ||
               pkg == "com.google.android.youtube.tvunplugged" ||
               pkg == "com.google.android.apps.youtube.tv.unplugged"
    }

    private fun closeYouTubeAndBringAppToFront(pkg: String?) {
        try {
            // 1. Dispatch media pause & stop keys so audio immediately halts
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_STOP))
            audioManager?.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_STOP))
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping media playback: ${e.message}")
        }

        try {
            // 2. Kill background processes of the cast/media app so it completely shuts down
            val actMan = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            if (!pkg.isNullOrBlank()) {
                actMan?.killBackgroundProcesses(pkg)
            }
            actMan?.killBackgroundProcesses("com.google.android.youtube.tv")
            actMan?.killBackgroundProcesses("com.google.android.apps.youtube.tv")
            actMan?.killBackgroundProcesses("com.google.android.apps.mediashell")
            actMan?.killBackgroundProcesses("com.google.android.youtube")
        } catch (e: Exception) {
            Log.w(TAG, "Error killing media background process: ${e.message}")
        }

        // 3. Reset foreground tracking
        currentForegroundPackage = null

        // 4. Bring Hotel TV App to front (works in both Try Demo mode & Login mode!)
        bringAppToFront()
    }

    private fun bringAppToFront() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to bring MainActivity to front: ${e.message}")
        }
    }

    override fun onInterrupt() {
        // Handle interrupt
    }

    private fun isDemoMode(): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getBoolean("flutter.is_demo_mode", false)
        } catch (e: Exception) {
            false
        }
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false

        val keyCode = event.keyCode
        val activePkg = getActivePackage()

        // 1. BACK button handling when in YouTube or Cast receiver:
        // Guest pressed BACK -> Close YouTube/Cast and bring Hotel TV app to front!
        // Works in BOTH Try Demo Mode and Login Mode!
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (isYouTubeOrCastPackage(activePkg)) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    Log.i(TAG, "Back pressed while in YouTube/Cast ($activePkg). Closing YouTube and returning to Hotel TV...")
                    closeYouTubeAndBringAppToFront(activePkg)
                }
                return true // Consume BACK so YouTube doesn't stay open!
            }
        }

        // 2. HOME or TV button handling:
        if (keyCode == KeyEvent.KEYCODE_HOME || keyCode == KeyEvent.KEYCODE_TV) {
            if (isYouTubeOrCastPackage(activePkg)) {
                if (event.action == KeyEvent.ACTION_DOWN) {
                    Log.i(TAG, "Home pressed while in YouTube/Cast ($activePkg). Closing YouTube and returning to Hotel TV...")
                    closeYouTubeAndBringAppToFront(activePkg)
                }
                return true
            }

            // In Demo Mode when already in our app, do not swallow keys (MainActivity handles it)
            if (isDemoMode() && activePkg == applicationContext.packageName) {
                return super.onKeyEvent(event)
            }

            if (event.action == KeyEvent.ACTION_DOWN) {
                bringAppToFront()
            }
            return true // Consume both ACTION_DOWN and ACTION_UP so OS never opens default home
        }

        return super.onKeyEvent(event)
    }
}


package com.digiemperor.hotel

import android.os.SystemClock

object ExternalLaunchTracker {
    @Volatile
    var lastExternalLaunchTime: Long = 0

    fun notifyExternalLaunch() {
        lastExternalLaunchTime = SystemClock.elapsedRealtime()
    }

    fun isRecentlyLaunchedExternal(): Boolean {
        // Increased timeout to 8 seconds.
        // Some TVs (like Skyworth/MediaTek) take 3-5 seconds to detect HDMI signal.
        // If we re-lock too early, it might pull the app back to foreground.
        return (SystemClock.elapsedRealtime() - lastExternalLaunchTime) < 8000
    }
}

package com.digiemperor.hotel

import android.os.SystemClock

object ExternalLaunchTracker {
    @Volatile
    var lastExternalLaunchTime: Long = 0

    fun notifyExternalLaunch() {
        lastExternalLaunchTime = SystemClock.elapsedRealtime()
    }

    fun isRecentlyLaunchedExternal(): Boolean {
        // Reduced timeout to 3 seconds.
        // If an external activity was triggered within 3 seconds, do NOT auto-relaunch Hotel TV app.
        // This ensures the kiosk mode recovers quickly if the user presses HOME.
        return (SystemClock.elapsedRealtime() - lastExternalLaunchTime) < 3000
    }
}

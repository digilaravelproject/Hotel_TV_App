package com.digiemperor.hotel

import android.os.SystemClock

object ExternalLaunchTracker {
    @Volatile
    var lastExternalLaunchTime: Long = 0

    fun notifyExternalLaunch() {
        lastExternalLaunchTime = SystemClock.elapsedRealtime()
    }

    fun isRecentlyLaunchedExternal(): Boolean {
        // If an external activity (Settings, Cast, HDMI, App launch) was triggered within 20 seconds,
        // do NOT auto-relaunch Hotel TV app.
        return (SystemClock.elapsedRealtime() - lastExternalLaunchTime) < 20000
    }
}

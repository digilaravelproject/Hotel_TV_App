package com.paxtv.hospitality

import android.os.SystemClock

object ExternalLaunchTracker {
    @Volatile
    var lastExternalLaunchTime: Long = 0

    @Volatile
    var currentTimeoutMs: Long = 8000L

    fun notifyExternalLaunch(timeoutMs: Long = 8000L) {
        lastExternalLaunchTime = SystemClock.elapsedRealtime()
        currentTimeoutMs = timeoutMs
    }

    fun isRecentlyLaunchedExternal(): Boolean {
        return (SystemClock.elapsedRealtime() - lastExternalLaunchTime) < currentTimeoutMs
    }
}

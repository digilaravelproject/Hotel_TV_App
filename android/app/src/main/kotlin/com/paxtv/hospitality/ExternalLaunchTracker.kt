package com.paxtv.hospitality

import android.os.SystemClock

object ExternalLaunchTracker {
    @Volatile
    var lastExternalLaunchTime: Long = 0

    @Volatile
    var currentTimeoutMs: Long = 8000L

    @Volatile
    var isAuthorizedSettingsOpen: Boolean = false

    fun notifyExternalLaunch(timeoutMs: Long = 8000L) {
        lastExternalLaunchTime = SystemClock.elapsedRealtime()
        currentTimeoutMs = timeoutMs
    }

    fun notifyAuthorizedSettingsLaunch(timeoutMs: Long = 120_000L) {
        lastExternalLaunchTime = SystemClock.elapsedRealtime()
        currentTimeoutMs = timeoutMs
        isAuthorizedSettingsOpen = true
    }

    fun onReturnedToApp() {
        isAuthorizedSettingsOpen = false
    }

    fun isRecentlyLaunchedExternal(): Boolean {
        return (SystemClock.elapsedRealtime() - lastExternalLaunchTime) < currentTimeoutMs
    }
}

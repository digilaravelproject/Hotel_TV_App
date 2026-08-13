package com.digiemperor.hotel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.UserManager

class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        android.util.Log.i("BootReceiver", "Received boot action: $action")

        // 1. Direct Boot check for Android 7.0+ / Android 13
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val userManager = context.getSystemService(UserManager::class.java)
            if (userManager != null && !userManager.isUserUnlocked) {
                android.util.Log.w("BootReceiver", "Storage is locked (Direct Boot). Waiting for BOOT_COMPLETED / USER_UNLOCKED.")
                // Skip launching during locked boot to prevent storage unlock crash & black screen
                if (action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
                    return
                }
            }
        }

        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON" ||
            action == "android.intent.action.REBOOT" ||
            action == Intent.ACTION_USER_PRESENT) {

            // Delayed launcher backup execution (gives Android 13 OS time to load window surface naturally)
            Handler(Looper.getMainLooper()).postDelayed({
                launchActivitySafely(context)
            }, 1500)
        }
    }

    private fun launchActivitySafely(context: Context) {
        try {
            val i = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            }
            context.startActivity(i)
        } catch (e: Exception) {
            android.util.Log.e("BootReceiver", "Error launching MainActivity from BootReceiver: ${e.message}")
        }
    }
}

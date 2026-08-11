package com.digiemperor.hotel

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED || 
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON" ||
            action == "android.intent.action.REBOOT" ||
            action == Intent.ACTION_USER_PRESENT) {
            
            // Immediate launch
            launchActivity(context)

            // Backup launch after 1 second if OS delayed initialization
            Handler(Looper.getMainLooper()).postDelayed({
                launchActivity(context)
            }, 1000)
        }
    }

    private fun launchActivity(context: Context) {
        try {
            val i = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
            }
            context.startActivity(i)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}

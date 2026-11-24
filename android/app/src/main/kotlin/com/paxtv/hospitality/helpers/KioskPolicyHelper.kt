package com.paxtv.hospitality.helpers

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.paxtv.hospitality.MyDeviceAdminReceiver

class KioskPolicyHelper(private val activity: Activity) {

    companion object {
        const val REQUEST_CODE_SET_DEFAULT_HOME = 1001
    }

    fun isAlreadyDefaultLauncher(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_HOME) }
            val resolveInfo = activity.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            val currentDefault = resolveInfo?.activityInfo?.packageName
            if (currentDefault != null && currentDefault == activity.packageName) {
                return true
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = activity.getSystemService(Context.ROLE_SERVICE) as? RoleManager
                if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    if (roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                        return true
                    }
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    fun requestDefaultLauncherRole() {
        try {
            if (isAlreadyDefaultLauncher()) {
                Log.i("KioskPolicy", "✅ App is already Default Home Launcher.")
                return
            }

            // 1. Android 10+ (API 29+) RoleManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = activity.getSystemService(Context.ROLE_SERVICE) as? RoleManager
                if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_HOME)) {
                    if (!roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                        try {
                            val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
                            activity.startActivityForResult(intent, REQUEST_CODE_SET_DEFAULT_HOME)
                            return
                        } catch (_: Exception) {}
                    }
                }
            }

            // 2. Action Home Settings
            try {
                val homeSettingsIntent = Intent(Settings.ACTION_HOME_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                if (homeSettingsIntent.resolveActivity(activity.packageManager) != null) {
                    activity.startActivity(homeSettingsIntent)
                    return
                }
            } catch (_: Exception) {}

            // 3. Fallback: TV Setting Intents
            val tvSettingIntents = arrayOf(
                Intent("com.android.tv.settings.MainSettings"),
                Intent(Settings.ACTION_SETTINGS),
                Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS)
            )
            for (intent in tvSettingIntents) {
                try {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    if (intent.resolveActivity(activity.packageManager) != null) {
                        activity.startActivity(intent)
                        return
                    }
                } catch (_: Exception) {}
            }

            // 4. Fallback: Intent Chooser
            val selectorIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            activity.startActivity(Intent.createChooser(selectorIntent, "Select Home Launcher").apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            })
        } catch (e: Exception) {
            Log.w("KioskPolicy", "Error requesting launcher role: ${e.message}")
        }
    }

    fun setupDeviceOwnerLock() {
        try {
            val dpm = activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return
            val adminComponent = MyDeviceAdminReceiver.getComponentName(activity)

            if (dpm.isDeviceOwnerApp(activity.packageName)) {
                Log.i("KioskPolicy", "🛡️ App is Device Owner. Enforcing Kiosk lockdown...")
                val packages = arrayOf(activity.packageName)
                dpm.setLockTaskPackages(adminComponent, packages)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    dpm.setLockTaskFeatures(
                        adminComponent,
                        DevicePolicyManager.LOCK_TASK_FEATURE_NONE
                    )
                }

                // Prevent keyguard / lock screen
                dpm.setKeyguardDisabled(adminComponent, true)

                // Enforce as persistent preferred home activity
                val filter = android.content.IntentFilter(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    addCategory(Intent.CATEGORY_DEFAULT)
                }
                val activityComponent = ComponentName(activity, activity.javaClass)
                dpm.addPersistentPreferredActivity(adminComponent, filter, activityComponent)

                Log.i("KioskPolicy", "✅ Device Owner Kiosk policies successfully configured")
            }
        } catch (e: Exception) {
            Log.w("KioskPolicy", "⚠️ Setup DeviceOwner error: ${e.message}")
        }
    }
}

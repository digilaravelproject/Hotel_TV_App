package com.digiemperor.hotel

import android.app.admin.DeviceAdminReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.Toast

class MyDeviceAdminReceiver : DeviceAdminReceiver() {

    companion object {
        /** Returns the ComponentName for this receiver, used in DevicePolicyManager calls. */
        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, MyDeviceAdminReceiver::class.java)
        }
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Toast.makeText(context, "Device Admin Enabled", Toast.LENGTH_SHORT).show()
    }
}

package com.digiemperor.hotel

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class TvButtonAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Handle events if needed
    }

    override fun onInterrupt() {
        // Handle interrupt
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false

        // Intercept Home button or TV key events to bring Hotel TV App to front
        if (event.keyCode == KeyEvent.KEYCODE_HOME || event.keyCode == KeyEvent.KEYCODE_TV) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(intent)
            }
            return true // Consume both ACTION_DOWN and ACTION_UP so OS never opens default home
        }
        return super.onKeyEvent(event)
    }
}

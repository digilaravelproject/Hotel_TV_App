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

        // Intercept Home button or specific key events if needed
        if (event.keyCode == KeyEvent.KEYCODE_HOME) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(intent)
                return true
            }
        }
        return super.onKeyEvent(event)
    }
}

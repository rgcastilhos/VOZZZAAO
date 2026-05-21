package com.example.voz_comando

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

class PhoneAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        current = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        if (current === this) {
            current = null
        }
        super.onDestroy()
    }

    companion object {
        private var current: PhoneAccessibilityService? = null
        private val handler = Handler(Looper.getMainLooper())

        fun isRunning(): Boolean = current != null

        fun pressBack(times: Int): Boolean {
            val service = current ?: return false
            val safeTimes = times.coerceIn(1, 10)
            repeat(safeTimes) { index ->
                handler.postDelayed(
                    { service.performGlobalAction(GLOBAL_ACTION_BACK) },
                    index * 250L,
                )
            }
            return true
        }

        fun pressHome(times: Int): Boolean {
            val service = current ?: return false
            val safeTimes = times.coerceIn(1, 5)
            repeat(safeTimes) { index ->
                handler.postDelayed(
                    { service.performGlobalAction(GLOBAL_ACTION_HOME) },
                    index * 300L,
                )
            }
            return true
        }
    }
}

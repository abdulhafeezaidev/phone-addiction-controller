package com.personal.phone_addiction_controller.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import com.personal.phone_addiction_controller.EscapeDetectionService
import com.personal.phone_addiction_controller.FlutterBridge
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.ForegroundApp

/**
 * Accessibility service that monitors foreground app changes and enforces blocking.
 *
 * Responsibility: Observe window events and feed package names into
 * [EscapeDetectionService.handleForegroundPackage]. All policy decisions
 * are made inside [EscapeDetectionService] via [FocusPolicyEngine].
 * This class has no policy logic of its own.
 */
class AccessibilityMonitorService : AccessibilityService() {

    private var escapeDetectionService: EscapeDetectionService? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Service Connected")
        FocusModeManager.init(this)

        escapeDetectionService = EscapeDetectionService(this)
        escapeDetectionService?.setListener(object : EscapeDetectionService.AppChangeListener {
            override fun onForegroundAppChanged(app: ForegroundApp) {
                FlutterBridge.sendForegroundAppUpdate(app)
            }

            override fun onAppBlocked(packageName: String, appName: String) {
                FlutterBridge.sendBlockedEvent(packageName, appName)
            }

            // Instantly collapses system UIs like the Recent Apps screen
            override fun forceHome() {
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        })
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val eventType = event.eventType
        if (
            eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            return
        }

        val packageName = resolveForegroundPackage(event)
        val className = event.className?.toString()
        escapeDetectionService?.handleForegroundPackage(packageName, className)
    }

    private fun resolveForegroundPackage(event: AccessibilityEvent): String? {
        // Primary source: event's own package name
        event.packageName?.toString()?.let { return it }

        // Secondary: root of the active window
        val rootPackage = rootInActiveWindow?.packageName?.toString()
        if (!rootPackage.isNullOrEmpty()) return rootPackage

        // Fallback: first application-type window in the window list
        val windows = windows ?: return null
        val activeWindow = windows.firstOrNull { it.type == AccessibilityWindowInfo.TYPE_APPLICATION }
        return activeWindow?.root?.packageName?.toString()
    }

    override fun onInterrupt() {
        Log.d(TAG, "Service Interrupted")
    }

    override fun onUnbind(intent: Intent?): Boolean {
        Log.d(TAG, "Service Unbound")
        escapeDetectionService?.setListener(null)
        escapeDetectionService = null
        return true // Request rebind on disconnect
    }

    override fun onDestroy() {
        Log.d(TAG, "Service Destroyed")
        escapeDetectionService?.setListener(null)
        escapeDetectionService = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "AccessibilityMonitor"
    }
}

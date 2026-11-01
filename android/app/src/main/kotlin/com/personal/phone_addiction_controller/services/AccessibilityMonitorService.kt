package com.personal.phone_addiction_controller.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.Toast
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityWindowInfo
import com.personal.phone_addiction_controller.EscapeDetectionService
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.ForegroundApp
import com.personal.phone_addiction_controller.MainActivity
import com.personal.phone_addiction_controller.TamperGuard

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
    private var overlayManager: AccessibilityOverlayManager? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastTamperDismissAt = 0L
    private var lastTamperPromptAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Service Connected")
        instance = this
        FocusModeManager.init(this)
        TamperGuard.init(this)

        val info = serviceInfo ?: android.accessibilityservice.AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or AccessibilityEvent.TYPE_WINDOWS_CHANGED
        info.feedbackType = android.accessibilityservice.AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.flags = android.accessibilityservice.AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
            android.accessibilityservice.AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        info.notificationTimeout = 50
        info.packageNames = null
        serviceInfo = info

        overlayManager = AccessibilityOverlayManager(this)

        escapeDetectionService = EscapeDetectionService(this)
        escapeDetectionService?.setListener(object : EscapeDetectionService.AppChangeListener {
            override fun onForegroundAppChanged(app: ForegroundApp) {
                // No consumer; foreground tracking is kept in FocusModeManager.
            }

            override fun onAppBlocked(packageName: String, appName: String) {
                overlayManager?.showOverlay(packageName, appName)
            }

            override fun onAppAllowed(packageName: String) {
                if (packageName != applicationContext.packageName) {
                    overlayManager?.hideOverlay()
                }
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
        if (packageName.isNullOrBlank()) return
        val className = event.className?.toString()
        Log.d(TAG, "onAccessibilityEvent: type=$eventType pkg=$packageName class=$className")

        // Best-effort guard: dismiss Detox's own removal/control screens.
        // Window content is often not populated on the first event, so re-check shortly after.
        if (TamperGuard.isProtectionEnabled && !TamperGuard.isUnlocked) {
            if (dismissIfTampering(packageName)) return
            for (delay in TAMPER_RECHECK_DELAYS_MS) {
                mainHandler.postDelayed({ dismissIfTampering(packageName) }, delay)
            }
        }

        escapeDetectionService?.handleForegroundPackage(packageName, className)
    }

    private fun dismissIfTampering(packageName: String): Boolean {
        if (!TamperGuard.isProtectionEnabled || TamperGuard.isUnlocked) return false
        // Only act while the screen we were asked about is still the active window.
        val root = rootInActiveWindow ?: return false
        if (root.packageName?.toString() != packageName) return false
        val blocked = TamperGuard.shouldBlock(this, packageName, root)
        if (!blocked) return false

        val now = System.currentTimeMillis()
        if (now - lastTamperDismissAt > TAMPER_TOAST_COOLDOWN_MS) {
            Toast.makeText(
                this,
                "Protected by Detox - admin password required.",
                Toast.LENGTH_LONG
            ).show()
        }
        lastTamperDismissAt = now
        performGlobalAction(GLOBAL_ACTION_HOME)

        // Avoid stacking authentication activities when Android emits repeated window events.
        if (now - lastTamperPromptAt >= TAMPER_PROMPT_COOLDOWN_MS) {
            lastTamperPromptAt = now
            try {
                val intent = Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    putExtra(MainActivity.EXTRA_PROMPT_UNINSTALL, true)
                }
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch MainActivity for admin uninstall prompt", e)
            }
        }

        return true
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
        if (instance == this) {
            instance = null
        }
        return true // Request rebind on disconnect
    }

    override fun onDestroy() {
        Log.d(TAG, "Service Destroyed")
        mainHandler.removeCallbacksAndMessages(null)
        escapeDetectionService?.setListener(null)
        escapeDetectionService = null
        if (instance == this) {
            instance = null
        }
        super.onDestroy()
    }

    fun hideOverlay() {
        overlayManager?.hideOverlay()
    }

    companion object {
        private const val TAG = "AccessibilityMonitor"
        private const val TAMPER_TOAST_COOLDOWN_MS = 3_000L
        private const val TAMPER_PROMPT_COOLDOWN_MS = 1_500L
        private val TAMPER_RECHECK_DELAYS_MS = longArrayOf(350L, 900L)
        var instance: AccessibilityMonitorService? = null
    }
}

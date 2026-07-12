package com.personal.phone_addiction_controller

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.LruCache

data class ForegroundApp(
    val packageName: String,
    val appName: String
)

/**
 * Centralized Foreground Validation Pipeline.
 *
 * All foreground package transitions flow through here:
 *
 *   Accessibility Events
 *         ↓
 *   handleForegroundPackage(packageName)
 *         ↓
 *   FocusPolicyEngine.evaluate()
 *         ↓
 *   ALLOW → notify listener
 *   BLOCK → launch Focus Home (with staggered retry)
 *
 * This class contains ZERO policy logic of its own.
 * All decisions are delegated to [FocusPolicyEngine].
 */
class EscapeDetectionService(private val context: Context) {

    interface AppChangeListener {
        fun onForegroundAppChanged(app: ForegroundApp)
        fun onAppBlocked(packageName: String, appName: String)
        fun forceHome()
    }

    private val policyEngine = FocusPolicyEngine(context)
    private val appNameCache = LruCache<String, String>(200)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var listener: AppChangeListener? = null
    private var currentPackage: String = ""
    private var lastEventTime: Long = 0
    private var lastRecoveryTime: Long = 0
    private var lastRecoveryPackage: String = ""

    // Minimum ms between processing duplicate events for the same package
    private val eventDedupingMs = 100L
    // Minimum ms between successive redirects for the same blocked package
    private val recoveryCooldownMs = 800L
    // Delay intervals for the staggered retry launches (ms)
    private val retryDelaysMs = longArrayOf(0L, 400L, 900L)

    fun setListener(listener: AppChangeListener?) {
        this.listener = listener
    }

    /**
     * Entry point for ALL foreground package observations.
     * Called by AccessibilityMonitorService for every window event.
     */
    fun handleForegroundPackage(packageName: String?, className: String? = null) {
        if (packageName.isNullOrEmpty()) return

        val now = System.currentTimeMillis()

        // Deduplicate: ignore rapid repeat events for the same package
        if (packageName == currentPackage && now - lastEventTime < eventDedupingMs) return
        lastEventTime = now
        currentPackage = packageName

        FocusModeManager.foregroundPackageName = packageName

        val appName = getAppName(packageName)
        listener?.onForegroundAppChanged(ForegroundApp(packageName, appName))

        // Delegate the actual policy decision to FocusPolicyEngine.
        // This is the ONLY place that decides ALLOW or BLOCK.
        val decision = policyEngine.evaluate(packageName, className)

        if (decision == FocusPolicyEngine.Decision.BLOCK) {
            enforceBlock(packageName, appName, now)
        }
    }

    // ── Private: Enforcement ─────────────────────────────────────────────────

    private fun enforceBlock(packageName: String, appName: String, now: Long) {
        // Cooldown: prevent rapid re-launching Focus Home for the same blocked app
        if (packageName == lastRecoveryPackage && now - lastRecoveryTime < recoveryCooldownMs) {
            return
        }
        lastRecoveryPackage = packageName
        lastRecoveryTime = now

        Log.d(TAG, "BLOCKING: $appName ($packageName) → redirecting to Focus Home")
        listener?.onAppBlocked(packageName, appName)
        
        // Immediately collapse the Recent Apps UI / System UI to prevent 
        // the user from interacting with it during the 5-second restriction window.
        listener?.forceHome()

        // Staggered retries to defeat Android's 5-second background launch restriction
        // that activates after a Home button press.
        for (delayMs in retryDelaysMs) {
            mainHandler.postDelayed({
                launchFocusHome(packageName, appName)
            }, delayMs)
        }
    }

    private fun launchFocusHome(packageName: String, appName: String) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra("focus_recovery", true)
                putExtra("blocked_package", packageName)
                putExtra("blocked_app_name", appName)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch Focus Home", e)
        }
    }

    // ── Private: Helpers ─────────────────────────────────────────────────────

    private fun getAppName(packageName: String): String {
        appNameCache.get(packageName)?.let { return it }
        val name = try {
            val info = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(info).toString()
        } catch (_: PackageManager.NameNotFoundException) {
            packageName
        }
        appNameCache.put(packageName, name)
        return name
    }

    companion object {
        private const val TAG = "EscapeDetection"
    }
}

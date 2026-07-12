package com.personal.phone_addiction_controller.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.provider.Settings
import android.text.TextUtils
import com.personal.phone_addiction_controller.DiagnosticsLogger
import com.personal.phone_addiction_controller.FlutterBridge
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.NotificationHelper
import com.personal.phone_addiction_controller.receivers.ScreenReceiver

/**
 * Foreground service that:
 * 1. Shows a persistent notification while Focus Mode is active.
 * 2. Updates the remaining time every minute.
 * 3. Runs a lightweight Watchdog every 30 seconds to verify and recover all
 *    Focus Mode components.
 * 4. Dynamically registers a ScreenReceiver for Focus Lock Screen.
 */
class FocusForegroundService : Service() {

    private val handler = Handler(Looper.getMainLooper())
    private var screenReceiver: ScreenReceiver? = null

    // ── Notification Update (every 60s) ─────────────────────────────────────
    private val updateRunnable = object : Runnable {
        override fun run() {
            updateNotification()
            handler.postDelayed(this, 60_000)
        }
    }

    // ── Watchdog (every 30s) ────────────────────────────────────────────────
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            runWatchdog()
            handler.postDelayed(this, WATCHDOG_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createNotificationChannels(this)
        FocusModeManager.init(this)
        DiagnosticsLogger.init(this)
        Log.d(TAG, "FocusForegroundService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationHelper.buildFocusNotification(
            this,
            getRemainingText()
        ).build()

        startForeground(NotificationHelper.FOCUS_NOTIFICATION_ID, notification)
        handler.post(updateRunnable)
        handler.postDelayed(watchdogRunnable, WATCHDOG_INTERVAL_MS)
        DiagnosticsLogger.foregroundServiceStarted()
        Log.d(TAG, "FocusForegroundService started")

        // Register ScreenReceiver dynamically
        registerScreenReceiver()

        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        handler.removeCallbacks(watchdogRunnable)
        unregisterScreenReceiver()
        DiagnosticsLogger.foregroundServiceStopped()
        Log.d(TAG, "FocusForegroundService destroyed")
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ── Notification ────────────────────────────────────────────────────────

    private fun updateNotification() {
        if (!FocusModeManager.isActive) {
            stopSelf()
            return
        }
        val notification = NotificationHelper.buildFocusNotification(
            this,
            getRemainingText()
        ).build()

        val nm = getSystemService(android.app.NotificationManager::class.java)
        nm.notify(NotificationHelper.FOCUS_NOTIFICATION_ID, notification)
    }

    private fun getRemainingText(): String {
        val endTime = FocusModeManager.scheduledEndTime
        if (endTime <= 0) {
            val startTime = FocusModeManager.sessionStartTime
            if (startTime > 0) {
                val elapsed = System.currentTimeMillis() - startTime
                val minutes = (elapsed / 60_000).toInt()
                val hours = minutes / 60
                val mins = minutes % 60
                return if (hours > 0) "Active for ${hours}h ${mins}m" else "Active for ${mins}m"
            }
            return "Focus Mode Active"
        }

        val remaining = endTime - System.currentTimeMillis()
        if (remaining <= 0) return "Ending soon..."

        val minutes = (remaining / 60_000).toInt()
        val hours = minutes / 60
        val mins = minutes % 60
        return if (hours > 0) "${hours}h ${mins}m remaining" else "${mins}m remaining"
    }

    // ── ScreenReceiver (dynamic registration) ───────────────────────────────

    private fun registerScreenReceiver() {
        if (screenReceiver != null) return
        screenReceiver = ScreenReceiver()
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        Log.d(TAG, "ScreenReceiver registered")
    }

    private fun unregisterScreenReceiver() {
        screenReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {}
            screenReceiver = null
            Log.d(TAG, "ScreenReceiver unregistered")
        }
    }

    // ── Watchdog ────────────────────────────────────────────────────────────

    private fun runWatchdog() {
        if (!FocusModeManager.isActive) {
            // Focus ended while service is still running — stop self
            Log.d(TAG, "Watchdog: Focus not active, stopping service")
            stopSelf()
            return
        }

        // Check 1: Accessibility Service running
        if (!isAccessibilityServiceRunning()) {
            Log.w(TAG, "Watchdog: Accessibility service not running!")
            DiagnosticsLogger.watchdogRepair("Accessibility", "Service not running — cannot auto-restart (requires user action)")
            // Cannot auto-restart accessibility — it requires user action in Android.
            // But we log the issue so diagnostics can show it.
        }

        // Check 2: Foreground Service alive (we are it, so yes by definition)
        // Just a sanity log
        DiagnosticsLogger.watchdogCheckPassed()

        // 3. In strict mode, verify Lock Task is active ONLY when our own app is
        // the expected foreground. If LTM exited while Focus Home should be showing,
        // delegate LTM restoration to FlutterBridge -> FocusEnvironmentManager.enterFocusEnvironment().
        //
        // ARCHITECTURE RULE: The watchdog MUST NOT call startActivity() or navigate.
        // It delegates to FlutterBridge.requestLockTaskRestore() which re-enters LTM
        // via the existing MainActivity reference — no focusRecover, no navigation.
        if (FocusModeManager.strictMode) {
            try {
                val fgPkg = FocusModeManager.foregroundPackageName
                val ourPackage = packageName

                // Only attempt LTM recovery if our own app is the current foreground,
                // or if there is no recorded foreground package (just started).
                // When an allowed 3rd-party app is foreground, LTM is correctly NONE.
                val ourAppExpectedInForeground = fgPkg == ourPackage

                if (ourAppExpectedInForeground) {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                    if (activityManager.lockTaskModeState == android.app.ActivityManager.LOCK_TASK_MODE_NONE) {
                        Log.w(TAG, "Watchdog: Focus Home is foreground but LTM not active — delegating restore")
                        DiagnosticsLogger.watchdogRepair("LockTask", "LTM inactive while Focus Home foreground — requesting restore")
                        // Delegate: re-enter LTM only, no navigation.
                        FlutterBridge.requestLockTaskRestore()
                    }
                } else {
                    Log.d(TAG, "Watchdog: package ($fgPkg) is foreground — LTM state is expected, skipping recovery")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Watchdog: Error checking Lock Task", e)
            }
        }

        // Check 4: Ensure Focus Home activity is reachable
        try {
            val pm = packageManager
            val launchIntent = pm.getLaunchIntentForPackage(packageName)
            if (launchIntent == null) {
                Log.w(TAG, "Watchdog: Focus Home not reachable!")
                DiagnosticsLogger.watchdogRepair("FocusHome", "Launch intent not resolvable")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Watchdog: Error checking Focus Home", e)
        }
    }

    private fun isAccessibilityServiceRunning(): Boolean {
        return try {
            val serviceId = "$packageName/com.personal.phone_addiction_controller.services.AccessibilityMonitorService"
            val enabledServices = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            ) ?: return false

            val colonSplitter = TextUtils.SimpleStringSplitter(':')
            colonSplitter.setString(enabledServices)

            while (colonSplitter.hasNext()) {
                val componentName = colonSplitter.next()
                if (componentName.equals(serviceId, ignoreCase = true)) {
                    return true
                }
            }
            false
        } catch (_: Exception) {
            false
        }
    }

    // ── Watchdog: LTM Restore (no navigation) ───────────────────────────────
    // NOTE: launchMainActivityForRecovery() has been REMOVED.
    // LTM restoration is now handled by FlutterBridge.requestLockTaskRestore()
    // which calls FocusEnvironmentManager.enterFocusEnvironment() directly — no startActivity(),
    // no focusRecover method call, no Flutter navigation. This ensures the watchdog
    // never overrides a FocusPolicyEngine ALLOW decision.

    companion object {
        private const val TAG = "FocusForegroundService"
        private const val WATCHDOG_INTERVAL_MS = 30_000L

        fun start(context: Context) {
            val intent = Intent(context, FocusForegroundService::class.java)
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start foreground service", e)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, FocusForegroundService::class.java)
            context.stopService(intent)
        }

        fun isRunning(context: Context): Boolean {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            @Suppress("DEPRECATION")
            for (service in activityManager.getRunningServices(Int.MAX_VALUE)) {
                if (FocusForegroundService::class.java.name == service.service.className) {
                    return true
                }
            }
            return false
        }
    }
}

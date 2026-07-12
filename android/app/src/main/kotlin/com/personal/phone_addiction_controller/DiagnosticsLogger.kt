package com.personal.phone_addiction_controller

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Unified diagnostic logger for FocusOS.
 *
 * Persists the last [MAX_EVENTS] lifecycle events to SharedPreferences
 * as a JSON array, consumable by the Flutter Diagnostics screen.
 *
 * Categories:
 *  - ROUTINE  (scheduled routine lifecycle)
 *  - WATCHDOG (automatic recovery)
 *  - BOOT    (boot/update recovery)
 *  - SERVICE (foreground service lifecycle)
 *  - SESSION (focus session lifecycle)
 */
object DiagnosticsLogger {
    private const val TAG = "DiagnosticsLogger"
    private const val PREFS_NAME = "DiagnosticsPrefs"
    private const val KEY_EVENTS = "events"
    private const val KEY_LAST_BOOT_TIME = "lastBootTime"
    private const val KEY_LAST_WATCHDOG_REPAIR = "lastWatchdogRepair"
    private const val KEY_LAST_BLOCKED_APP = "lastBlockedApp"
    private const val KEY_LAST_RECOVERY_EVENT = "lastRecoveryEvent"
    private const val MAX_EVENTS = 100

    private lateinit var prefs: SharedPreferences

    fun init(context: Context) {
        if (!::prefs.isInitialized) {
            prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    // ── Routine Lifecycle ───────────────────────────────────────────────────

    fun routineCreated(routineId: String) =
        log("ROUTINE", "CREATED", "Routine $routineId created/scheduled")

    fun routineStarted(routineId: String) =
        log("ROUTINE", "STARTED", "Routine $routineId alarm fired (START)")

    fun routineSnapshotCreated(routineId: String) =
        log("ROUTINE", "SNAPSHOT_CREATED", "FocusSessionSnapshot created for routine $routineId")

    fun routineForegroundServiceStarted(routineId: String) =
        log("ROUTINE", "FGS_STARTED", "Foreground service started for routine $routineId")

    fun routineLockTaskStarted(routineId: String) =
        log("ROUTINE", "LOCK_TASK_STARTED", "Lock Task Mode started for routine $routineId")

    fun routineAccessibilityStarted(routineId: String) =
        log("ROUTINE", "ACCESSIBILITY_STARTED", "Accessibility monitoring active for routine $routineId")

    fun routineEnded(routineId: String) =
        log("ROUTINE", "ENDED", "Routine $routineId alarm fired (STOP)")

    fun routineCancelled(routineId: String) =
        log("ROUTINE", "CANCELLED", "Routine $routineId cancelled")

    fun routineInterrupted(routineId: String, reason: String) =
        log("ROUTINE", "INTERRUPTED", "Routine $routineId interrupted: $reason")

    fun routineRestoredAfterReboot(routineId: String) =
        log("ROUTINE", "RESTORED_AFTER_REBOOT", "Routine $routineId restored after reboot")

    // ── Boot / Update Recovery ──────────────────────────────────────────────

    fun bootRecoveryStarted() {
        log("BOOT", "RECOVERY_STARTED", "Boot completed — starting recovery")
        if (::prefs.isInitialized) {
            prefs.edit().putLong(KEY_LAST_BOOT_TIME, System.currentTimeMillis()).apply()
        }
    }

    fun bootRecoveryCompleted(sessionRestored: Boolean) =
        log("BOOT", "RECOVERY_COMPLETED", "Boot recovery done. Session restored: $sessionRestored")

    fun updateRecoveryStarted() =
        log("BOOT", "UPDATE_RECOVERY", "MY_PACKAGE_REPLACED — recovering state")

    // ── Watchdog ────────────────────────────────────────────────────────────

    fun watchdogRepair(component: String, action: String) {
        val msg = "Watchdog repaired $component: $action"
        log("WATCHDOG", "REPAIR", msg)
        if (::prefs.isInitialized) {
            prefs.edit().putString(KEY_LAST_WATCHDOG_REPAIR, "$component|$action|${System.currentTimeMillis()}").apply()
        }
    }

    fun watchdogCheckPassed() {
        // Intentionally no-op to avoid flooding the log.
        // Un-comment below for extreme debugging:
        // log("WATCHDOG", "CHECK_PASSED", "All components healthy")
    }

    // ── Service Lifecycle ───────────────────────────────────────────────────

    fun foregroundServiceStarted() =
        log("SERVICE", "FGS_STARTED", "FocusForegroundService started")

    fun foregroundServiceStopped() =
        log("SERVICE", "FGS_STOPPED", "FocusForegroundService stopped")

    // ── Session Lifecycle ───────────────────────────────────────────────────

    fun sessionStarted(scheduled: Boolean, routineId: String?) =
        log("SESSION", "STARTED", "Focus session started (scheduled=$scheduled, routineId=$routineId)")

    fun sessionEnded() =
        log("SESSION", "ENDED", "Focus session ended")

    // ── Blocked App ─────────────────────────────────────────────────────────

    fun appBlocked(packageName: String) {
        if (::prefs.isInitialized) {
            prefs.edit().putString(KEY_LAST_BLOCKED_APP, "$packageName|${System.currentTimeMillis()}").apply()
        }
    }

    // ── Queries (for Diagnostics screen) ────────────────────────────────────

    fun getLastBootTime(): Long =
        if (::prefs.isInitialized) prefs.getLong(KEY_LAST_BOOT_TIME, 0L) else 0L

    fun getLastWatchdogRepair(): String =
        if (::prefs.isInitialized) prefs.getString(KEY_LAST_WATCHDOG_REPAIR, "") ?: "" else ""

    fun getLastBlockedApp(): String =
        if (::prefs.isInitialized) prefs.getString(KEY_LAST_BLOCKED_APP, "") ?: "" else ""

    fun getLastRecoveryEvent(): String =
        if (::prefs.isInitialized) prefs.getString(KEY_LAST_RECOVERY_EVENT, "") ?: "" else ""

    fun getAllEvents(): String {
        if (!::prefs.isInitialized) return "[]"
        return prefs.getString(KEY_EVENTS, "[]") ?: "[]"
    }

    // ── Internal ────────────────────────────────────────────────────────────

    private fun log(category: String, event: String, message: String) {
        Log.d(TAG, "[$category/$event] $message")
        if (!::prefs.isInitialized) return

        try {
            val raw = prefs.getString(KEY_EVENTS, "[]") ?: "[]"
            val arr = try { JSONArray(raw) } catch (_: Exception) { JSONArray() }

            val entry = JSONObject().apply {
                put("ts", System.currentTimeMillis())
                put("cat", category)
                put("evt", event)
                put("msg", message)
            }
            arr.put(entry)

            // Trim to last MAX_EVENTS
            while (arr.length() > MAX_EVENTS) {
                arr.remove(0)
            }

            prefs.edit()
                .putString(KEY_EVENTS, arr.toString())
                .putString(KEY_LAST_RECOVERY_EVENT, "$category/$event|${System.currentTimeMillis()}")
                .apply()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist event", e)
        }
    }
}

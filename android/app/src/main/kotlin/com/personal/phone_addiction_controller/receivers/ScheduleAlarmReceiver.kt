package com.personal.phone_addiction_controller.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personal.phone_addiction_controller.DiagnosticsLogger
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.ScheduleManager
import com.personal.phone_addiction_controller.FocusSessionController

/**
 * Receives alarms from [ScheduleManager] to start or stop Focus Mode.
 *
 * On START:
 *   1. Initialises FocusModeManager with native state
 *   2. Starts the persistent FocusForegroundService (notification)
 *   3. Re-schedules the next occurrence of this alarm
 *
 * On STOP:
 *   1. Ends the native focus session
 *   2. Stops the FocusForegroundService
 *   3. Re-schedules the next occurrence of this alarm
 *
 * Every lifecycle event is recorded to [DiagnosticsLogger].
 */
class ScheduleAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val routineId = intent.getStringExtra(ScheduleManager.EXTRA_ROUTINE_ID) ?: run {
            Log.e(TAG, "Alarm received without routine_id — ignoring")
            return
        }
        val isStart = intent.getBooleanExtra(ScheduleManager.EXTRA_IS_START, true)

        Log.d(TAG, "Alarm received: routine=$routineId isStart=$isStart")

        // Always initialise before touching any prefs-backed property
        FocusModeManager.init(context)
        DiagnosticsLogger.init(context)

        if (isStart) {
            handleStart(context, routineId)
        } else {
            handleStop(context, routineId)
        }

        // Re-schedule the next occurrence so the routine repeats weekly
        rescheduleNext(context, routineId)
    }

    // ── Handlers ────────────────────────────────────────────────────────────

    private fun handleStart(context: Context, routineId: String) {
        DiagnosticsLogger.routineStarted(routineId)

        if (FocusModeManager.isActive) {
            Log.d(TAG, "Focus mode already active — updating activeRoutineId for $routineId")
            FocusModeManager.activeRoutineId = routineId
            FocusModeManager.isScheduled = true
        } else {
            // 1. Set native focus state (persisted immediately to SharedPreferences)
            FocusModeManager.startSession(scheduled = true, routineId = routineId)
            DiagnosticsLogger.sessionStarted(scheduled = true, routineId = routineId)
        }

        // 2. Load blocked apps for this routine if specified in routine JSON
        try {
            val scheduleManager = ScheduleManager(context)
            val routineJson = scheduleManager.getAllRoutines()[routineId]
            if (routineJson != null) {
                val obj = org.json.JSONObject(routineJson)
                if (obj.has("blockedPackages")) {
                    val arr = obj.getJSONArray("blockedPackages")
                    val pkgs = mutableSetOf<String>()
                    for (i in 0 until arr.length()) pkgs.add(arr.getString(i))
                    if (pkgs.isNotEmpty()) {
                        FocusModeManager.blockedPackages = pkgs
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error loading blocked packages for routine $routineId", e)
        }

        // 3. Start the persistent foreground notification and apply native Focus policies immediately
        FocusSessionController.ensureServiceRunning(context)
        DiagnosticsLogger.routineForegroundServiceStarted(routineId)

        // In Personal Mode, do NOT launch MainActivity. Focus runs seamlessly in background.
        Log.d(TAG, "Focus session started in background by routine: $routineId")
    }

    private fun handleStop(context: Context, routineId: String) {
        DiagnosticsLogger.routineEnded(routineId)

        if (!FocusModeManager.isActive) {
            DiagnosticsLogger.routineInterrupted(routineId, "Stop received but Focus was not active")
            return
        }

        // Precedence Check:
        // 1. Check if a manual session is currently running
        val now = System.currentTimeMillis()
        val manualActive = !FocusModeManager.isScheduled &&
            FocusModeManager.scheduledEndTime > 0L &&
            now < FocusModeManager.scheduledEndTime

        // 2. Check if any scheduled routine is still running
        val scheduleManager = ScheduleManager(context)
        val routineActive = scheduleManager.isAnyRoutineActive()

        if (manualActive || routineActive) {
            Log.d(TAG, "Precedence check: manual session ($manualActive) or routine ($routineActive) still active — not stopping focus mode")
            DiagnosticsLogger.routineInterrupted(routineId, "Stop deferred: session or other routine still active")
            return
        }

        FocusSessionController.endSession(context)
        DiagnosticsLogger.sessionEnded()
        Log.d(TAG, "Focus session ended by routine: $routineId")
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun rescheduleNext(context: Context, routineId: String) {
        try {
            val scheduleManager = ScheduleManager(context)
            val routineJson = scheduleManager.getAllRoutines()[routineId]
            if (routineJson != null) {
                scheduleManager.scheduleRoutine(routineJson)
            } else {
                Log.w(TAG, "No stored JSON found for routine $routineId — cannot reschedule")
                DiagnosticsLogger.routineInterrupted(routineId, "No stored JSON — cannot reschedule")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule routine $routineId", e)
            DiagnosticsLogger.routineInterrupted(routineId, "Reschedule failed: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "ScheduleAlarmReceiver"
    }
}

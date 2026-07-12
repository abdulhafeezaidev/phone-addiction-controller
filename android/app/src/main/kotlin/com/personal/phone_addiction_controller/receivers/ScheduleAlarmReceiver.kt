package com.personal.phone_addiction_controller.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personal.phone_addiction_controller.DiagnosticsLogger
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.MainActivity
import com.personal.phone_addiction_controller.ScheduleManager
import com.personal.phone_addiction_controller.FocusEnvironmentManager
import com.personal.phone_addiction_controller.services.FocusForegroundService

/**
 * Receives alarms from [ScheduleManager] to start or stop Focus Mode.
 *
 * On START:
 *   1. Initialises FocusModeManager with native state
 *   2. Starts the persistent FocusForegroundService (notification)
 *   3. Launches MainActivity with [EXTRA_ROUTINE_TRIGGERED] so the Flutter
 *      layer can create the FocusSessionSnapshot and navigate to Focus Home
 *   4. Re-schedules the next occurrence of this alarm
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
            Log.d(TAG, "Focus mode already active — skipping duplicate start for $routineId")
            DiagnosticsLogger.routineInterrupted(routineId, "Skipped: Focus already active")
            return
        }

        // 1. Set native focus state (persisted immediately to SharedPreferences)
        FocusModeManager.startSession(scheduled = true, routineId = routineId)
        DiagnosticsLogger.sessionStarted(scheduled = true, routineId = routineId)

        // 2. Start the persistent foreground notification and apply native Focus policies immediately
        FocusEnvironmentManager(context).enterFocusEnvironment()
        DiagnosticsLogger.routineForegroundServiceStarted(routineId)

        // 3. Launch MainActivity (and thereby the Flutter engine) with a signal
        //    telling the Flutter layer to: create the FocusSessionSnapshot,
        //    update allowed apps, and navigate to the Focus Home screen.
        launchMainActivityForRoutine(context, routineId)
        DiagnosticsLogger.routineSnapshotCreated(routineId)

        Log.d(TAG, "Focus session started by routine: $routineId")
    }

    private fun handleStop(context: Context, routineId: String) {
        DiagnosticsLogger.routineEnded(routineId)

        if (!FocusModeManager.isActive) {
            DiagnosticsLogger.routineInterrupted(routineId, "Stop received but Focus was not active")
            return
        }

        // Only stop if no other routine is still running
        val scheduleManager = ScheduleManager(context)
        if (scheduleManager.isAnyRoutineActive()) {
            Log.d(TAG, "Another routine slot is still active — not stopping")
            DiagnosticsLogger.routineInterrupted(routineId, "Stop deferred: another routine still active")
            return
        }

        FocusModeManager.endSession()
        FocusEnvironmentManager(context).exitFocusEnvironment()
        DiagnosticsLogger.sessionEnded()
        Log.d(TAG, "Focus session ended by routine: $routineId")
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private fun launchMainActivityForRoutine(context: Context, routineId: String) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra(EXTRA_ROUTINE_TRIGGERED, true)
                putExtra(EXTRA_TRIGGERED_ROUTINE_ID, routineId)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity for routine $routineId", e)
            DiagnosticsLogger.routineInterrupted(routineId, "Failed to launch MainActivity: ${e.message}")
        }
    }

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

        /** Intent extra: signals Flutter that a routine triggered automatically. */
        const val EXTRA_ROUTINE_TRIGGERED    = "routine_triggered"
        /** Intent extra: the routine ID that triggered. */
        const val EXTRA_TRIGGERED_ROUTINE_ID = "triggered_routine_id"
    }
}

package com.personal.phone_addiction_controller

import android.content.Context
import android.util.Log
import com.personal.phone_addiction_controller.services.AccessibilityMonitorService
import com.personal.phone_addiction_controller.services.FocusForegroundService
import org.json.JSONObject

/**
 * Starts and stops Focus sessions. Every entry point (Flutter, routine alarms,
 * boot recovery) goes through here so session state and the foreground service
 * can never drift apart.
 */
object FocusSessionController {
    private const val TAG = "FocusSessionController"

    /** Starts a quick session that ends automatically at [endTimeMs]. */
    fun startQuickSession(context: Context, endTimeMs: Long, blocked: Set<String>) {
        FocusModeManager.init(context)
        FocusModeManager.blockedPackages = blocked
        FocusModeManager.startSession(scheduled = false, routineId = null)
        FocusModeManager.scheduledEndTime = endTimeMs
        ensureServiceRunning(context)
    }

    /** Ends the session, stops the service and removes any visible block overlay. */
    fun endSession(context: Context) {
        FocusModeManager.init(context)
        FocusModeManager.endSession()
        FocusForegroundService.stop(context)
        AccessibilityMonitorService.instance?.hideOverlay()
    }

    /**
     * Called when a quick session passes its end time. If a routine is active right now the
     * session is handed over to it, otherwise the session ends.
     */
    fun onQuickSessionExpired(context: Context) {
        FocusModeManager.init(context)
        val activeJson = ScheduleManager(context).getActiveRoutineJson()
        if (activeJson == null) {
            endSession(context)
            return
        }
        val obj = JSONObject(activeJson)
        val blocked = mutableSetOf<String>()
        obj.optJSONArray("blockedPackages")?.let { arr ->
            for (i in 0 until arr.length()) blocked.add(arr.getString(i))
            FocusModeManager.blockedPackages = blocked
        }
        FocusModeManager.isScheduled = true
        FocusModeManager.scheduledEndTime = 0L
        FocusModeManager.activeRoutineId = obj.optString("id")
    }

    /** Starts the foreground service if a session is running and not overridden. */
    fun ensureServiceRunning(context: Context) {
        FocusModeManager.init(context)
        if (!FocusModeManager.isActive) return
        try {
            FocusForegroundService.start(context)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start FocusForegroundService", e)
        }
    }

    /**
     * Aligns the running session with the stored routines: starts a session if a
     * routine is active right now, or ends a routine-driven session whose routine
     * was removed/disabled. Safe to call at any time.
     */
    fun reconcileWithRoutines(context: Context) {
        FocusModeManager.init(context)
        val activeJson = ScheduleManager(context).getActiveRoutineJson()
        if (FocusModeManager.isActive) {
            if (FocusModeManager.isScheduled && activeJson == null) {
                Log.d(TAG, "Routine session no longer backed by an active routine - ending")
                endSession(context)
            }
            return
        }
        if (activeJson == null) return

        val obj = JSONObject(activeJson)
        val blocked = mutableSetOf<String>()
        obj.optJSONArray("blockedPackages")?.let { arr ->
            for (i in 0 until arr.length()) blocked.add(arr.getString(i))
            FocusModeManager.blockedPackages = blocked
        }
        FocusModeManager.startSession(scheduled = true, routineId = obj.optString("id"))
        ensureServiceRunning(context)
    }
}

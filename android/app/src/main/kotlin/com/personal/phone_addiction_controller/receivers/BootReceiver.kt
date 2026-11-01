package com.personal.phone_addiction_controller.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personal.phone_addiction_controller.DiagnosticsLogger
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.FocusSessionController
import com.personal.phone_addiction_controller.NotificationHelper
import com.personal.phone_addiction_controller.ScheduleManager

/**
 * Restores routine alarms and any running Focus session after a reboot, app update
 * or system time change. Runs entirely natively; the Flutter UI is not launched.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_TIME_CHANGED &&
            action != Intent.ACTION_TIMEZONE_CHANGED &&
            action != Intent.ACTION_DATE_CHANGED
        ) return

        Log.d(TAG, "Received broadcast: $action")

        try {
            FocusModeManager.init(context)
            DiagnosticsLogger.init(context)
            NotificationHelper.createNotificationChannels(context)

            when (action) {
                Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                    // Direct boot: credential-protected storage is unavailable; wait for BOOT_COMPLETED.
                    DiagnosticsLogger.bootRecoveryStarted()
                }
                MY_PACKAGE_REPLACED -> {
                    DiagnosticsLogger.updateRecoveryStarted()
                    performFullRecovery(context)
                }
                else -> {
                    if (action == Intent.ACTION_BOOT_COMPLETED) DiagnosticsLogger.bootRecoveryStarted()
                    performFullRecovery(context)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring state after $action", e)
        }
    }

    private fun performFullRecovery(context: Context) {
        // 1. A quick session whose end time passed while the device was off is over.
        if (FocusModeManager.hasQuickSessionExpired()) {
            FocusSessionController.onQuickSessionExpired(context)
            DiagnosticsLogger.sessionEnded()
        }

        val wasActive = FocusModeManager.isActive

        // 2. Re-arm every stored routine alarm.
        ScheduleManager(context).rescheduleAllFromStorage()

        // 3. Align the session with the routines (starts one if a routine is active now).
        FocusSessionController.reconcileWithRoutines(context)

        // 4. Keep the foreground service alive for a running session.
        if (FocusModeManager.isActive) {
            FocusSessionController.ensureServiceRunning(context)
            DiagnosticsLogger.foregroundServiceStarted()
        }

        DiagnosticsLogger.bootRecoveryCompleted(sessionRestored = wasActive)
    }

    companion object {
        private const val TAG = "BootReceiver"
        private const val MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED"
    }
}

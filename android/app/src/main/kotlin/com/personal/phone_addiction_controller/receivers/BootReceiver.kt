package com.personal.phone_addiction_controller.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personal.phone_addiction_controller.DiagnosticsLogger
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.MainActivity
import com.personal.phone_addiction_controller.NotificationHelper
import com.personal.phone_addiction_controller.ScheduleManager
import com.personal.phone_addiction_controller.FocusEnvironmentManager
import com.personal.phone_addiction_controller.services.FocusForegroundService

/**
 * Receives BOOT_COMPLETED, LOCKED_BOOT_COMPLETED, and MY_PACKAGE_REPLACED
 * broadcasts to restore Focus Mode state after reboot or app update.
 *
 * Recovery pipeline:
 * 1. Initializes FocusModeManager from persisted SharedPreferences
 * 2. Initializes DiagnosticsLogger
 * 3. If focus mode was active:
 *    a. Restarts the Foreground Service
 *    b. Launches MainActivity with EXTRA_BOOT_RECOVERY so the Flutter layer
 *       restores FocusSessionSnapshot, Lock Task, and Focus Home
 * 4. Re-schedules all alarms for routines
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != MY_PACKAGE_REPLACED
        ) return

        Log.d(TAG, "Received broadcast: $action — restoring FocusOS state")

        try {
            // Initialize singletons
            FocusModeManager.init(context)
            DiagnosticsLogger.init(context)
            NotificationHelper.createNotificationChannels(context)

            when (action) {
                Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                    // Direct-boot: limited storage access; just mark boot time
                    DiagnosticsLogger.bootRecoveryStarted()
                    Log.d(TAG, "LOCKED_BOOT_COMPLETED — deferring full recovery to BOOT_COMPLETED")
                }

                Intent.ACTION_BOOT_COMPLETED -> {
                    DiagnosticsLogger.bootRecoveryStarted()
                    performFullRecovery(context)
                }

                MY_PACKAGE_REPLACED -> {
                    DiagnosticsLogger.updateRecoveryStarted()
                    performFullRecovery(context)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring state after $action", e)
        }
    }

    private fun performFullRecovery(context: Context) {
        val wasActive = FocusModeManager.isActive

        // Re-schedule all routines (even if focus isn't active — routines may fire later)
        val scheduleManager = ScheduleManager(context)
        scheduleManager.rescheduleAllFromStorage()
        Log.d(TAG, "All routines re-scheduled after recovery")

        if (wasActive) {
            Log.d(TAG, "Focus mode was active — restarting foreground service and launching Focus Home")

            // 1. Establish the Focus Environment (Foreground Service, Restrictions, Preferred Activity)
            FocusEnvironmentManager(context).enterFocusEnvironment()
            DiagnosticsLogger.foregroundServiceStarted()

            // 2. Launch MainActivity so Flutter can restore the FocusSessionSnapshot,
            //    re-enter Lock Task Mode, and navigate to Focus Home.
            launchMainActivityForBootRecovery(context)
        }

        DiagnosticsLogger.bootRecoveryCompleted(sessionRestored = wasActive)
    }

    private fun launchMainActivityForBootRecovery(context: Context) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
                putExtra(EXTRA_BOOT_RECOVERY, true)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch MainActivity for boot recovery", e)
        }
    }

    companion object {
        private const val TAG = "BootReceiver"
        private const val MY_PACKAGE_REPLACED = "android.intent.action.MY_PACKAGE_REPLACED"

        /** Intent extra: signals Flutter that a boot recovery is in progress. */
        const val EXTRA_BOOT_RECOVERY = "boot_recovery"
    }
}

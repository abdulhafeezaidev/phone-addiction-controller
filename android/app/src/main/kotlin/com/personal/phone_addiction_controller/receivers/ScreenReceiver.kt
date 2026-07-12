package com.personal.phone_addiction_controller.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.FocusPolicyEngine
import com.personal.phone_addiction_controller.MainActivity

/**
 * Receives SCREEN_OFF and SCREEN_ON broadcasts.
 *
 * When Focus Mode is active and the screen turns on, launches MainActivity
 * with [EXTRA_SCREEN_ON] so Flutter can push the Focus Lock Screen route.
 *
 * NOTE: SCREEN_OFF/SCREEN_ON broadcasts are NOT delivered to manifest-declared
 * receivers on modern Android. They must be registered dynamically. This class
 * is registered dynamically by [FocusForegroundService] when Focus Mode is active.
 */
class ScreenReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_SCREEN_OFF -> {
                Log.d(TAG, "Screen OFF")
                // No action needed — the lock screen will show on SCREEN_ON
            }
            Intent.ACTION_SCREEN_ON -> {
                Log.d(TAG, "Screen ON")
                if (FocusModeManager.isActive && !FocusModeManager.isEmergencyOverrideActive()) {
                    launchLockScreen(context)
                }
            }
            Intent.ACTION_USER_PRESENT -> {
                Log.d(TAG, "User present (device unlocked)")
                // Device was unlocked. Only launch Focus Home if there is NO allowed app
                // currently in the foreground. If an allowed app is running, do nothing —
                // the user should return to it uninterrupted.
                //
                // Architecture rule: FocusPolicyEngine is the ONLY navigation authority.
                // This receiver must consult the engine before deciding to navigate.
                if (FocusModeManager.isActive && !FocusModeManager.isEmergencyOverrideActive()) {
                    val fgPkg = FocusModeManager.foregroundPackageName
                    val decision = if (!fgPkg.isNullOrBlank()) {
                        FocusPolicyEngine(context).evaluate(fgPkg)
                    } else {
                        // No foreground package known — default BLOCK (launch Focus Home)
                        FocusPolicyEngine.Decision.BLOCK
                    }

                    if (decision == FocusPolicyEngine.Decision.BLOCK) {
                        Log.d(TAG, "User present: blocked app ($fgPkg) — launching Focus Home")
                        launchFocusHome(context)
                    } else {
                        Log.d(TAG, "User present: allowed app ($fgPkg) is foreground — not interrupting")
                    }
                }
            }
        }
    }

    private fun launchLockScreen(context: Context) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra(EXTRA_SCREEN_ON, true)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch lock screen", e)
        }
    }

    private fun launchFocusHome(context: Context) {
        try {
            val intent = Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                )
                putExtra("focus_recovery", true)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch Focus Home after unlock", e)
        }
    }

    companion object {
        private const val TAG = "ScreenReceiver"

        /** Intent extra: signals Flutter to show the Focus Lock Screen. */
        const val EXTRA_SCREEN_ON = "screen_on_lock"
    }
}

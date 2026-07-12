package com.personal.phone_addiction_controller

import android.content.Context
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.util.Log
import com.personal.phone_addiction_controller.receivers.FocusDeviceAdminReceiver
import com.personal.phone_addiction_controller.receivers.ScheduleAlarmReceiver
import com.personal.phone_addiction_controller.receivers.ScreenReceiver
import com.personal.phone_addiction_controller.receivers.BootReceiver
import android.content.Intent
import android.os.Build
import android.os.UserManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val navChannelName = "com.personal.phone_addiction_controller/navigation"
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val TAG = "MainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterBridge.initialize(context, flutterEngine)
        FlutterBridge.setMainActivity(this)
        DiagnosticsLogger.init(context)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, navChannelName)

        // Handle the intent that originally launched or re-launched this activity
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Store new intent so getIntent() returns it for future calls
        setIntent(intent)
        handleIntent(intent)
    }

    // ── Intent Routing ───────────────────────────────────────────────────────

    private fun handleIntent(intent: Intent) {
        // Priority 0: Boot recovery — Flutter must restore snapshot + Lock Task + Focus Home
        if (intent.getBooleanExtra(BootReceiver.EXTRA_BOOT_RECOVERY, false)) {
            Log.d(TAG, "Boot recovery intent received — notifying Flutter")
            methodChannel?.invokeMethod("bootRecovery", null)
            // Clear the flag so it doesn't re-trigger
            intent.removeExtra(BootReceiver.EXTRA_BOOT_RECOVERY)
            return
        }

        // Priority 0b: Watchdog recovery — re-enter Lock Task and navigate to Focus Home
        if (intent.getBooleanExtra("watchdog_recovery", false)) {
            Log.d(TAG, "Watchdog recovery intent received")
            FocusEnvironmentManager(this).enterFocusEnvironment(this)
            methodChannel?.invokeMethod("focusRecover", null)
            intent.removeExtra("watchdog_recovery")
            return
        }

        // Priority 0c: Screen ON lock screen
        if (intent.getBooleanExtra(ScreenReceiver.EXTRA_SCREEN_ON, false)) {
            Log.d(TAG, "Screen ON lock screen intent received")
            methodChannel?.invokeMethod("showLockScreen", null)
            intent.removeExtra(ScreenReceiver.EXTRA_SCREEN_ON)
            return
        }

        // Priority 1: A scheduled routine fired and needs Flutter to start the session
        if (intent.getBooleanExtra(ScheduleAlarmReceiver.EXTRA_ROUTINE_TRIGGERED, false)) {
            val routineId = intent.getStringExtra(ScheduleAlarmReceiver.EXTRA_TRIGGERED_ROUTINE_ID) ?: ""
            methodChannel?.invokeMethod(
                "routineTriggered",
                mapOf("routineId" to routineId)
            )
            return
        }

        // Priority 2: Focus Home recovery after a blocked-app redirect
        if (intent.getBooleanExtra("focus_recovery", false)) {
            methodChannel?.invokeMethod("focusRecover", null)
            return
        }

        // Priority 3: Home button pressed while focus is active
        val categories = intent.categories
        val isHomeIntent = intent.action == Intent.ACTION_MAIN &&
            categories != null &&
            categories.contains(Intent.CATEGORY_HOME)
        if (isHomeIntent && FocusModeManager.isActive && !FocusModeManager.isEmergencyOverrideActive()) {
            methodChannel?.invokeMethod("homeLaunch", null)
            return
        }

        // Priority 4: A specific blocked-app event notification
        if (intent.getBooleanExtra("is_blocked_event", false)) {
            val blockedPackage = intent.getStringExtra("blocked_package") ?: ""
            val blockedAppName = intent.getStringExtra("blocked_app_name") ?: ""
            methodChannel?.invokeMethod(
                "showBlockScreen",
                mapOf("packageName" to blockedPackage, "appName" to blockedAppName)
            )
        }
    }

    override fun onResume() {
        super.onResume()
        updateShowWhenLocked()
        FocusEnvironmentManager(this).enterFocusEnvironment(this)
    }

    /**
     * Configures the window to show over the lock screen when Focus Mode is active.
     * This allows our Focus Lock Screen to replace the system lock experience.
     */
    private fun updateShowWhenLocked() {
        val isFocusActive = FocusModeManager.isActive && !FocusModeManager.isEmergencyOverrideActive()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(isFocusActive)
            setTurnScreenOn(isFocusActive)
        } else {
            if (isFocusActive) {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            } else {
                @Suppress("DEPRECATION")
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        }
    }
}


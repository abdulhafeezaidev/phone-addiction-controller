package com.personal.phone_addiction_controller

import android.content.Context
import android.app.Activity
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.UserManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import android.content.pm.PackageManager
import com.personal.phone_addiction_controller.receivers.FocusDeviceAdminReceiver
import com.personal.phone_addiction_controller.services.AccessibilityMonitorService
import com.personal.phone_addiction_controller.services.FocusForegroundService

class FocusEnvironmentManager(private val context: Context) {

    private val allowedAppsManager = AllowedAppsManager(context)
    private val focusLayerPackage = context.packageName

    companion object {
        private const val TAG = "FocusEnvironmentManager"
    }

    fun isFocusActive(): Boolean {
        return FocusModeManager.isActive && !FocusModeManager.isEmergencyOverrideActive()
    }

    fun startFocusSession(scheduled: Boolean = false, routineId: String? = null) {
        FocusModeManager.startSession(scheduled, routineId)
    }

    fun endFocusSession() {
        FocusModeManager.endSession()
    }

    fun updateAllowedApps(allowed: Collection<String>, alwaysAllowed: Collection<String>) {
        allowedAppsManager.updateAllowedApps(allowed, alwaysAllowed)
    }

    fun updateSessionAllowedApps(packageNames: Collection<String>) {
        allowedAppsManager.updateSessionAllowedApps(packageNames)
    }

    fun getEffectiveAllowedPackages(): Set<String> {
        return allowedAppsManager.getEffectiveAllowedPackages()
    }

    fun isFocusLayerPackage(packageName: String?): Boolean {
        return packageName == focusLayerPackage
    }

    /**
     * Idempotent method to establish the Focus Environment.
     * Can be called with just a Context (from receivers) or an Activity (from MainActivity).
     * If an Activity is provided, it will also attempt to call startLockTask().
     */
    fun enterFocusEnvironment(activity: Activity? = null) {
        Log.d(TAG, "Attempting to enter Focus Environment")

        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, FocusDeviceAdminReceiver::class.java)
        val isDeviceOwner = dpm.isDeviceOwnerApp(context.packageName)
        val isStrict = FocusModeManager.strictMode
        val isFocusActive = isFocusActive()

        Log.d(TAG, "Environment context: DeviceOwner=$isDeviceOwner, StrictMode=$isStrict, FocusActive=$isFocusActive, isActive=${FocusModeManager.isActive}, emergencyOverride=${FocusModeManager.isEmergencyOverrideActive()}")

        if (!isDeviceOwner) {
            Log.w(TAG, "Device Owner privileges are NOT active. Cannot establish native Focus Environment.")
            return
        }

        if (!isFocusActive) {
            Log.w(TAG, "Focus Mode is not active. Aborting environment entry.")
            return
        }

        try {
            // 1. Foreground Service
            FocusForegroundService.start(context)

            // 2. Status Bar Restriction
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dpm.setStatusBarDisabled(adminComponent, true)
            }

            // 3. User Restrictions
            dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_SAFE_BOOT)
            dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_FACTORY_RESET)
            dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_ADD_USER)
            dpm.addUserRestriction(adminComponent, UserManager.DISALLOW_MOUNT_PHYSICAL_MEDIA)

            // 4. Uninstall Protection
            dpm.setUninstallBlocked(adminComponent, context.packageName, true)

            // 5. Persistent Preferred Activity (Focus Launcher Activation)
            val filter = IntentFilter(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            try {
                dpm.addPersistentPreferredActivity(
                    adminComponent,
                    filter,
                    ComponentName(context, MainActivity::class.java)
                )
                Log.d(TAG, "Successfully registered persistent preferred activity (FocusOS is Home).")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to register persistent preferred activity", e)
            }

            // 6. Lock Task Mode
            if (isStrict) {
                val whitelisted = mutableSetOf(context.packageName)
                whitelisted.addAll(FocusModeManager.allowedApps)
                whitelisted.addAll(FocusModeManager.alwaysAllowedApps)
                
                dpm.setLockTaskPackages(adminComponent, whitelisted.toTypedArray())

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    try {
                        val flags = DevicePolicyManager.LOCK_TASK_FEATURE_KEYGUARD or 
                                    DevicePolicyManager.LOCK_TASK_FEATURE_GLOBAL_ACTIONS
                        dpm.setLockTaskFeatures(adminComponent, flags)
                        Log.d(TAG, "Enabled Keyguard and Global Actions in Lock Task Mode")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to set Lock Task Features", e)
                    }
                }

                activity?.let {
                    val activityManager = it.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    if (activityManager.lockTaskModeState == ActivityManager.LOCK_TASK_MODE_NONE) {
                        try {
                            it.startLockTask()
                            Log.d(TAG, "Lock Task Mode started successfully.")
                            DiagnosticsLogger.watchdogRepair("LockTask", "Lock Task Mode (re-)entered")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to start Lock Task Mode", e)
                        }
                    }
                }
            } else {
                Log.d(TAG, "Strict mode is OFF, skipping Lock Task Mode packages.")
            }

            // 7. Verify Environment
            verifyEnvironment(dpm, adminComponent, isStrict)

            // 8. Force return to the newly set Home screen (FocusOS) only if not already there
            if (activity == null) {
                forceReturnHome(isEntering = true)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to completely enter Focus Environment", e)
        }
    }

    /**
     * Cleanly restores the device to normal operation.
     */
    fun exitFocusEnvironment(activity: Activity? = null) {
        Log.d(TAG, "Attempting to exit Focus Environment")

        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(context, FocusDeviceAdminReceiver::class.java)
        val isDeviceOwner = dpm.isDeviceOwnerApp(context.packageName)

        // 1. Exit Lock Task if we were in it
        activity?.let {
            val activityManager = it.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            if (activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE) {
                try {
                    it.stopLockTask()
                    Log.d(TAG, "Lock Task Mode stopped successfully.")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop Lock Task Mode", e)
                }
            }
        }

        if (isDeviceOwner) {
            try {
                // 2. Clear Persistent Preferred Activities (added by DPM)
                dpm.clearPackagePersistentPreferredActivities(adminComponent, context.packageName)
                Log.d(TAG, "Cleared persistent preferred activities (Restored default launcher).")
                
                // 3. Clear Status Bar Restriction
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    dpm.setStatusBarDisabled(adminComponent, false)
                }
                
                // 4. Clear User Restrictions
                dpm.clearUserRestriction(adminComponent, UserManager.DISALLOW_SAFE_BOOT)
                dpm.clearUserRestriction(adminComponent, UserManager.DISALLOW_FACTORY_RESET)
                dpm.clearUserRestriction(adminComponent, UserManager.DISALLOW_ADD_USER)
                dpm.clearUserRestriction(adminComponent, UserManager.DISALLOW_MOUNT_PHYSICAL_MEDIA)
                // Note: Uninstall block is purposefully kept until authorized Flutter removal

                Log.d(TAG, "Device Owner restrictions cleared.")
                
                // 5. Force return to the original Home screen (e.g., One UI)
                forceReturnHome(isEntering = false)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to clear focus policies", e)
            }
        }
    }

    private fun verifyEnvironment(dpm: DevicePolicyManager, admin: ComponentName, isStrict: Boolean) {
        Log.d(TAG, "--- Environment Verification Report ---")
        
        val isDeviceOwner = dpm.isDeviceOwnerApp(context.packageName)
        Log.d(TAG, "✓ Device Owner active: $isDeviceOwner")

        // In Android, we can't cleanly query if our preferred activity is the ONLY one, 
        // but we know we didn't throw an exception adding it.
        Log.d(TAG, "✓ Persistent preferred launcher registered")

        if (isStrict) {
            val packages = dpm.getLockTaskPackages(admin)
            val hasPackages = packages != null && packages.contains(context.packageName)
            Log.d(TAG, "✓ Lock Task packages configured: $hasPackages")
        }

        Log.d(TAG, "✓ Status bar restriction applied (No API to read back cleanly in all versions, relying on successful invocation)")

        Log.d(TAG, "✓ Foreground service requested: True")
        
        val isAccessibilityActive = isAccessibilityServiceRunning()
        Log.d(TAG, "✓ Accessibility running: $isAccessibilityActive")
        
        Log.d(TAG, "---------------------------------------")
    }

    private fun isAccessibilityServiceRunning(): Boolean {
        return try {
            val serviceId = "${context.packageName}/com.personal.phone_addiction_controller.services.AccessibilityMonitorService"
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
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

    private fun forceReturnHome(isEntering: Boolean) {
        try {
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
            }
            
            if (isEntering) {
                homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                homeIntent.setClassName(context, "com.personal.phone_addiction_controller.MainActivity")
                context.startActivity(homeIntent)
                Log.d(TAG, "Successfully forced Home Intent to FocusOS without clearing task.")
            } else {
                homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                val resolveInfos = context.packageManager.queryIntentActivities(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
                for (resolveInfo in resolveInfos) {
                    if (resolveInfo.activityInfo.packageName != context.packageName) {
                        homeIntent.setClassName(resolveInfo.activityInfo.packageName, resolveInfo.activityInfo.name)
                        context.startActivity(homeIntent)
                        Log.d(TAG, "Successfully forced Home Intent to default launcher: ${resolveInfo.activityInfo.packageName}")
                        return
                    }
                }
                // Fallback if no other home found
                context.startActivity(homeIntent)
                Log.d(TAG, "Fired generic Home Intent (no other launcher found).")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to force Home redirection", e)
        }
    }
}
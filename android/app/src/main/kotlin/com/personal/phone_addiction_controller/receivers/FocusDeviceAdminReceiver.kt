package com.personal.phone_addiction_controller.receivers

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.personal.phone_addiction_controller.TamperGuard

/**
 * Device-admin component. It requests no policies; its only purpose is that Android
 * refuses to uninstall an app while it is an active device admin, so removing Focus
 * Guard first requires deactivating it (a screen [TamperGuard] protects).
 */
class FocusDeviceAdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device admin enabled")
    }

    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        TamperGuard.init(context)
        return "Deactivating Detox removes Android's uninstall deterrent. If the optional screen guard is enabled, it may ask you to verify in Detox."
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device admin disabled")
    }

    companion object {
        private const val TAG = "FocusDeviceAdminReceiver"
    }
}

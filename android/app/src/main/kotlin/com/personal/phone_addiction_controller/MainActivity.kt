package com.personal.phone_addiction_controller

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter UI. Blocking, routines and recovery all run natively, so this
 * activity only needs to (a) initialise the bridge and (b) forward the one deep-link
 * the native layer can request: "open the emergency screen" from the block overlay.
 */
class MainActivity : FlutterActivity() {

    private var navChannel: MethodChannel? = null

    // Buffers a deep-link that arrives before Flutter has attached its handler.
    private var isFlutterNavReady = false
    private var pendingNavMethod: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterBridge.initialize(context, flutterEngine)
        DiagnosticsLogger.init(context)

        navChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAV_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "navigationReady" -> {
                        isFlutterNavReady = true
                        pendingNavMethod?.let { navChannel?.invokeMethod(it, null) }
                        pendingNavMethod = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        if (intent.getBooleanExtra(EXTRA_OPEN_EMERGENCY, false)) {
            intent.removeExtra(EXTRA_OPEN_EMERGENCY)
            if (isFlutterNavReady) {
                navChannel?.invokeMethod("openEmergency", null)
            } else {
                Log.d(TAG, "Flutter not ready - buffering openEmergency")
                pendingNavMethod = "openEmergency"
            }
        } else if (intent.getBooleanExtra(EXTRA_PROMPT_UNINSTALL, false)) {
            intent.removeExtra(EXTRA_PROMPT_UNINSTALL)
            if (isFlutterNavReady) {
                navChannel?.invokeMethod("promptUninstallAdmin", null)
            } else {
                Log.d(TAG, "Flutter not ready - buffering promptUninstallAdmin")
                pendingNavMethod = "promptUninstallAdmin"
            }
        }
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val NAV_CHANNEL = "com.personal.phone_addiction_controller/navigation"
        const val EXTRA_OPEN_EMERGENCY = "open_emergency_override"
        const val EXTRA_PROMPT_UNINSTALL = "prompt_uninstall_admin"
    }
}

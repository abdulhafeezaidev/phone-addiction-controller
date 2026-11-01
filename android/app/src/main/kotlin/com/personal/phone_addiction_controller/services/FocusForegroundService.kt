package com.personal.phone_addiction_controller.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.personal.phone_addiction_controller.DiagnosticsLogger
import com.personal.phone_addiction_controller.FocusModeManager
import com.personal.phone_addiction_controller.FocusSessionController
import com.personal.phone_addiction_controller.NotificationHelper

/**
 * Foreground service that keeps the process alive while a Focus session runs.
 *
 * 1. Shows a persistent notification with the remaining time.
 * 2. Ends quick sessions at their end time (the accessibility service enforces
 *    blocking; this only guarantees the session state and notification are cleaned up).
 */
class FocusForegroundService : Service() {

    private val handler = Handler(Looper.getMainLooper())

    private val updateRunnable = object : Runnable {
        override fun run() {
            if (!tick()) return
            handler.postDelayed(this, TICK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createNotificationChannels(this)
        FocusModeManager.init(this)
        DiagnosticsLogger.init(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = NotificationHelper.buildFocusNotification(this, getRemainingText()).build()
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NotificationHelper.FOCUS_NOTIFICATION_ID,
                    notification,
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NotificationHelper.FOCUS_NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enter foreground state", e)
            stopSelf()
            return START_NOT_STICKY
        }
        handler.removeCallbacks(updateRunnable)
        handler.post(updateRunnable)
        DiagnosticsLogger.foregroundServiceStarted()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(updateRunnable)
        DiagnosticsLogger.foregroundServiceStopped()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** Returns false when the service stopped itself and no further ticks are needed. */
    private fun tick(): Boolean {
        if (!FocusModeManager.isActive) {
            stopSelf()
            return false
        }

        if (FocusModeManager.hasQuickSessionExpired()) {
            Log.d(TAG, "Quick session reached its end time")
            FocusSessionController.onQuickSessionExpired(this)
            if (!FocusModeManager.isActive) {
                DiagnosticsLogger.sessionEnded()
                return false
            }
        }

        val nm = getSystemService(android.app.NotificationManager::class.java)
        nm.notify(
            NotificationHelper.FOCUS_NOTIFICATION_ID,
            NotificationHelper.buildFocusNotification(this, getRemainingText()).build()
        )
        return true
    }

    private fun getRemainingText(): String {
        val endTime = FocusModeManager.scheduledEndTime
        if (endTime <= 0) {
            val startTime = FocusModeManager.sessionStartTime
            if (startTime > 0) {
                val minutes = ((System.currentTimeMillis() - startTime) / 60_000).toInt()
                val hours = minutes / 60
                val mins = minutes % 60
                return if (hours > 0) "Active for ${hours}h ${mins}m" else "Active for ${mins}m"
            }
            return "Focus Mode Active"
        }

        val remaining = endTime - System.currentTimeMillis()
        if (remaining <= 0) return "Ending soon..."

        val minutes = (remaining / 60_000).toInt()
        val hours = minutes / 60
        val mins = minutes % 60
        return if (hours > 0) "${hours}h ${mins}m remaining" else "${mins}m remaining"
    }

    companion object {
        private const val TAG = "FocusForegroundService"
        private const val TICK_INTERVAL_MS = 30_000L

        fun start(context: Context) {
            val intent = Intent(context, FocusForegroundService::class.java)
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start foreground service", e)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, FocusForegroundService::class.java))
        }
    }
}

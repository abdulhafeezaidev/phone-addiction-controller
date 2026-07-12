package com.personal.phone_addiction_controller

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Helper for creating and managing notifications.
 */
object NotificationHelper {
    const val FOCUS_CHANNEL_ID = "focus_mode_channel"
    const val SCHEDULE_CHANNEL_ID = "schedule_channel"
    const val FOCUS_NOTIFICATION_ID = 1001
    const val SCHEDULE_NOTIFICATION_ID = 1002

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(NotificationManager::class.java)

            val focusChannel = NotificationChannel(
                FOCUS_CHANNEL_ID,
                context.getString(R.string.focus_notification_channel_name),
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = context.getString(R.string.focus_notification_channel_description)
                setShowBadge(false)
            }

            val scheduleChannel = NotificationChannel(
                SCHEDULE_CHANNEL_ID,
                context.getString(R.string.schedule_notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = context.getString(R.string.schedule_notification_channel_description)
            }

            nm.createNotificationChannel(focusChannel)
            nm.createNotificationChannel(scheduleChannel)
        }
    }

    fun buildFocusNotification(
        context: Context,
        remainingText: String = "Focus Mode Active"
    ): NotificationCompat.Builder {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, FOCUS_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentTitle("Focus Mode Active")
            .setContentText(remainingText)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setContentIntent(pendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
    }
}

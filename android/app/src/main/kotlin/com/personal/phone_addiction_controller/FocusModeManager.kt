package com.personal.phone_addiction_controller

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Manages Focus Mode state persistence via SharedPreferences.
 * Accessible from any component (Service, Receiver, Activity) without Flutter engine.
 */
object FocusModeManager {
    private const val TAG = "FocusModeManager"
    private const val PREFS_NAME = "FocusModePrefs"
    private const val KEY_IS_ACTIVE = "isActive"
    private const val KEY_ALLOWED_APPS = "allowedApps"
    private const val KEY_ALWAYS_ALLOWED_APPS = "alwaysAllowedApps"
    private const val KEY_SESSION_START_TIME = "sessionStartTime"
    private const val KEY_SCHEDULED_END_TIME = "scheduledEndTime"
    private const val KEY_ACTIVE_ROUTINE_ID = "activeRoutineId"
    private const val KEY_IS_SCHEDULED = "isScheduled"
    private const val KEY_STRICT_MODE = "strictMode"

    private lateinit var prefs: SharedPreferences

    @Volatile
    var foregroundPackageName: String? = null

    fun init(context: Context) {
        if (!::prefs.isInitialized) {
            prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    var isActive: Boolean
        get() = if (::prefs.isInitialized) prefs.getBoolean(KEY_IS_ACTIVE, false) else false
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putBoolean(KEY_IS_ACTIVE, value).apply()
                Log.d(TAG, "Focus mode active: $value")
            }
        }

    var allowedApps: Set<String>
        get() = if (::prefs.isInitialized) prefs.getStringSet(KEY_ALLOWED_APPS, emptySet()) ?: emptySet() else emptySet()
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putStringSet(KEY_ALLOWED_APPS, value).apply()
            }
        }

    var alwaysAllowedApps: Set<String>
        get() = if (::prefs.isInitialized) prefs.getStringSet(KEY_ALWAYS_ALLOWED_APPS, emptySet()) ?: emptySet() else emptySet()
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putStringSet(KEY_ALWAYS_ALLOWED_APPS, value).apply()
            }
        }

    var sessionStartTime: Long
        get() = if (::prefs.isInitialized) prefs.getLong(KEY_SESSION_START_TIME, 0L) else 0L
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putLong(KEY_SESSION_START_TIME, value).apply()
            }
        }

    var scheduledEndTime: Long
        get() = if (::prefs.isInitialized) prefs.getLong(KEY_SCHEDULED_END_TIME, 0L) else 0L
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putLong(KEY_SCHEDULED_END_TIME, value).apply()
            }
        }

    var activeRoutineId: String?
        get() = if (::prefs.isInitialized) prefs.getString(KEY_ACTIVE_ROUTINE_ID, null) else null
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putString(KEY_ACTIVE_ROUTINE_ID, value).apply()
            }
        }

    var isScheduled: Boolean
        get() = if (::prefs.isInitialized) prefs.getBoolean(KEY_IS_SCHEDULED, false) else false
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putBoolean(KEY_IS_SCHEDULED, value).apply()
            }
        }

    var strictMode: Boolean
        get() = if (::prefs.isInitialized) prefs.getBoolean(KEY_STRICT_MODE, false) else false
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putBoolean(KEY_STRICT_MODE, value).apply()
                Log.d(TAG, "Strict mode set to: $value")
            }
        }

    var emergencyOverrideActive: Boolean
        get() = if (::prefs.isInitialized) prefs.getBoolean("emergencyOverrideActive", false) else false
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putBoolean("emergencyOverrideActive", value).apply()
                Log.d(TAG, "Emergency override active set to: $value")
            }
        }

    var emergencyOverrideExpirationTime: Long
        get() = if (::prefs.isInitialized) prefs.getLong("emergencyOverrideExpirationTime", 0L) else 0L
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putLong("emergencyOverrideExpirationTime", value).apply()
                Log.d(TAG, "Emergency override expiration time set to: $value")
            }
        }

    fun isEmergencyOverrideActive(): Boolean {
        if (!emergencyOverrideActive) return false
        val exp = emergencyOverrideExpirationTime
        if (exp == 0L) return false
        if (System.currentTimeMillis() > exp) {
            // Expired, turn off dynamically
            emergencyOverrideActive = false
            emergencyOverrideExpirationTime = 0L
            return false
        }
        return true
    }

    /** Start a new focus session. */
    fun startSession(scheduled: Boolean = false, routineId: String? = null) {
        emergencyOverrideActive = false
        emergencyOverrideExpirationTime = 0L
        isActive = true
        sessionStartTime = System.currentTimeMillis()
        isScheduled = scheduled
        activeRoutineId = routineId
    }

    /** End the current focus session. */
    fun endSession() {
        isActive = false
        sessionStartTime = 0L
        scheduledEndTime = 0L
        activeRoutineId = null
        isScheduled = false
        emergencyOverrideActive = false
        emergencyOverrideExpirationTime = 0L
    }
}

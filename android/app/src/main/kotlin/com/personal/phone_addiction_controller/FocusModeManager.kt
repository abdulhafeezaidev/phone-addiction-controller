package com.personal.phone_addiction_controller

import android.content.Context
import android.content.SharedPreferences
import android.util.Log

/**
 * Persists Focus Mode state in SharedPreferences.
 *
 * This is the single source of truth for the running session. It is readable
 * from any component (service, receiver, activity) without the Flutter engine,
 * which is what lets blocking keep working when the UI process is not alive.
 */
object FocusModeManager {
    private const val TAG = "FocusModeManager"
    private const val PREFS_NAME = "FocusModePrefs"
    private const val KEY_IS_ACTIVE = "isActive"
    private const val KEY_BLOCKED_PACKAGES = "blockedPackages"
    private const val KEY_SESSION_START_TIME = "sessionStartTime"
    private const val KEY_SCHEDULED_END_TIME = "scheduledEndTime"
    private const val KEY_ACTIVE_ROUTINE_ID = "activeRoutineId"
    private const val KEY_IS_SCHEDULED = "isScheduled"
    private const val KEY_EMERGENCY_ACTIVE = "emergencyOverrideActive"
    private const val KEY_EMERGENCY_EXPIRY = "emergencyOverrideExpirationTime"

    private lateinit var prefs: SharedPreferences

    @Volatile
    var foregroundPackageName: String? = null

    fun init(context: Context) {
        if (!::prefs.isInitialized) {
            prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        }
    }

    private fun getBoolean(key: String, default: Boolean = false) =
        if (::prefs.isInitialized) prefs.getBoolean(key, default) else default

    private fun getLong(key: String) = if (::prefs.isInitialized) prefs.getLong(key, 0L) else 0L

    var isActive: Boolean
        get() = getBoolean(KEY_IS_ACTIVE)
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putBoolean(KEY_IS_ACTIVE, value).apply()
                Log.d(TAG, "Focus mode active: $value")
            }
        }

    var blockedPackages: Set<String>
        get() = if (::prefs.isInitialized) {
            // Copy: the set returned by SharedPreferences must never be mutated.
            HashSet(prefs.getStringSet(KEY_BLOCKED_PACKAGES, emptySet()) ?: emptySet())
        } else emptySet()
        set(value) {
            if (::prefs.isInitialized) {
                prefs.edit().putStringSet(KEY_BLOCKED_PACKAGES, HashSet(value)).apply()
                Log.d(TAG, "Blocked packages updated: ${value.size} packages")
            }
        }

    var sessionStartTime: Long
        get() = getLong(KEY_SESSION_START_TIME)
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putLong(KEY_SESSION_START_TIME, value).apply()
        }

    /** Absolute end time (epoch ms) of a quick session, or 0 for routine-driven sessions. */
    var scheduledEndTime: Long
        get() = getLong(KEY_SCHEDULED_END_TIME)
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putLong(KEY_SCHEDULED_END_TIME, value).apply()
        }

    var activeRoutineId: String?
        get() = if (::prefs.isInitialized) prefs.getString(KEY_ACTIVE_ROUTINE_ID, null) else null
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putString(KEY_ACTIVE_ROUTINE_ID, value).apply()
        }

    /** True when the running session was started by a routine alarm. */
    var isScheduled: Boolean
        get() = getBoolean(KEY_IS_SCHEDULED)
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putBoolean(KEY_IS_SCHEDULED, value).apply()
        }

    var emergencyOverrideActive: Boolean
        get() = getBoolean(KEY_EMERGENCY_ACTIVE)
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putBoolean(KEY_EMERGENCY_ACTIVE, value).apply()
        }

    var emergencyOverrideExpirationTime: Long
        get() = getLong(KEY_EMERGENCY_EXPIRY)
        set(value) {
            if (::prefs.isInitialized) prefs.edit().putLong(KEY_EMERGENCY_EXPIRY, value).apply()
        }

    fun isEmergencyOverrideActive(): Boolean {
        if (!emergencyOverrideActive) return false
        val exp = emergencyOverrideExpirationTime
        if (exp == 0L || System.currentTimeMillis() > exp) {
            emergencyOverrideActive = false
            emergencyOverrideExpirationTime = 0L
            return false
        }
        return true
    }

    /** True when a quick (non-routine) session has passed its absolute end time. */
    fun hasQuickSessionExpired(now: Long = System.currentTimeMillis()): Boolean {
        val end = scheduledEndTime
        return isActive && !isScheduled && end > 0L && now >= end
    }

    fun startSession(scheduled: Boolean = false, routineId: String? = null) {
        emergencyOverrideActive = false
        emergencyOverrideExpirationTime = 0L
        isActive = true
        sessionStartTime = System.currentTimeMillis()
        isScheduled = scheduled
        activeRoutineId = routineId
        if (scheduled) scheduledEndTime = 0L
    }

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

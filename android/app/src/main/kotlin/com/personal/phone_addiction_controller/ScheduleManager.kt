package com.personal.phone_addiction_controller

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import com.personal.phone_addiction_controller.receivers.ScheduleAlarmReceiver
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Manages schedule alarms using AlarmManager.
 *
 * Persists routine data in SharedPreferences as JSON so it can survive
 * app restarts and reboots without needing Flutter/Hive.
 *
 * Supports overnight schedules (start > end) and overlapping schedules.
 *
 * PendingIntents include an explicit action string so each start/stop alarm
 * has a stable, unique identity — required for reliable alarm delivery under
 * Doze Mode and after device restarts.
 */
class ScheduleManager(private val context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val alarmManager: AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    // ── Public API ──────────────────────────────────────────────────────────

    /**
     * Schedules start and stop alarms for a routine.
     * [routineJson] must contain: id, label, weekdays[], startHour, startMinute,
     * endHour, endMinute, enabled, slots[].
     */
    fun scheduleRoutine(routineJson: String) {
        try {
            val json = JSONObject(routineJson)
            val id = json.getString("id")
            val enabled = json.getBoolean("enabled")

            // Always save latest JSON to storage (even if disabled)
            saveRoutine(id, routineJson)

            if (!enabled) {
                cancelRoutine(id)
                return
            }

            // A routine may have multiple time slots; schedule each independently.
            val weekdays = mutableListOf<Int>()
            val wdArray = json.getJSONArray("weekdays")
            for (i in 0 until wdArray.length()) {
                weekdays.add(wdArray.getInt(i))
            }

            // Support multi-slot routines (slots array) or fall back to
            // the top-level startHour/startMinute/endHour/endMinute fields.
            val slots = mutableListOf<Pair<Pair<Int, Int>, Pair<Int, Int>>>() // (start, end)
            if (json.has("slots")) {
                val slotsArray = json.getJSONArray("slots")
                for (i in 0 until slotsArray.length()) {
                    val s = slotsArray.getJSONObject(i)
                    slots.add(
                        Pair(
                            Pair(s.getInt("startHour"), s.getInt("startMinute")),
                            Pair(s.getInt("endHour"), s.getInt("endMinute"))
                        )
                    )
                }
            }
            if (slots.isEmpty()) {
                slots.add(
                    Pair(
                        Pair(json.getInt("startHour"), json.getInt("startMinute")),
                        Pair(json.getInt("endHour"), json.getInt("endMinute"))
                    )
                )
            }

            for ((slotIndex, slot) in slots.withIndex()) {
                val (start, end) = slot
                val (startHour, startMinute) = start
                val (endHour, endMinute) = end

                val nextStart = getNextAlarmTime(weekdays, startHour, startMinute)
                if (nextStart != null) {
                    setAlarm(
                        requestCode = getStartRequestCode(id, slotIndex),
                        timeMs = nextStart,
                        routineId = id,
                        slotIndex = slotIndex,
                        isStart = true,
                    )
                }

                val nextStop = getNextAlarmTime(weekdays, endHour, endMinute)
                if (nextStop != null) {
                    setAlarm(
                        requestCode = getStopRequestCode(id, slotIndex),
                        timeMs = nextStop,
                        routineId = id,
                        slotIndex = slotIndex,
                        isStart = false,
                    )
                }
            }

            DiagnosticsLogger.routineCreated(id)
            Log.d(TAG, "Scheduled routine: $id (${slots.size} slot(s))")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule routine", e)
        }
    }

    fun cancelRoutine(id: String) {
        // Cancel up to 10 slot alarms per routine (generous upper bound)
        for (slotIndex in 0 until 10) {
            cancelAlarm(getStartRequestCode(id, slotIndex))
            cancelAlarm(getStopRequestCode(id, slotIndex))
        }
        DiagnosticsLogger.routineCancelled(id)
        Log.d(TAG, "Cancelled routine: $id")
    }

    fun cancelAllRoutines() {
        val routines = getAllRoutines()
        for ((id, _) in routines) {
            cancelRoutine(id)
        }
        prefs.edit().remove(KEY_ROUTINES).apply()
        Log.d(TAG, "Cancelled all routines")
    }

    /**
     * Checks if any enabled routine is currently active at this moment.
     */
    fun isAnyRoutineActive(): Boolean {
        val now = Calendar.getInstance()
        val currentDay = convertCalendarDayToWeekday(now.get(Calendar.DAY_OF_WEEK))
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

        val routines = getAllRoutines()
        for ((_, json) in routines) {
            try {
                val obj = JSONObject(json)
                if (!obj.getBoolean("enabled")) continue

                val weekdays = mutableListOf<Int>()
                val wdArray = obj.getJSONArray("weekdays")
                for (i in 0 until wdArray.length()) {
                    weekdays.add(wdArray.getInt(i))
                }

                if (!weekdays.contains(currentDay)) continue

                // Check all slots
                val slots = mutableListOf<Pair<Int, Int>>() // (startMinutes, endMinutes)
                if (obj.has("slots")) {
                    val slotsArray = obj.getJSONArray("slots")
                    for (i in 0 until slotsArray.length()) {
                        val s = slotsArray.getJSONObject(i)
                        val sm = s.getInt("startHour") * 60 + s.getInt("startMinute")
                        val em = s.getInt("endHour") * 60 + s.getInt("endMinute")
                        slots.add(Pair(sm, em))
                    }
                }
                if (slots.isEmpty()) {
                    val sm = obj.getInt("startHour") * 60 + obj.getInt("startMinute")
                    val em = obj.getInt("endHour") * 60 + obj.getInt("endMinute")
                    slots.add(Pair(sm, em))
                }

                for ((startMinutes, endMinutes) in slots) {
                    val isOvernight = startMinutes >= endMinutes
                    val active = if (isOvernight) {
                        currentMinutes >= startMinutes || currentMinutes < endMinutes
                    } else {
                        currentMinutes >= startMinutes && currentMinutes < endMinutes
                    }
                    if (active) return true
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error checking routine", e)
            }
        }
        return false
    }

    /**
     * Returns the active routine's JSON if one is currently active, null otherwise.
     */
    fun getActiveRoutineJson(): String? {
        val now = Calendar.getInstance()
        val currentDay = convertCalendarDayToWeekday(now.get(Calendar.DAY_OF_WEEK))
        val currentMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

        for ((_, json) in getAllRoutines()) {
            try {
                val obj = JSONObject(json)
                if (!obj.getBoolean("enabled")) continue

                val weekdays = mutableListOf<Int>()
                val wdArray = obj.getJSONArray("weekdays")
                for (i in 0 until wdArray.length()) weekdays.add(wdArray.getInt(i))

                if (!weekdays.contains(currentDay)) continue

                val slots = mutableListOf<Pair<Int, Int>>()
                if (obj.has("slots")) {
                    val slotsArray = obj.getJSONArray("slots")
                    for (i in 0 until slotsArray.length()) {
                        val s = slotsArray.getJSONObject(i)
                        slots.add(Pair(s.getInt("startHour") * 60 + s.getInt("startMinute"),
                            s.getInt("endHour") * 60 + s.getInt("endMinute")))
                    }
                }
                if (slots.isEmpty()) {
                    slots.add(Pair(obj.getInt("startHour") * 60 + obj.getInt("startMinute"),
                        obj.getInt("endHour") * 60 + obj.getInt("endMinute")))
                }

                for ((sm, em) in slots) {
                    val overnight = sm >= em
                    val active = if (overnight) (currentMinutes >= sm || currentMinutes < em)
                                 else (currentMinutes >= sm && currentMinutes < em)
                    if (active) return json
                }
            } catch (_: Exception) {}
        }
        return null
    }

    /**
     * Re-schedules all stored routines. Called after boot or when alarm fires
     * (to schedule the next occurrence).
     */
    fun rescheduleAllFromStorage() {
        val routines = getAllRoutines()
        for ((_, json) in routines) {
            scheduleRoutine(json)
        }

        // If any routine is currently active AND focus mode isn't already on,
        // start a focus session immediately.
        if (isAnyRoutineActive() && !FocusModeManager.isActive) {
            val activeJson = getActiveRoutineJson()
            val routineId = activeJson?.let { JSONObject(it).optString("id") }
            FocusModeManager.startSession(scheduled = true, routineId = routineId)
            if (routineId != null) {
                DiagnosticsLogger.routineRestoredAfterReboot(routineId)
            }
        }
    }

    // ── Storage ─────────────────────────────────────────────────────────────

    private fun saveRoutine(id: String, json: String) {
        val routines = getAllRoutinesRaw()
        routines.put(id, json)
        prefs.edit().putString(KEY_ROUTINES, routines.toString()).apply()
    }

    fun removeRoutine(id: String) {
        val routines = getAllRoutinesRaw()
        routines.remove(id)
        prefs.edit().putString(KEY_ROUTINES, routines.toString()).apply()
    }

    private fun getAllRoutinesRaw(): JSONObject {
        val raw = prefs.getString(KEY_ROUTINES, null) ?: return JSONObject()
        return try { JSONObject(raw) } catch (_: Exception) { JSONObject() }
    }

    fun getAllRoutines(): Map<String, String> {
        val obj = getAllRoutinesRaw()
        val map = mutableMapOf<String, String>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            map[key] = obj.getString(key)
        }
        return map
    }

    // ── Alarm Helpers ───────────────────────────────────────────────────────

    private fun setAlarm(
        requestCode: Int,
        timeMs: Long,
        routineId: String,
        slotIndex: Int,
        isStart: Boolean,
    ) {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            // Explicit action makes each PendingIntent uniquely identifiable
            // to the AlarmManager — critical for reliable delivery in Doze Mode.
            action = if (isStart) ACTION_START else ACTION_STOP
            putExtra(EXTRA_ROUTINE_ID, routineId)
            putExtra(EXTRA_SLOT_INDEX, slotIndex)
            putExtra(EXTRA_IS_START, isStart)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                } else {
                    // Fall back to inexact — will still fire, just possibly slightly late
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
                }
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
            }
            Log.d(TAG, "Alarm set: ${if (isStart) "START" else "STOP"} routine=$routineId slot=$slotIndex at $timeMs")
        } catch (e: SecurityException) {
            Log.e(TAG, "Cannot schedule exact alarm, using inexact fallback", e)
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timeMs, pendingIntent)
        }
    }

    private fun cancelAlarm(requestCode: Int) {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    private fun getNextAlarmTime(weekdays: List<Int>, hour: Int, minute: Int): Long? {
        if (weekdays.isEmpty()) return null

        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        // Look up to 8 days ahead to find the next matching weekday
        for (daysAhead in 0..7) {
            val candidate = Calendar.getInstance().apply {
                timeInMillis = target.timeInMillis
                add(Calendar.DAY_OF_YEAR, daysAhead)
            }

            // Skip if the candidate is in the past (for today)
            if (daysAhead == 0 && candidate.timeInMillis <= now.timeInMillis) continue

            val dayOfWeek = convertCalendarDayToWeekday(candidate.get(Calendar.DAY_OF_WEEK))
            if (weekdays.contains(dayOfWeek)) {
                return candidate.timeInMillis
            }
        }
        return null
    }

    /**
     * Converts Java Calendar DAY_OF_WEEK (Sun=1..Sat=7) to our weekday format (Mon=0..Sun=6).
     */
    private fun convertCalendarDayToWeekday(calendarDay: Int): Int {
        return when (calendarDay) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }
    }

    /**
     * Unique request codes for PendingIntents.
     * Using hashCode * 20 + slotIndex * 2 + isStart gives stable, non-colliding codes.
     */
    private fun getStartRequestCode(id: String, slotIndex: Int = 0): Int =
        id.hashCode() * 20 + slotIndex * 2

    private fun getStopRequestCode(id: String, slotIndex: Int = 0): Int =
        id.hashCode() * 20 + slotIndex * 2 + 1

    companion object {
        private const val TAG = "ScheduleManager"
        private const val PREFS_NAME = "SchedulePrefs"
        private const val KEY_ROUTINES = "routines"

        // Intent action strings — make PendingIntents uniquely identifiable
        const val ACTION_START = "com.personal.phone_addiction_controller.ACTION_ROUTINE_START"
        const val ACTION_STOP  = "com.personal.phone_addiction_controller.ACTION_ROUTINE_STOP"

        // Intent extras
        const val EXTRA_ROUTINE_ID  = "routine_id"
        const val EXTRA_SLOT_INDEX  = "slot_index"
        const val EXTRA_IS_START    = "is_start"
    }
}

package com.personal.phone_addiction_controller

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.provider.Settings.Secure
import android.speech.tts.TextToSpeech
import android.text.TextUtils
import android.util.Log
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import androidx.core.app.NotificationManagerCompat
import com.personal.phone_addiction_controller.receivers.FocusDeviceAdminReceiver
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.sin

/**
 * The single Flutter <-> native surface. Flutter never keeps session state of its own:
 * it asks native for the session ([getSession]) and tells native what to do.
 */
object FlutterBridge {
    private const val TAG = "FlutterBridge"
    private const val METHOD_CHANNEL = "com.personal.phone_addiction_controller/accessibility"
    private const val UNINSTALL_FLOW_UNLOCK_MS = 2 * 60 * 1000L
    private var lumiTts: TextToSpeech? = null
    private var lumiTtsReady = false
    private var pendingLumiText: String? = null
    private var activeAmbientTrack: AudioTrack? = null
    @Volatile
    private var ambientRunning = false
    @Volatile
    private var ambientGeneration = 0

    fun initialize(context: Context, flutterEngine: FlutterEngine) {
        val appContext = context.applicationContext
        FocusModeManager.init(appContext)
        TamperGuard.init(appContext)
        NotificationHelper.createNotificationChannels(appContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    handle(appContext, call, result)
                } catch (e: Exception) {
                    Log.e(TAG, "Method ${call.method} failed", e)
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // ── Permissions & system state ───────────────────────────────
            "getStorageDirectory" -> result.success(io.flutter.util.PathUtils.getDataDirectory(context))
            "isServiceEnabled" -> result.success(isAccessibilityServiceEnabled(context))
            "openAccessibilitySettings" -> {
                if (!openSettings(context, Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))) {
                    openSettings(context, Intent(Settings.ACTION_SETTINGS))
                }
                result.success(null)
            }
            "isBatteryOptimizationDisabled" -> result.success(isBatteryOptDisabled(context))
            "openBatteryOptimizationSettings" -> {
                val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    .setData(Uri.parse("package:${context.packageName}"))
                if (!openSettings(context, direct)) {
                    openSettings(context, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                }
                result.success(null)
            }
            "areNotificationsEnabled" ->
                result.success(NotificationManagerCompat.from(context).areNotificationsEnabled())
            "openNotificationSettings" -> {
                val notifIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                if (!openSettings(context, notifIntent)) {
                    openSettings(
                        context,
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.parse("package:${context.packageName}"))
                    )
                }
                result.success(null)
            }

            // ── Session ──────────────────────────────────────────────────
            "startSession" -> {
                val endTimeMs = call.argument<Number>("endTimeMs")?.toLong() ?: 0L
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                if (endTimeMs <= System.currentTimeMillis()) {
                    result.error("INVALID_ARGUMENT", "endTimeMs must be in the future", null)
                } else {
                    FocusSessionController.startQuickSession(context, endTimeMs, packages.toSet())
                    result.success(null)
                }
            }
            "stopSession" -> {
                FocusSessionController.endSession(context)
                result.success(null)
            }
            "getSession" -> {
                if (FocusModeManager.hasQuickSessionExpired()) {
                    FocusSessionController.onQuickSessionExpired(context)
                }
                result.success(
                    mapOf(
                        "isActive" to FocusModeManager.isActive,
                        "startTimeMs" to FocusModeManager.sessionStartTime,
                        "endTimeMs" to FocusModeManager.scheduledEndTime,
                        "isScheduled" to FocusModeManager.isScheduled,
                        "routineId" to FocusModeManager.activeRoutineId,
                        "blockedPackages" to FocusModeManager.blockedPackages.toList(),
                        "emergencyActive" to FocusModeManager.isEmergencyOverrideActive()
                    )
                )
            }
            "getBlockedPackages" -> result.success(FocusModeManager.blockedPackages.toList())
            "setEmergencyOverrideActive" -> {
                val active = call.argument<Boolean>("active") ?: false
                FocusModeManager.emergencyOverrideActive = active
                FocusModeManager.emergencyOverrideExpirationTime =
                    call.argument<Number>("expirationTime")?.toLong() ?: 0L
                if (active) {
                    com.personal.phone_addiction_controller.services.AccessibilityMonitorService.instance?.hideOverlay()
                }
                result.success(null)
            }

            // ── Installed apps ───────────────────────────────────────────
            "getInstalledApps" -> {
                CoroutineScope(Dispatchers.Main).launch {
                    try {
                        val apps = withContext(Dispatchers.IO) { getUserAppsList(context) }
                        result.success(apps)
                    } catch (e: Exception) {
                        result.error("APPS_ERROR", e.message, null)
                    }
                }
            }

            // ── Routines ─────────────────────────────────────────────────
            "scheduleRoutine" -> {
                val json = call.argument<String>("routineJson") ?: "{}"
                ScheduleManager(context).scheduleRoutine(json)
                FocusSessionController.reconcileWithRoutines(context)
                result.success(null)
            }
            "cancelRoutine" -> {
                val id = call.argument<String>("routineId") ?: ""
                val manager = ScheduleManager(context)
                manager.cancelRoutine(id)
                manager.removeRoutine(id)
                FocusSessionController.reconcileWithRoutines(context)
                result.success(null)
            }
            "isAnyRoutineActive" -> result.success(ScheduleManager(context).isAnyRoutineActive())

            // ── Tamper protection / uninstall control ────────────────────
            "enableProtectionGuard" -> {
                if (!isAccessibilityServiceEnabled(context)) {
                    result.error(
                        "ACCESSIBILITY_REQUIRED",
                        "Enable Detox's Accessibility service in Android Settings before enabling the screen guard.",
                        null
                    )
                    return
                }
                TamperGuard.isProtectionEnabled = true
                result.success(null)
            }
            "disableProtectionGuardAfterAuthentication" -> {
                TamperGuard.isProtectionEnabled = false
                TamperGuard.lock()
                result.success(null)
            }
            "getProtectionState" -> result.success(
                getProtectionState(context)
            )
            "isDeviceAdminActive" -> result.success(isDeviceAdminActive(context))
            "requestDeviceAdmin" -> {
                if (!context.packageManager.hasSystemFeature("android.software.device_admin")) {
                    result.error(
                        "UNSUPPORTED_CONFIGURATION",
                        "This Android device does not report Device Admin support.",
                        null
                    )
                    return
                }
                val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent(context))
                    .putExtra(
                        DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                        "When enabled, Android requires Device Admin to be deactivated before Detox can be uninstalled. This is an uninstall deterrent, not a guarantee."
                    )
                val opened = openSettings(context, intent) ||
                    openSettings(context, Intent(Settings.ACTION_SECURITY_SETTINGS))
                result.success(opened)
            }
            "speakLumi" -> {
                val text = call.argument<String>("text")
                    ?.takeIf { it.isNotBlank() }
                    ?: throw IllegalArgumentException("text is required")
                result.success(speakLumi(context, text))
            }
            "stopSpeakingLumi" -> {
                result.success(stopSpeakingLumi())
            }
            "playSoundscape" -> {
                val token = call.argument<String>("token") ?: "dewdrop_water_pluck"
                result.success(playSoundscape(token))
            }
            "startAmbientSoundscape" -> {
                val scene = call.argument<String>("scene") ?: "forest_rain"
                result.success(startAmbient(scene))
            }
            "stopAmbientSoundscape" -> {
                result.success(stopAmbient())
            }
            "deactivateDeviceAdminAfterAuthentication" -> {
                result.success(deactivateDeviceAdmin(context))
            }
            "setOwnerUninstallBlocked" -> {
                val blocked = call.argument<Boolean>("blocked")
                    ?: throw IllegalArgumentException("blocked is required")
                if (!blocked) {
                    result.error(
                        "AUTH_REQUIRED",
                        "Disabling owner-enforced uninstall blocking requires in-app authentication.",
                        null
                    )
                    return
                }
                result.success(setOwnerUninstallBlocked(context, true))
            }
            "disableOwnerUninstallBlockedAfterAuthentication" -> {
                result.success(setOwnerUninstallBlocked(context, false))
            }
            "prepareUninstall" -> {
                if (!deactivateDeviceAdmin(context)) {
                    result.error(
                        "DEACTIVATION_INCOMPLETE",
                        "Android still reports Detox as a device administrator or owner.",
                        null
                    )
                    return
                }
                TamperGuard.unlock(UNINSTALL_FLOW_UNLOCK_MS)
                val uninstall = Intent(Intent.ACTION_DELETE)
                    .setData(Uri.parse("package:${context.packageName}"))
                val started = openSettings(context, uninstall)
                if (!started) TamperGuard.lock()
                result.success(started)
            }

            else -> result.notImplemented()
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun openSettings(context: Context, intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "Unable to open ${intent.action}", e)
            false
        }
    }

    @Synchronized
    private fun speakLumi(context: Context, text: String): Boolean {
        return try {
            pendingLumiText = text
            if (lumiTts == null) {
                lumiTts = TextToSpeech(context.applicationContext) { status ->
                    if (status != TextToSpeech.SUCCESS) {
                        Log.e(TAG, "Android text-to-speech initialization failed: $status")
                        pendingLumiText = null
                        return@TextToSpeech
                    }
                    val engine = lumiTts ?: return@TextToSpeech
                    try {
                        engine.language = Locale.getDefault()
                    } catch (_: Exception) {}
                    engine.setSpeechRate(0.88f)
                    engine.setPitch(1.05f)
                    lumiTtsReady = true
                    pendingLumiText?.let { pending ->
                        engine.speak(
                            pending,
                            TextToSpeech.QUEUE_FLUSH,
                            null,
                            "lumi-${System.currentTimeMillis()}"
                        )
                    }
                    pendingLumiText = null
                }
                true
            } else if (lumiTtsReady) {
                lumiTts?.speak(
                    text,
                    TextToSpeech.QUEUE_FLUSH,
                    null,
                    "lumi-${System.currentTimeMillis()}"
                ) == TextToSpeech.SUCCESS
            } else {
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unable to speak Lumi message", e)
            false
        }
    }

    @Synchronized
    private fun stopSpeakingLumi(): Boolean {
        return try {
            pendingLumiText = null
            lumiTts?.stop()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Unable to stop Lumi speech", e)
            false
        }
    }

    private fun playSoundscape(token: String): Boolean {
        CoroutineScope(Dispatchers.Default).launch {
            try {
                val sampleRate = 44100
                val pcm: ShortArray = when (token) {
                    "bell_528_harmony" -> generateBell528(sampleRate)
                    "kalimba_pentatonic_sparkle" -> generateKalimba(sampleRate)
                    "singing_bowl_drone" -> generateSingingBowl(sampleRate)
                    "dewdrop_water_pluck" -> generateDewdrop(sampleRate)
                    "zen_wind_chime" -> generateWindChime(sampleRate)
                    else -> generateDewdrop(sampleRate)
                }
                playPcm(pcm, sampleRate)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to play soundscape: $token", e)
            }
        }
        return true
    }

    private fun playPcm(pcm: ShortArray, sampleRate: Int) {
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(pcm.size * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        track.write(pcm, 0, pcm.size)
        track.play()
        CoroutineScope(Dispatchers.IO).launch {
            delay((pcm.size.toDouble() / sampleRate * 1000).toLong() + 300)
            try {
                track.stop()
                track.release()
            } catch (_: Exception) {}
        }
    }

    private fun generateDewdrop(sampleRate: Int): ShortArray {
        val duration = 0.35
        val samples = (duration * sampleRate).toInt()
        val buffer = ShortArray(samples)
        for (i in 0 until samples) {
            val t = i.toDouble() / sampleRate
            val freq = 880.0 - (260.0 * (t / duration))
            val envelope = if (t < 0.005) t / 0.005 else exp(-(t - 0.005) * 12.0)
            val sample = sin(2 * PI * freq * t) * envelope * 0.40
            buffer[i] = (sample * Short.MAX_VALUE).toInt().toShort()
        }
        return buffer
    }

    private fun generateBell528(sampleRate: Int): ShortArray {
        val duration = 2.0
        val samples = (duration * sampleRate).toInt()
        val buffer = ShortArray(samples)
        val freqs = doubleArrayOf(528.0, 1056.0, 1584.0, 2112.0)
        val amps = doubleArrayOf(0.40, 0.18, 0.08, 0.03)

        for (i in 0 until samples) {
            val t = i.toDouble() / sampleRate
            val attack = if (t < 0.015) t / 0.015 else 1.0
            val decay = exp(-t * 2.2)
            var sample = 0.0
            for (f in freqs.indices) {
                sample += sin(2 * PI * freqs[f] * t) * amps[f]
            }
            buffer[i] = (sample * attack * decay * Short.MAX_VALUE).toInt().toShort()
        }
        return buffer
    }

    private fun generateKalimba(sampleRate: Int): ShortArray {
        val totalDuration = 1.3
        val totalSamples = (totalDuration * sampleRate).toInt()
        val buffer = ShortArray(totalSamples)
        val notes = doubleArrayOf(523.25, 659.25, 783.99, 880.0) // C5, E5, G5, A5
        val noteSpacing = 0.09

        for (n in notes.indices) {
            val startSample = (n * noteSpacing * sampleRate).toInt()
            val noteDuration = 0.6
            val noteSamples = (noteDuration * sampleRate).toInt()
            val freq = notes[n]

            for (i in 0 until noteSamples) {
                val destIdx = startSample + i
                if (destIdx >= totalSamples) break
                val t = i.toDouble() / sampleRate
                val attack = if (t < 0.005) t / 0.005 else 1.0
                val decay = exp(-t * 5.5)
                val fundamental = sin(2 * PI * freq * t)
                val overtone = 0.25 * sin(2 * PI * freq * 2.0 * t)
                val sample = (fundamental + overtone) * attack * decay * 0.25
                val current = buffer[destIdx].toDouble() / Short.MAX_VALUE
                buffer[destIdx] = ((current + sample).coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
            }
        }
        return buffer
    }

    private fun generateSingingBowl(sampleRate: Int): ShortArray {
        val duration = 2.8
        val samples = (duration * sampleRate).toInt()
        val buffer = ShortArray(samples)
        for (i in 0 until samples) {
            val t = i.toDouble() / sampleRate
            val attack = if (t < 0.40) t / 0.40 else 1.0
            val decay = if (t > 2.0) exp(-(t - 2.0) * 2.5) else 1.0
            val vibrato = 2.5 * sin(2 * PI * 4.5 * t)
            val fundamental = sin(2 * PI * (216.0 + vibrato) * t)
            val overtone = 0.35 * sin(2 * PI * 432.0 * t)
            val sample = (fundamental + overtone) * attack * decay * 0.30
            buffer[i] = (sample * Short.MAX_VALUE).toInt().toShort()
        }
        return buffer
    }

    private fun generateWindChime(sampleRate: Int): ShortArray {
        val totalDuration = 1.8
        val totalSamples = (totalDuration * sampleRate).toInt()
        val buffer = ShortArray(totalSamples)
        val notes = doubleArrayOf(659.25, 830.61, 987.77, 1318.51)
        val noteSpacing = 0.11

        for (n in notes.indices) {
            val startSample = (n * noteSpacing * sampleRate).toInt()
            val noteDuration = 1.0
            val noteSamples = (noteDuration * sampleRate).toInt()
            val freq = notes[n]

            for (i in 0 until noteSamples) {
                val destIdx = startSample + i
                if (destIdx >= totalSamples) break
                val t = i.toDouble() / sampleRate
                val attack = if (t < 0.01) t / 0.01 else 1.0
                val decay = exp(-t * 2.8)
                val sample = sin(2 * PI * freq * t) * attack * decay * 0.22
                val current = buffer[destIdx].toDouble() / Short.MAX_VALUE
                buffer[destIdx] = ((current + sample).coerceIn(-1.0, 1.0) * Short.MAX_VALUE).toInt().toShort()
            }
        }
        return buffer
    }

    @Synchronized
    private fun startAmbient(scene: String): Boolean {
        stopAmbient()
        ambientRunning = true
        val myGen = ++ambientGeneration
        CoroutineScope(Dispatchers.Default).launch {
            try {
                val sampleRate = 44100
                val bufferSize = sampleRate * 2
                val pcm = ShortArray(bufferSize)
                val fadeSamples = (sampleRate * 0.02).toInt() // 20ms boundary envelope for seamless loop

                when (scene) {
                    "soft_drone" -> {
                        for (i in 0 until bufferSize) {
                            val t = i.toDouble() / sampleRate
                            val wave = 0.60 * sin(2 * PI * 108.0 * t) + 0.30 * sin(2 * PI * 162.0 * t)
                            pcm[i] = (wave * 0.12 * Short.MAX_VALUE).toInt().toShort()
                        }
                    }
                    "forest_rain" -> {
                        var filtered = 0.0
                        for (i in 0 until bufferSize) {
                            val noise = Math.random() * 2.0 - 1.0
                            filtered = filtered * 0.94 + noise * 0.06
                            val env = when {
                                i < fadeSamples -> i.toDouble() / fadeSamples
                                i >= bufferSize - fadeSamples -> (bufferSize - 1 - i).toDouble() / fadeSamples
                                else -> 1.0
                            }
                            pcm[i] = (filtered * env * 0.35 * Short.MAX_VALUE).toInt().toShort()
                        }
                    }
                    "gentle_stream" -> {
                        var filtered = 0.0
                        for (i in 0 until bufferSize) {
                            val noise = Math.random() * 2.0 - 1.0
                            filtered = filtered * 0.84 + noise * 0.16
                            val mod = 0.8 + 0.2 * sin(2 * PI * 0.5 * (i.toDouble() / sampleRate))
                            val env = when {
                                i < fadeSamples -> i.toDouble() / fadeSamples
                                i >= bufferSize - fadeSamples -> (bufferSize - 1 - i).toDouble() / fadeSamples
                                else -> 1.0
                            }
                            pcm[i] = (filtered * mod * env * 0.28 * Short.MAX_VALUE).toInt().toShort()
                        }
                    }
                    else -> {
                        var filtered = 0.0
                        for (i in 0 until bufferSize) {
                            val noise = Math.random() * 2.0 - 1.0
                            filtered = filtered * 0.94 + noise * 0.06
                            val env = when {
                                i < fadeSamples -> i.toDouble() / fadeSamples
                                i >= bufferSize - fadeSamples -> (bufferSize - 1 - i).toDouble() / fadeSamples
                                else -> 1.0
                            }
                            pcm[i] = (filtered * env * 0.30 * Short.MAX_VALUE).toInt().toShort()
                        }
                    }
                }

                val track = AudioTrack.Builder()
                    .setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                            .build()
                    )
                    .setAudioFormat(
                        AudioFormat.Builder()
                            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                            .setSampleRate(sampleRate)
                            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                            .build()
                    )
                    .setBufferSizeInBytes(pcm.size * 2)
                    .setTransferMode(AudioTrack.MODE_STATIC)
                    .build()

                track.write(pcm, 0, pcm.size)
                track.setLoopPoints(0, pcm.size, -1)

                synchronized(this@FlutterBridge) {
                    if (!ambientRunning || myGen != ambientGeneration) {
                        try {
                            track.release()
                        } catch (_: Exception) {}
                        return@launch
                    }
                    track.play()
                    activeAmbientTrack = track
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start ambient: $scene", e)
            }
        }
        return true
    }

    @Synchronized
    private fun stopAmbient(): Boolean {
        ambientRunning = false
        ambientGeneration++
        try {
            activeAmbientTrack?.stop()
            activeAmbientTrack?.release()
            activeAmbientTrack = null
        } catch (_: Exception) {}
        return true
    }

    private fun adminComponent(context: Context) =
        ComponentName(context, FocusDeviceAdminReceiver::class.java)

    private fun isDeviceAdminActive(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isAdminActive(adminComponent(context))
    }

    private fun getProtectionState(context: Context): Map<String, Any> {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val component = adminComponent(context)
        val isDeviceOwner = dpm.isDeviceOwnerApp(context.packageName)
        val isProfileOwner = dpm.isProfileOwnerApp(context.packageName)
        val ownerCanBlockUninstall = isDeviceOwner || isProfileOwner

        return mapOf(
            "statusAvailable" to true,
            "deviceAdminSupported" to context.packageManager.hasSystemFeature("android.software.device_admin"),
            "deviceAdminActive" to dpm.isAdminActive(component),
            "accessibilityServiceEnabled" to isAccessibilityServiceEnabled(context),
            "guardEnabled" to TamperGuard.isProtectionEnabled,
            "deviceOwner" to isDeviceOwner,
            "profileOwner" to isProfileOwner,
            "ownerUninstallBlocked" to (
                ownerCanBlockUninstall && dpm.isUninstallBlocked(component, context.packageName)
            )
        )
    }

    private fun setOwnerUninstallBlocked(context: Context, blocked: Boolean): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val component = adminComponent(context)
        if (!dpm.isDeviceOwnerApp(context.packageName) &&
            !dpm.isProfileOwnerApp(context.packageName)
        ) {
            throw IllegalStateException(
                "Detox is not a Device Owner or Profile Owner; Android does not allow this app to enforce uninstall blocking."
            )
        }
        dpm.setUninstallBlocked(component, context.packageName, blocked)
        return dpm.isUninstallBlocked(component, context.packageName) == blocked
    }

    private fun deactivateDeviceAdmin(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val component = adminComponent(context)

        if (dpm.isProfileOwnerApp(context.packageName) &&
            !dpm.isDeviceOwnerApp(context.packageName)
        ) {
            throw IllegalStateException(
                "A Profile Owner must be removed through Android's managed-profile settings."
            )
        }
        if (dpm.isDeviceOwnerApp(context.packageName)) {
            dpm.setUninstallBlocked(component, context.packageName, false)
            dpm.clearDeviceOwnerApp(context.packageName)
        }
        if (dpm.isAdminActive(component)) {
            dpm.removeActiveAdmin(component)
        }
        return !dpm.isDeviceOwnerApp(context.packageName) &&
            !dpm.isAdminActive(component)
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val serviceId =
            "${context.packageName}/com.personal.phone_addiction_controller.services.AccessibilityMonitorService"
        val enabledServices = Secure.getString(
            context.contentResolver,
            Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabledServices)
        while (splitter.hasNext()) {
            if (splitter.next().equals(serviceId, ignoreCase = true)) return true
        }
        return false
    }

    private fun isBatteryOptDisabled(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun getUserAppsList(context: Context): List<Map<String, Any?>> {
        val pm = context.packageManager
        val classifier = AppClassifier(context)
        val mainIntent = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, 0)
        }

        val result = mutableListOf<Map<String, Any?>>()
        val seen = mutableSetOf<String>()
        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo?.packageName ?: continue
            if (packageName == context.packageName || !seen.add(packageName)) continue
            if (!classifier.isUserInstalledApp(packageName)) continue
            try {
                result.add(
                    mapOf(
                        "packageName" to packageName,
                        "appName" to resolveInfo.loadLabel(pm).toString(),
                        "icon" to getIconBytes(pm, packageName)
                    )
                )
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load app info for $packageName", e)
            }
        }
        result.sortBy { (it["appName"] as? String)?.lowercase(Locale.ROOT) }
        return result
    }

    private fun getIconBytes(pm: PackageManager, packageName: String): ByteArray? {
        return try {
            val bitmap = drawableToBitmap(pm.getApplicationIcon(packageName))
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) return drawable.bitmap
        val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
        val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}

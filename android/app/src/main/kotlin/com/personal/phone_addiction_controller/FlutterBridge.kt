package com.personal.phone_addiction_controller

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
import android.text.TextUtils
import android.util.Base64
import android.util.Log
import android.app.admin.DevicePolicyManager
import android.hardware.camera2.CameraManager
import android.net.wifi.WifiManager
import android.bluetooth.BluetoothAdapter
import android.media.AudioManager
import android.app.NotificationManager
import android.os.BatteryManager
import android.telephony.TelephonyManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.personal.phone_addiction_controller.services.FocusForegroundService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

object FlutterBridge {
    private const val TAG = "FlutterBridge"
    private const val METHOD_CHANNEL = "com.personal.phone_addiction_controller/accessibility"
    private const val EVENT_CHANNEL = "com.personal.phone_addiction_controller/foreground_app"
    private const val BLOCKED_EVENT_CHANNEL = "com.personal.phone_addiction_controller/blocked_events"

    private var eventSink: EventChannel.EventSink? = null
    private var blockedEventSink: EventChannel.EventSink? = null
    private var pendingBlockedEvent: Map<String, String>? = null
    private var mainActivityRef: MainActivity? = null
    private var isTorchOn = false

    fun setMainActivity(activity: MainActivity) {
        mainActivityRef = activity
    }

    /**
     * Requests Lock Task Mode restoration without triggering any navigation.
     *
     * Called by watchdog components that detect LTM has unexpectedly exited.
     * This ONLY calls FocusEnvironmentManager.enterFocusEnvironment() —
     * it does NOT call startActivity(), does NOT send focusRecover, does NOT navigate.
     *
     * Architecture rule: navigation decisions belong to FocusPolicyEngine alone.
     */
    fun requestLockTaskRestore() {
        val activity = mainActivityRef
        if (activity != null && !activity.isFinishing && !activity.isDestroyed) {
            Log.d(TAG, "requestLockTaskRestore: delegating to FocusEnvironmentManager.enterFocusEnvironment()")
            activity.runOnUiThread {
                FocusEnvironmentManager(activity).enterFocusEnvironment(activity)
            }
        } else {
            Log.w(TAG, "requestLockTaskRestore: MainActivity not available — skipping LTM restore")
        }
    }

    fun initialize(context: Context, flutterEngine: FlutterEngine) {
        FocusModeManager.init(context)
        NotificationHelper.createNotificationChannels(context)

        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            cameraManager.registerTorchCallback(object : CameraManager.TorchCallback() {
                override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
                    super.onTorchModeChanged(cameraId, enabled)
                    isTorchOn = enabled
                }
            }, null)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register torch callback", e)
        }

        // Setup MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // ── Accessibility ────────────────────────────────────────
                "isServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(context))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(null)
                }

                // ── Focus Mode ──────────────────────────────────────────
                "startFocusMode" -> {
                    val envManager = FocusEnvironmentManager(context)
                    envManager.startFocusSession()
                    envManager.enterFocusEnvironment(mainActivityRef)
                    result.success(null)
                }
                "stopFocusMode" -> {
                    val envManager = FocusEnvironmentManager(context)
                    envManager.endFocusSession()
                    envManager.exitFocusEnvironment(mainActivityRef)
                    FocusForegroundService.stop(context)
                    result.success(null)
                }
                "isFocusModeActive" -> {
                    result.success(FocusModeManager.isActive)
                }
                "getNativeSessionDetails" -> {
                    result.success(mapOf(
                        "isActive" to FocusModeManager.isActive,
                        "sessionStartTime" to FocusModeManager.sessionStartTime,
                        "scheduledEndTime" to FocusModeManager.scheduledEndTime,
                        "allowedApps" to FocusModeManager.allowedApps.toList(),
                        "alwaysAllowedApps" to FocusModeManager.alwaysAllowedApps.toList(),
                        "strictMode" to FocusModeManager.strictMode,
                        "isScheduled" to FocusModeManager.isScheduled,
                        "activeRoutineId" to FocusModeManager.activeRoutineId
                    ))
                }
                "getPendingBlockedEvent" -> {
                    val event = pendingBlockedEvent
                    pendingBlockedEvent = null
                    result.success(event)
                }
                "updateAllowedApps" -> {
                    val apps = call.argument<List<String>>("apps") ?: emptyList()
                    val alwaysAllowed = call.argument<List<String>>("alwaysAllowedApps") ?: emptyList()
                    FocusEnvironmentManager(context).updateAllowedApps(apps, alwaysAllowed)
                    FocusEnvironmentManager(context).enterFocusEnvironment(mainActivityRef)
                    result.success(null)
                }
                "updateStrictMode" -> {
                    val isStrict = call.argument<Boolean>("isStrict") ?: false
                    FocusModeManager.strictMode = isStrict
                    FocusEnvironmentManager(context).enterFocusEnvironment(mainActivityRef)
                    result.success(null)
                }
                "setEmergencyOverrideActive" -> {
                    val active = call.argument<Boolean>("active") ?: false
                    val expirationTime = call.argument<Long>("expirationTime") ?: 0L
                    FocusModeManager.emergencyOverrideActive = active
                    FocusModeManager.emergencyOverrideExpirationTime = expirationTime
                    result.success(null)
                }

                // ── Installed Apps / User Apps ──────────────────────────────
                "getUserApps", "getInstalledApps" -> {
                    val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                    CoroutineScope(Dispatchers.Main).launch {
                        try {
                            val apps = withContext(Dispatchers.IO) {
                                getUserAppsList(context, includeSystem)
                            }
                            result.success(apps)
                        } catch (e: Exception) {
                            result.error("APPS_ERROR", e.message, null)
                        }
                    }
                }
                "isSystemPackage" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(AppClassifier(context).isSystemPackage(packageName))
                }
                "getAppInfo" -> {
                    try {
                        val packageName = call.argument<String>("packageName") ?: ""
                        val info = getAppInfoMap(context, packageName)
                        result.success(info)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    result.success(isPackageInstalled(context, packageName))
                }
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName") ?: ""
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
                    if (launchIntent == null) {
                        result.error("LAUNCH_ERROR", "No launch intent for $packageName", null)
                    } else {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(launchIntent)
                        result.success(null)
                    }
                }

                // ── Schedule ────────────────────────────────────────────
                "scheduleRoutine" -> {
                    try {
                        val routineJson = call.argument<String>("routineJson") ?: "{}"
                        val manager = ScheduleManager(context)
                        manager.scheduleRoutine(routineJson)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SCHEDULE_ERROR", e.message, null)
                    }
                }
                "cancelRoutine" -> {
                    val routineId = call.argument<String>("routineId") ?: ""
                    val manager = ScheduleManager(context)
                    manager.cancelRoutine(routineId)
                    manager.removeRoutine(routineId)
                    result.success(null)
                }
                "cancelAllRoutines" -> {
                    val manager = ScheduleManager(context)
                    manager.cancelAllRoutines()
                    result.success(null)
                }
                "isAnyRoutineActive" -> {
                    val manager = ScheduleManager(context)
                    result.success(manager.isAnyRoutineActive())
                }

                // ── Battery Optimization ────────────────────────────────
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptDisabled(context))
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        // Fallback to general battery settings
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(null)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }

                // ── Overlay Permission ──────────────────────────────────
                "openOverlayPermissionSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "canDrawOverlays" -> {
                    result.success(Settings.canDrawOverlays(context))
                }

                // ── Notification Permission ─────────────────────────────
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                // ── Foreground Service ───────────────────────────────────
                "startForegroundService" -> {
                    FocusForegroundService.start(context)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    FocusForegroundService.stop(context)
                    result.success(null)
                }

                // ── Device Owner ────────────────────────────────────────
                "isDeviceOwner" -> {
                    result.success(isDeviceOwner(context))
                }
                "removeDeviceOwner" -> {
                    try {
                        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = android.content.ComponentName(context, com.personal.phone_addiction_controller.receivers.FocusDeviceAdminReceiver::class.java)
                        if (dpm.isDeviceOwnerApp(context.packageName)) {
                            // Clear uninstall block first
                            dpm.setUninstallBlocked(adminComponent, context.packageName, false)
                            // Clear all restrictions
                            dpm.clearUserRestriction(adminComponent, android.os.UserManager.DISALLOW_SAFE_BOOT)
                            dpm.clearUserRestriction(adminComponent, android.os.UserManager.DISALLOW_FACTORY_RESET)
                            dpm.clearUserRestriction(adminComponent, android.os.UserManager.DISALLOW_ADD_USER)
                            dpm.clearUserRestriction(adminComponent, android.os.UserManager.DISALLOW_MOUNT_PHYSICAL_MEDIA)
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                dpm.setStatusBarDisabled(adminComponent, false)
                            }
                            // Remove Device Owner
                            dpm.clearDeviceOwnerApp(context.packageName)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("DO_REMOVE_ERROR", e.message, null)
                    }
                }

                // ── Default Launcher ────────────────────────────────────
                "isDefaultLauncher" -> {
                    result.success(isDefaultLauncher(context))
                }
                "openDefaultLauncherSettings" -> {
                    try {
                        // Try HOME_SETTINGS first (Android 10+)
                        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        try {
                            // Fallback to MANAGE_DEFAULT_APPS_SETTINGS
                            val intent = Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            context.startActivity(intent)
                            result.success(null)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }
                "openLauncherChooser" -> {
                    try {
                        val homeIntent = Intent(Intent.ACTION_MAIN)
                        homeIntent.addCategory(Intent.CATEGORY_HOME)
                        val chooser = Intent.createChooser(homeIntent, "Select Home App")
                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(chooser)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("CHOOSER_ERROR", e.message, null)
                    }
                }

                // ── Diagnostics ────────────────────────────────────────
                "getDiagnosticsData" -> {
                    try {
                        DiagnosticsLogger.init(context)
                        FocusModeManager.init(context)

                        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager

                        val scheduleManager = ScheduleManager(context)
                        val nextRoutineInfo = scheduleManager.getActiveRoutineJson()

                        result.success(mapOf(
                            "isDeviceOwner" to dpm.isDeviceOwnerApp(context.packageName),
                            "lockTaskState" to am.lockTaskModeState,
                            "isAccessibilityRunning" to isAccessibilityServiceEnabled(context),
                            "isForegroundServiceRunning" to com.personal.phone_addiction_controller.services.FocusForegroundService.isRunning(context),
                            "isFocusActive" to FocusModeManager.isActive,
                            "sessionStartTime" to FocusModeManager.sessionStartTime,
                            "scheduledEndTime" to FocusModeManager.scheduledEndTime,
                            "activeRoutineId" to (FocusModeManager.activeRoutineId ?: ""),
                            "strictMode" to FocusModeManager.strictMode,
                            "isScheduled" to FocusModeManager.isScheduled,
                            "lastBootTime" to DiagnosticsLogger.getLastBootTime(),
                            "lastWatchdogRepair" to DiagnosticsLogger.getLastWatchdogRepair(),
                            "lastBlockedApp" to DiagnosticsLogger.getLastBlockedApp(),
                            "lastRecoveryEvent" to DiagnosticsLogger.getLastRecoveryEvent(),
                            "allEvents" to DiagnosticsLogger.getAllEvents(),
                            "activeRoutineJson" to (nextRoutineInfo ?: ""),
                            "isBatteryOptimizationDisabled" to isBatteryOptDisabled(context)
                        ))
                    } catch (e: Exception) {
                        result.error("DIAGNOSTICS_ERROR", e.message, null)
                    }
                }

                // ── Foreground Service Status ───────────────────────────
                "isForegroundServiceRunning" -> {
                    result.success(com.personal.phone_addiction_controller.services.FocusForegroundService.isRunning(context))
                }

                // ── Control Center ──────────────────────────────────────
                "getControlCenterData" -> {
                    try {
                        val bm = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val batteryLevel = try {
                            bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                        } catch (_: Exception) { -1 }

                        val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        val wifiEnabled = wifiManager.isWifiEnabled

                        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                        val bluetoothEnabled = bluetoothAdapter?.isEnabled ?: false

                        val isAirplaneModeOn = Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0

                        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val ringerMode = audioManager.ringerMode
                        val volume = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)

                        val brightness = Settings.System.getInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, 128)

                        val canWriteSettings = Settings.System.canWrite(context)

                        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val hasDndAccess = Build.VERSION.SDK_INT < Build.VERSION_CODES.M || nm.isNotificationPolicyAccessGranted

                        result.success(mapOf(
                            "batteryLevel" to batteryLevel,
                            "wifiEnabled" to wifiEnabled,
                            "bluetoothEnabled" to bluetoothEnabled,
                            "airplaneModeEnabled" to isAirplaneModeOn,
                            "ringerMode" to ringerMode,
                            "brightness" to brightness,
                            "volume" to volume,
                            "maxVolume" to maxVolume,
                            "hasWriteSettingsPermission" to canWriteSettings,
                            "hasDndPermission" to hasDndAccess,
                            "isFlashlightEnabled" to isTorchOn
                        ))
                    } catch (e: Exception) {
                        result.error("CONTROL_CENTER_ERROR", e.message, null)
                    }
                }
                "setWifiEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            // On Android 10+, programmatic Wifi toggle is restricted.
                            // Return false to tell Dart to fall back to opening settings.
                            result.success(false)
                        } else {
                            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            @Suppress("DEPRECATION")
                            wifiManager.isWifiEnabled = enabled
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("WIFI_ERROR", e.message, null)
                    }
                }
                "setBluetoothEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
                        if (bluetoothAdapter != null) {
                            if (Build.VERSION.SDK_INT >= 33) {
                                // On Android 13+, programmatic Bluetooth toggle is restricted.
                                result.success(false)
                            } else {
                                if (enabled) {
                                    @Suppress("DEPRECATION")
                                    bluetoothAdapter.enable()
                                } else {
                                    @Suppress("DEPRECATION")
                                    bluetoothAdapter.disable()
                                }
                                result.success(true)
                            }
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("BLUETOOTH_ERROR", e.message, null)
                    }
                }
                "setFlashlightEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    try {
                        val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
                        val cameraId = cameraManager.cameraIdList.firstOrNull()
                        if (cameraId != null) {
                            cameraManager.setTorchMode(cameraId, enabled)
                            isTorchOn = enabled
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("TORCH_ERROR", e.message, null)
                    }
                }
                "setBrightness" -> {
                    val brightness = call.argument<Int>("brightness") ?: 128
                    try {
                        if (Settings.System.canWrite(context)) {
                            Settings.System.putInt(context.contentResolver, Settings.System.SCREEN_BRIGHTNESS, brightness)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    } catch (e: Exception) {
                        result.error("BRIGHTNESS_ERROR", e.message, null)
                    }
                }
                "setVolume" -> {
                    val volume = call.argument<Int>("volume") ?: 0
                    try {
                        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", e.message, null)
                    }
                }
                "setRingerMode" -> {
                    val mode = call.argument<Int>("mode") ?: AudioManager.RINGER_MODE_NORMAL
                    try {
                        val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val hasDndAccess = Build.VERSION.SDK_INT < Build.VERSION_CODES.M || nm.isNotificationPolicyAccessGranted
                        
                        if (!hasDndAccess && (mode == AudioManager.RINGER_MODE_SILENT || mode == AudioManager.RINGER_MODE_VIBRATE)) {
                            result.success(false)
                        } else {
                            audioManager.ringerMode = mode
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.error("RINGER_ERROR", e.message, null)
                    }
                }
                "openWriteSettingsPermissionSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "openDndAccessSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "openWifiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "openMobileDataSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_DATA_ROAMING_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("SETTINGS_ERROR", e2.message, null)
                        }
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }
                "openAirplaneModeSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_AIRPLANE_MODE_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SETTINGS_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // Setup EventChannel for Foreground Apps
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // Setup EventChannel for Blocked Events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, BLOCKED_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    blockedEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    blockedEventSink = null
                }
            }
        )
    }

    fun sendForegroundAppUpdate(app: ForegroundApp) {
        eventSink?.success(
            mapOf(
                "packageName" to app.packageName,
                "appName" to app.appName
            )
        )
    }

    fun sendBlockedEvent(packageName: String, appName: String) {
        pendingBlockedEvent = mapOf(
            "packageName" to packageName,
            "appName" to appName
        )
        blockedEventSink?.success(
            mapOf(
                "packageName" to packageName,
                "appName" to appName,
                "timestamp" to System.currentTimeMillis()
            )
        )
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val serviceId = "${context.packageName}/com.personal.phone_addiction_controller.services.AccessibilityMonitorService"
        val enabledServices = Secure.getString(
            context.contentResolver,
            Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServices)

        while (colonSplitter.hasNext()) {
            val componentName = colonSplitter.next()
            if (componentName.equals(serviceId, ignoreCase = true)) {
                return true
            }
        }
        return false
    }

    private fun getUserAppsList(context: Context, includeSystem: Boolean): List<Map<String, Any?>> {
        val pm = context.packageManager
        val classifier = AppClassifier(context)
        val mainIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(mainIntent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(mainIntent, 0)
        }

        val result = mutableListOf<Map<String, Any?>>()
        val ownPackage = context.packageName
        val processedPackages = mutableSetOf<String>()

        for (resolveInfo in resolveInfos) {
            val packageName = resolveInfo.activityInfo?.packageName ?: continue
            if (packageName == ownPackage) continue
            if (processedPackages.contains(packageName)) continue
            processedPackages.add(packageName)

            if (!includeSystem && !classifier.isUserInstalledApp(packageName)) {
                continue
            }

            try {
                val appName = resolveInfo.loadLabel(pm).toString()
                val iconBytes = getIconBytes(pm, packageName)

                result.add(mapOf(
                    "packageName" to packageName,
                    "appName" to appName,
                    "icon" to iconBytes
                ))
            } catch (e: Exception) {
                Log.w(TAG, "Failed to load app info for $packageName", e)
            }
        }

        result.sortBy { (it["appName"] as? String)?.lowercase(Locale.ROOT) }
        return result
    }

    private fun getAppInfoMap(context: Context, packageName: String): Map<String, Any?>? {
        val pm = context.packageManager
        return try {
            val appInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(packageName, 0)
            }
            val appName = pm.getApplicationLabel(appInfo).toString()
            val iconBytes = getIconBytes(pm, packageName)
            mapOf(
                "packageName" to packageName,
                "appName" to appName,
                "icon" to iconBytes
            )
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun isPackageInstalled(context: Context, packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getApplicationInfo(packageName, 0)
            }
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private const val MAX_ICON_SIZE = 96

    private fun getIconBytes(pm: PackageManager, packageName: String): ByteArray? {
        return try {
            val drawable = pm.getApplicationIcon(packageName)
            val bitmap = drawableToBitmap(drawable)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 80, stream)
            val bytes = stream.toByteArray()
            if (bitmap !== (drawable as? BitmapDrawable)?.bitmap) {
                bitmap.recycle()
            }
            bytes
        } catch (e: Exception) {
            null
        }
    }

    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap.width <= MAX_ICON_SIZE) {
            return drawable.bitmap
        }
        val srcWidth = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 48
        val srcHeight = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 48
        // Scale down large icons to prevent OOM
        val scale = if (srcWidth > MAX_ICON_SIZE || srcHeight > MAX_ICON_SIZE) {
            MAX_ICON_SIZE.toFloat() / maxOf(srcWidth, srcHeight)
        } else 1f
        val width = (srcWidth * scale).toInt()
        val height = (srcHeight * scale).toInt()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }

    private fun isDefaultLauncher(context: Context): Boolean {
        val homeIntent = Intent(Intent.ACTION_MAIN)
        homeIntent.addCategory(Intent.CATEGORY_HOME)
        val resolveInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.resolveActivity(
                homeIntent,
                PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong())
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)
        }
        val currentHome = resolveInfo?.activityInfo?.packageName
        return currentHome == context.packageName
    }

    private fun isBatteryOptDisabled(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    private fun isDeviceOwner(context: Context): Boolean {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        return dpm.isDeviceOwnerApp(context.packageName)
    }
}

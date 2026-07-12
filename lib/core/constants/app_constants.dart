class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'FocusOS';
  static const String packageName = 'com.personal.phone_addiction_controller';
  static const String appVersion = '1.0.0+1';

  // Hive Box Names
  static const String focusSessionBox = 'focus_sessions';
  static const String allowedAppsBox = 'allowed_apps';
  static const String routinesBox = 'routines';
  static const String adminSettingsBox = 'admin_settings';
  static const String settingsBox = 'settings';
  static const String appSettingsBox = 'app_settings';
  static const String focusSessionSnapshotBox = 'focus_session_snapshots';
  static const String emergencyOverrideBox = 'emergency_override';

  // Hive Type IDs
  static const int focusSessionTypeId = 0;
  static const int allowedAppTypeId = 1;
  static const int routineTypeId = 2;
  static const int adminSettingsTypeId = 3;
  static const int appSettingsTypeId = 4;
  static const int sessionTriggerTypeId = 5;
  static const int sessionStopTypeId = 6;
  static const int timeSlotTypeId = 7;
  static const int focusSessionSnapshotTypeId = 8;
  static const int emergencyOverrideTypeId = 9;

  // Settings Keys
  static const String themeKey = 'theme_mode';
  static const String focusActiveKey = 'focus_active';
  static const String adminPasswordKey = 'admin_password_hash';
  static const String appSettingsKey = 'app_settings';

  // Default Values
  static const int defaultFocusDurationMinutes = 25;
  static const int defaultBreakDurationMinutes = 5;

  // Notification
  static const String focusNotificationChannelId = 'focus_mode_channel';
  static const String scheduleNotificationChannelId = 'schedule_channel';
  static const int focusNotificationId = 1001;
  static const int scheduleNotificationId = 1002;

  // Platform Channels
  static const String accessibilityChannel =
      '$packageName/accessibility';
  static const String foregroundAppEventChannel =
      '$packageName/foreground_app';
  static const String blockedEventChannel =
      '$packageName/blocked_events';
  static const String navigationChannel =
      '$packageName/navigation';

  // Accessibility Service Class
  static const String accessibilityServiceClass =
      '$packageName/com.personal.phone_addiction_controller.services.AccessibilityMonitorService';

  // Backup
  static const String backupFilePrefix = 'focusos_backup';
  static const int backupVersion = 1;
}

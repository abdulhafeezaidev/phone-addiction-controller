class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Detox';
  static const String packageName = 'com.personal.phone_addiction_controller';
  static const String appVersion = '1.0.0+1';

  // Hive Box Names
  static const String routinesBox = 'routines';
  static const String adminSettingsBox = 'admin_settings';
  static const String emergencyOverrideBox = 'emergency_override';
  static const String settingsBox = 'settings';

  // Hive Type IDs
  static const int routineTypeId = 2;
  static const int adminSettingsTypeId = 3;
  static const int timeSlotTypeId = 7;
  static const int emergencyOverrideTypeId = 9;

  // Settings Keys
  static const String onboardingCompletedKey = 'onboarding_completed';
  static const String adminPasswordKey = 'admin_password_hash';
  static const String lastBlockedPackagesKey = 'last_blocked_packages';
  static const String protectionEnabledKey = 'protection_enabled';
  static const String emergencyReflectionMinsKey = 'emergency_reflection_mins';
  static const String emergencyOverrideHoursKey = 'emergency_override_hours';
  static const String emergencyCooldownHoursKey = 'emergency_cooldown_hours';

  // Platform Channels
  static const String accessibilityChannel = '$packageName/accessibility';
  static const String navigationChannel = '$packageName/navigation';
}

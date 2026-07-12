import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'app_settings.g.dart';

/// Persisted application settings.
@HiveType(typeId: AppConstants.appSettingsTypeId)
class AppSettings extends HiveObject with EquatableMixin {
  /// Whether strict mode is enabled (prevents uninstall during focus).
  @HiveField(0)
  bool strictMode;

  /// Whether focus reminders / notifications are enabled.
  @HiveField(1)
  bool notificationsEnabled;

  /// Whether to auto-start focus mode on boot.
  @HiveField(2)
  bool autoStartOnBoot;

  /// Whether the user has dismissed the battery optimization card.
  @HiveField(3)
  bool batteryOptDismissed;

  /// Theme mode: 0 = system, 1 = light, 2 = dark.
  @HiveField(4)
  int themeMode;

  AppSettings({
    this.strictMode = false,
    this.notificationsEnabled = true,
    this.autoStartOnBoot = false,
    this.batteryOptDismissed = false,
    this.themeMode = 2,
  });

  AppSettings copyWith({
    bool? strictMode,
    bool? notificationsEnabled,
    bool? autoStartOnBoot,
    bool? batteryOptDismissed,
    int? themeMode,
  }) {
    return AppSettings(
      strictMode: strictMode ?? this.strictMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoStartOnBoot: autoStartOnBoot ?? this.autoStartOnBoot,
      batteryOptDismissed: batteryOptDismissed ?? this.batteryOptDismissed,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [
        strictMode,
        notificationsEnabled,
        autoStartOnBoot,
        batteryOptDismissed,
        themeMode,
      ];
}

import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'focus_session_snapshot.g.dart';

@HiveType(typeId: AppConstants.focusSessionSnapshotTypeId)
class FocusSessionSnapshot extends HiveObject with EquatableMixin {
  @HiveField(0)
  final String sessionId;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime endTime;

  @HiveField(3)
  final Duration duration;

  @HiveField(4)
  final List<String> allowedApps;

  @HiveField(5)
  final List<String> alwaysAllowedApps;

  @HiveField(6)
  final String activeProfile;

  @HiveField(7)
  final Map<String, String> blockingRules;

  @HiveField(8)
  final Map<String, String> focusSettings;

  @HiveField(9)
  final String? scheduleId;

  @HiveField(10)
  final DateTime creationTimestamp;

  FocusSessionSnapshot({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.allowedApps,
    required this.alwaysAllowedApps,
    required this.activeProfile,
    required this.blockingRules,
    required this.focusSettings,
    this.scheduleId,
    required this.creationTimestamp,
  });

  FocusSessionSnapshot copyWith({
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    Duration? duration,
    List<String>? allowedApps,
    List<String>? alwaysAllowedApps,
    String? activeProfile,
    Map<String, String>? blockingRules,
    Map<String, String>? focusSettings,
    String? scheduleId,
    DateTime? creationTimestamp,
  }) {
    return FocusSessionSnapshot(
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      allowedApps: allowedApps ?? this.allowedApps,
      alwaysAllowedApps: alwaysAllowedApps ?? this.alwaysAllowedApps,
      activeProfile: activeProfile ?? this.activeProfile,
      blockingRules: blockingRules ?? this.blockingRules,
      focusSettings: focusSettings ?? this.focusSettings,
      scheduleId: scheduleId ?? this.scheduleId,
      creationTimestamp: creationTimestamp ?? this.creationTimestamp,
    );
  }

  @override
  List<Object?> get props => [
        sessionId,
        startTime,
        endTime,
        duration,
        allowedApps,
        alwaysAllowedApps,
        activeProfile,
        blockingRules,
        focusSettings,
        scheduleId,
        creationTimestamp,
      ];
}

import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'focus_session.g.dart';

/// How the focus session was started.
@HiveType(typeId: AppConstants.sessionTriggerTypeId)
enum SessionTriggerType {
  @HiveField(0)
  manual,
  @HiveField(1)
  scheduled,
}

/// How the focus session was stopped.
@HiveType(typeId: AppConstants.sessionStopTypeId)
enum SessionStopType {
  @HiveField(0)
  manual,
  @HiveField(1)
  scheduled,
  @HiveField(2)
  completed,
  @HiveField(3)
  appRestart,
}

/// Represents a single Focus Mode session with tracking metadata.
@HiveType(typeId: AppConstants.focusSessionTypeId)
class FocusSession extends HiveObject with EquatableMixin {
  @HiveField(0)
  DateTime startTime;

  @HiveField(1)
  DateTime? endTime;

  @HiveField(2)
  bool enabled;

  /// Unique identifier for this session.
  @HiveField(3)
  String id;

  /// How this session was started.
  @HiveField(4)
  SessionTriggerType triggerType;

  /// How this session was stopped. Null if still active.
  @HiveField(5)
  SessionStopType? stopType;

  /// Number of blocked app attempts during this session.
  @HiveField(6)
  int blockedAttempts;

  /// Map of package name → blocked count for "most blocked" statistics.
  @HiveField(7)
  Map<String, int> blockedAppCounts;

  /// ID of the routine that triggered this session, if scheduled.
  @HiveField(8)
  String? routineId;

  FocusSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.enabled = false,
    this.triggerType = SessionTriggerType.manual,
    this.stopType,
    this.blockedAttempts = 0,
    Map<String, int>? blockedAppCounts,
    this.routineId,
  }) : blockedAppCounts = blockedAppCounts ?? {};

  FocusSession copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    bool? enabled,
    SessionTriggerType? triggerType,
    SessionStopType? stopType,
    int? blockedAttempts,
    Map<String, int>? blockedAppCounts,
    String? routineId,
  }) {
    return FocusSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      enabled: enabled ?? this.enabled,
      triggerType: triggerType ?? this.triggerType,
      stopType: stopType ?? this.stopType,
      blockedAttempts: blockedAttempts ?? this.blockedAttempts,
      blockedAppCounts: blockedAppCounts ?? Map.from(this.blockedAppCounts),
      routineId: routineId ?? this.routineId,
    );
  }

  /// Duration of the session. Returns null if the session is ongoing.
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Whether this session is currently active.
  bool get isActive => enabled && endTime == null;

  /// Record a blocked app attempt.
  void recordBlockedAttempt(String packageName) {
    blockedAttempts++;
    blockedAppCounts[packageName] = (blockedAppCounts[packageName] ?? 0) + 1;
  }

  @override
  List<Object?> get props => [
        id,
        startTime,
        endTime,
        enabled,
        triggerType,
        stopType,
        blockedAttempts,
        routineId,
      ];
}

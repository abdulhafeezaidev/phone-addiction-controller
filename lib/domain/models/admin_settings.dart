import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'admin_settings.g.dart';

/// Stores administrator password and security settings.
@HiveType(typeId: AppConstants.adminSettingsTypeId)
class AdminSettings extends HiveObject with EquatableMixin {
  /// SHA-256 hash of the administrator password.
  @HiveField(0)
  String passwordHash;

  /// Whether the admin lock is currently enabled.
  @HiveField(1)
  bool isLockEnabled;

  /// Maximum failed attempts before temporary lockout.
  @HiveField(2)
  int maxFailedAttempts;

  /// Timestamp of last failed attempt.
  @HiveField(3)
  DateTime? lastFailedAttempt;

  /// Number of consecutive failed attempts.
  @HiveField(4)
  int failedAttemptCount;

  /// The emergency override recovery challenge question.
  @HiveField(5)
  String? recoveryChallenge;

  /// SHA-256 hash of the recovery answer.
  @HiveField(6)
  String? recoveryAnswerHash;

  AdminSettings({
    required this.passwordHash,
    this.isLockEnabled = true,
    this.maxFailedAttempts = 5,
    this.lastFailedAttempt,
    this.failedAttemptCount = 0,
    this.recoveryChallenge,
    this.recoveryAnswerHash,
  });

  AdminSettings copyWith({
    String? passwordHash,
    bool? isLockEnabled,
    int? maxFailedAttempts,
    DateTime? lastFailedAttempt,
    int? failedAttemptCount,
    String? recoveryChallenge,
    String? recoveryAnswerHash,
  }) {
    return AdminSettings(
      passwordHash: passwordHash ?? this.passwordHash,
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      maxFailedAttempts: maxFailedAttempts ?? this.maxFailedAttempts,
      lastFailedAttempt: lastFailedAttempt ?? this.lastFailedAttempt,
      failedAttemptCount: failedAttemptCount ?? this.failedAttemptCount,
      recoveryChallenge: recoveryChallenge ?? this.recoveryChallenge,
      recoveryAnswerHash: recoveryAnswerHash ?? this.recoveryAnswerHash,
    );
  }

  @override
  List<Object?> get props => [
        passwordHash,
        isLockEnabled,
        maxFailedAttempts,
        lastFailedAttempt,
        failedAttemptCount,
        recoveryChallenge,
        recoveryAnswerHash,
      ];
}

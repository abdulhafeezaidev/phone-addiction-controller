import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'admin_settings.g.dart';

/// Stores administrator password, accountability partner info, and security settings.
@HiveType(typeId: AppConstants.adminSettingsTypeId)
// ignore: must_be_immutable
class AdminSettings extends HiveObject with EquatableMixin {
  /// Salted PBKDF2-like hash of the administrator password.
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

  /// Name of the chosen administrator / accountability partner.
  @HiveField(7)
  String? adminName;

  /// Contact (phone number or email) of the administrator.
  @HiveField(8)
  String? adminContact;

  AdminSettings({
    required this.passwordHash,
    this.isLockEnabled = true,
    this.maxFailedAttempts = 5,
    this.lastFailedAttempt,
    this.failedAttemptCount = 0,
    this.recoveryChallenge,
    this.recoveryAnswerHash,
    this.adminName,
    this.adminContact,
  });

  AdminSettings copyWith({
    String? passwordHash,
    bool? isLockEnabled,
    int? maxFailedAttempts,
    DateTime? lastFailedAttempt,
    int? failedAttemptCount,
    String? recoveryChallenge,
    String? recoveryAnswerHash,
    String? adminName,
    String? adminContact,
  }) {
    return AdminSettings(
      passwordHash: passwordHash ?? this.passwordHash,
      isLockEnabled: isLockEnabled ?? this.isLockEnabled,
      maxFailedAttempts: maxFailedAttempts ?? this.maxFailedAttempts,
      lastFailedAttempt: lastFailedAttempt ?? this.lastFailedAttempt,
      failedAttemptCount: failedAttemptCount ?? this.failedAttemptCount,
      recoveryChallenge: recoveryChallenge ?? this.recoveryChallenge,
      recoveryAnswerHash: recoveryAnswerHash ?? this.recoveryAnswerHash,
      adminName: adminName ?? this.adminName,
      adminContact: adminContact ?? this.adminContact,
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
        adminName,
        adminContact,
      ];
}

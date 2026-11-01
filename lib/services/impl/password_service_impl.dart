import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../../domain/models/admin_settings.dart';
import '../../core/constants/app_constants.dart';
import '../interfaces/password_service.dart';
import '../interfaces/storage_service.dart';

/// Concrete implementation of [PasswordService].
/// Uses PBKDF2-like salted iterations of HMAC-SHA256 and Hive for persistence.
class PasswordServiceImpl implements PasswordService {
  final StorageService _storageService;

  PasswordServiceImpl(this._storageService);

  static const Duration _lockoutDuration = Duration(seconds: 30);
  static const int _iterations = 1000;

  @override
  String hashPassword(String plainPassword) {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    final saltHex = base64.encode(saltBytes);

    final hashHex = _pbkdf2Like(plainPassword, saltHex);
    return '$saltHex:$hashHex';
  }

  String _pbkdf2Like(String password, String salt) {
    final key = utf8.encode(password);
    final saltBytes = utf8.encode(salt);
    final hmac = Hmac(sha256, key);

    var hash = hmac.convert(saltBytes).bytes;
    for (var i = 1; i < _iterations; i++) {
      hash = hmac.convert(hash).bytes;
    }
    return base64.encode(hash);
  }

  @override
  bool verifyPassword(String plainPassword, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;

    final saltHex = parts[0];
    final hashHex = parts[1];

    final calculatedHash = _pbkdf2Like(plainPassword, saltHex);
    return calculatedHash == hashHex;
  }

  @override
  Future<void> setPassword(String plainPassword) async {
    final hashed = hashPassword(plainPassword);
    final current = await getAdminSettings();
    final updated = (current ?? AdminSettings(passwordHash: hashed)).copyWith(
      passwordHash: hashed,
      failedAttemptCount: 0,
      lastFailedAttempt: null,
    );
    await _storageService.put(
      AppConstants.adminSettingsBox,
      AppConstants.adminPasswordKey,
      updated,
    );
  }

  @override
  Future<void> saveAdminConfig({
    required String password,
    String? adminName,
    String? adminContact,
    String? recoveryChallenge,
    String? recoveryAnswer,
  }) async {
    final hashed = hashPassword(password);
    String? hashedAnswer;
    if (recoveryAnswer != null && recoveryAnswer.trim().isNotEmpty) {
      final normalized = recoveryAnswer.trim().toLowerCase();
      hashedAnswer = sha256.convert(utf8.encode(normalized)).toString();
    }

    final settings = AdminSettings(
      passwordHash: hashed,
      adminName: adminName,
      adminContact: adminContact,
      recoveryChallenge: recoveryChallenge,
      recoveryAnswerHash: hashedAnswer,
      failedAttemptCount: 0,
      lastFailedAttempt: null,
    );

    await _storageService.put(
      AppConstants.adminSettingsBox,
      AppConstants.adminPasswordKey,
      settings,
    );
  }

  @override
  Future<void> updateAdminProfile({
    String? adminName,
    String? adminContact,
  }) async {
    final current = await getAdminSettings();
    if (current == null) return;
    final updated = current.copyWith(
      adminName: adminName ?? current.adminName,
      adminContact: adminContact ?? current.adminContact,
    );
    await _storageService.put(
      AppConstants.adminSettingsBox,
      AppConstants.adminPasswordKey,
      updated,
    );
  }

  @override
  Future<AdminSettings?> getAdminSettings() async {
    try {
      return _storageService.get<AdminSettings>(
        AppConstants.adminSettingsBox,
        AppConstants.adminPasswordKey,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<AdminSettings> recordFailedAttempt() async {
    final current = await getAdminSettings();
    if (current == null) {
      throw StateError('Cannot record attempt when no password is set.');
    }
    final updated = current.copyWith(
      failedAttemptCount: current.failedAttemptCount + 1,
      lastFailedAttempt: DateTime.now(),
    );
    await _storageService.put(
      AppConstants.adminSettingsBox,
      AppConstants.adminPasswordKey,
      updated,
    );
    return updated;
  }

  @override
  Future<void> resetFailedAttempts() async {
    final current = await getAdminSettings();
    if (current == null) return;
    final updated = current.copyWith(
      failedAttemptCount: 0,
      lastFailedAttempt: null,
    );
    await _storageService.put(
      AppConstants.adminSettingsBox,
      AppConstants.adminPasswordKey,
      updated,
    );
  }

  @override
  Future<bool> isLockedOut() async {
    final settings = await getAdminSettings();
    if (settings == null) return false;

    if (settings.failedAttemptCount >= settings.maxFailedAttempts) {
      final lastFailed = settings.lastFailedAttempt;
      if (lastFailed != null) {
        final timePassed = DateTime.now().difference(lastFailed);
        return timePassed < _lockoutDuration;
      }
    }
    return false;
  }

  @override
  Future<Duration> getRemainingLockoutDuration() async {
    final settings = await getAdminSettings();
    if (settings == null) return Duration.zero;

    if (settings.failedAttemptCount >= settings.maxFailedAttempts) {
      final lastFailed = settings.lastFailedAttempt;
      if (lastFailed != null) {
        final timePassed = DateTime.now().difference(lastFailed);
        final remaining = _lockoutDuration - timePassed;
        return remaining.isNegative ? Duration.zero : remaining;
      }
    }
    return Duration.zero;
  }

  @override
  Future<void> resetPassword() async {
    await _storageService.delete(AppConstants.adminSettingsBox, AppConstants.adminPasswordKey);
  }
}

import '../../domain/models/admin_settings.dart';

/// Abstract interface for the Password Service.
///
/// Handles admin password hashing, verification, accountability partner info, and lockout logic.
abstract class PasswordService {
  /// Hashes [plainPassword] using salted PBKDF2-like HMAC-SHA256.
  String hashPassword(String plainPassword);

  /// Returns true if [plainPassword] matches the stored [storedHash].
  bool verifyPassword(String plainPassword, String storedHash);

  /// Sets a new admin password. Hashes it before storing.
  Future<void> setPassword(String plainPassword);

  /// Saves the complete admin configuration including accountability partner and recovery questions.
  Future<void> saveAdminConfig({
    required String password,
    String? adminName,
    String? adminContact,
    String? recoveryChallenge,
    String? recoveryAnswer,
  });

  /// Updates admin name and contact info.
  Future<void> updateAdminProfile({
    String? adminName,
    String? adminContact,
  });

  /// Returns the current [AdminSettings], or null if never configured.
  Future<AdminSettings?> getAdminSettings();

  /// Records a failed login attempt and returns the updated [AdminSettings].
  Future<AdminSettings> recordFailedAttempt();

  /// Resets the failed attempt counter after a successful login.
  Future<void> resetFailedAttempts();

  /// Returns true if the account is currently locked out due to too many failed attempts.
  Future<bool> isLockedOut();

  /// Returns the remaining lockout duration, or Duration.zero if not locked.
  Future<Duration> getRemainingLockoutDuration();

  /// Clears the stored admin settings.
  Future<void> resetPassword();
}

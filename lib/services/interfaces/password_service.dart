import '../../domain/models/admin_settings.dart';

/// Abstract interface for the Password Service.
///
/// Handles admin password hashing, verification, and lockout logic.
abstract class PasswordService {
  /// Hashes [plainPassword] using SHA-256 and returns the hash string.
  String hashPassword(String plainPassword);

  /// Returns true if [plainPassword] matches the stored [storedHash].
  bool verifyPassword(String plainPassword, String storedHash);

  /// Sets a new admin password. Hashes it before storing.
  Future<void> setPassword(String plainPassword);

  /// Returns the current [AdminSettings], or null if never configured.
  Future<AdminSettings?> getAdminSettings();

  /// Records a failed login attempt and returns the updated [AdminSettings].
  Future<AdminSettings> recordFailedAttempt();

  /// Resets the failed attempt counter after a successful login.
  Future<void> resetFailedAttempts();

  /// Returns true if the account is currently locked out due to too many
  /// failed attempts.
  Future<bool> isLockedOut();

  /// Returns the remaining lockout duration, or Duration.zero if not locked.
  Future<Duration> getRemainingLockoutDuration();
  /// **New**: Clears the stored admin password, allowing the user to set a new one.
  Future<void> resetPassword();

}

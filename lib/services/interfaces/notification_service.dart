/// Service for managing notifications via platform channels.
abstract class NotificationService {
  /// Check if the user has granted notification permissions.
  Future<bool> hasPermission();

  /// Request notification permissions from the user.
  Future<bool> requestPermission();

  /// Open the system settings page for the app's notifications.
  Future<void> openSettings();

  /// Starts the persistent foreground service notification.
  Future<void> startForegroundService();

  /// Stops the persistent foreground service notification.
  Future<void> stopForegroundService();
}

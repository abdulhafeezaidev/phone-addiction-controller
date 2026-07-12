abstract class AccessibilityServiceManager {
  /// Returns true if the Accessibility Service is currently enabled
  /// in Android Settings.
  Future<bool> isServiceEnabled();

  /// Opens the Android Accessibility Settings screen so the user can
  /// manually grant permission.
  Future<void> openAccessibilitySettings();

  /// Sends a command to the running Accessibility Service.
  /// [command] is a string key (e.g. 'startFocusMode', 'stopFocusMode', 'updateAllowedApps').
  Future<bool> sendCommand(String command, {Map<String, dynamic>? args});

  /// Returns true if the service is actively blocking apps.
  Future<bool> isBlockingActive();

  /// Returns true if our app is the device's default home launcher.
  Future<bool> isDefaultLauncher();

  /// Opens the system "Choose default home app" settings screen.
  Future<void> openDefaultLauncherSettings();

  /// Opens a chooser dialog so the user can pick a different home launcher.
  Future<void> openLauncherChooser();

  /// Gets the native session details from SharedPreferences.
  Future<Map<String, dynamic>?> getNativeSessionDetails();

  /// Returns true if the app is the Device Owner.
  Future<bool> isDeviceOwner();
}

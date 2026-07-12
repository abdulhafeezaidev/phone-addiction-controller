/// Abstract interface for the App Blocking Service.
///
/// This service is responsible for determining which apps should be blocked
/// and communicating that list to the Accessibility Service.
abstract class AppBlockingService {
  /// Starts blocking all apps not on the allowed list.
  Future<void> startBlocking();

  /// Stops blocking apps (exits Focus Mode).
  Future<void> stopBlocking();

  /// Returns the current list of blocked package names.
  Future<List<String>> getBlockedPackages();

  /// Updates the allowed apps list that the service uses.
  Future<void> updateAllowedApps(List<String> packageNames);

  /// Returns true if blocking is currently active.
  bool get isBlocking;

  /// Stream of blocked events containing packageName, appName, and timestamp
  Stream<Map<String, dynamic>> get blockedEventsStream;
}

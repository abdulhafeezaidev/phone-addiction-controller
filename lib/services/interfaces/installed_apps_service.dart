import '../../domain/models/allowed_app.dart';

/// Abstract interface for querying installed applications on the device.
abstract class InstalledAppsService {
  /// Returns all user-installed applications on the device.
  /// System apps are excluded by default.
  Future<List<AllowedApp>> getInstalledApps({bool includeSystemApps = false});

  /// Returns the [AllowedApp] for a specific [packageName].
  /// Returns null if not found.
  Future<AllowedApp?> getAppInfo(String packageName);

  /// Returns true if the given [packageName] is installed.
  Future<bool> isAppInstalled(String packageName);
}

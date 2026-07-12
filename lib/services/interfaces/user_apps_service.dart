import '../../domain/models/allowed_app.dart';

abstract class UserAppsService {
  /// Returns launchable user-installed apps for the UI and Focus Mode control.
  Future<List<AllowedApp>> getUserApps({bool includeSystem = false});

  /// Returns single app information.
  Future<AllowedApp?> getAppInfo(String packageName);

  /// Checks if an app is installed.
  Future<bool> isAppInstalled(String packageName);

  /// Launches an app by package name.
  Future<void> launchApp(String packageName);
}

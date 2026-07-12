import '../../domain/models/allowed_app.dart';
import '../interfaces/installed_apps_service.dart';
import '../interfaces/user_apps_service.dart';
import 'user_apps_service_impl.dart';

class InstalledAppsServiceImpl implements InstalledAppsService {
  final UserAppsService _userAppsService = UserAppsServiceImpl();

  @override
  Future<List<AllowedApp>> getInstalledApps({
    bool includeSystemApps = false,
  }) async {
    return _userAppsService.getUserApps(includeSystem: includeSystemApps);
  }

  @override
  Future<AllowedApp?> getAppInfo(String packageName) async {
    return _userAppsService.getAppInfo(packageName);
  }

  @override
  Future<bool> isAppInstalled(String packageName) async {
    return _userAppsService.isAppInstalled(packageName);
  }
}

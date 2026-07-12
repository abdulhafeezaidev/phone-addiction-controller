import '../../domain/models/allowed_app.dart';

abstract class AllowedAppsRepository {
  List<AllowedApp> getAllowedApps();

  Stream<List<AllowedApp>> watchAllowedApps();

  Future<void> upsertAllowedApp(AllowedApp app);

  Future<void> removeAllowedApp(String packageName);

  Future<void> replaceAllowedApps(Iterable<AllowedApp> apps);
}
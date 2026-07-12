import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/allowed_app.dart';
import '../interfaces/allowed_apps_repository.dart';

class AllowedAppsRepositoryImpl implements AllowedAppsRepository {
  Box<AllowedApp> get _box => Hive.box<AllowedApp>(AppConstants.allowedAppsBox);

  List<AllowedApp> _normalize(Iterable<AllowedApp> apps) {
    final allowedApps = apps
        .where((app) => app.isAllowed)
        .map((app) => app.copyWith(isAllowed: true))
        .toList();
    allowedApps.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );
    return List.unmodifiable(allowedApps);
  }

  @override
  List<AllowedApp> getAllowedApps() {
    return _normalize(_box.values);
  }

  @override
  Stream<List<AllowedApp>> watchAllowedApps() async* {
    yield getAllowedApps();
    await for (final _ in _box.watch()) {
      yield getAllowedApps();
    }
  }

  @override
  Future<void> upsertAllowedApp(AllowedApp app) async {
    await _box.put(
      app.packageName,
      app.copyWith(isAllowed: true),
    );
  }

  @override
  Future<void> removeAllowedApp(String packageName) async {
    await _box.delete(packageName);
  }

  @override
  Future<void> replaceAllowedApps(Iterable<AllowedApp> apps) async {
    await _box.clear();
    for (final app in apps) {
      await _box.put(
        app.packageName,
        app.copyWith(isAllowed: true),
      );
    }
  }
}
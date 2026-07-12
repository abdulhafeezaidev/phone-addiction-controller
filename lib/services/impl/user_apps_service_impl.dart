import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../domain/models/allowed_app.dart';
import '../interfaces/user_apps_service.dart';

class UserAppsServiceImpl implements UserAppsService {
  static const MethodChannel _channel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  @override
  Future<List<AllowedApp>> getUserApps({bool includeSystem = false}) async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>(
        'getUserApps',
        {'includeSystem': includeSystem},
      );

      if (result == null) return <AllowedApp>[];

      return result.map<AllowedApp>((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final iconBytes = map['icon'] != null
            ? Uint8List.fromList(List<int>.from(map['icon'] as List))
            : null;

        return AllowedApp(
          packageName: map['packageName'] as String,
          appName: map['appName'] as String,
          icon: iconBytes,
        );
      }).toList();
    } on PlatformException catch (_) {
      return <AllowedApp>[];
    }
  }

  @override
  Future<AllowedApp?> getAppInfo(String packageName) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getAppInfo',
        {'packageName': packageName},
      );

      if (result == null) return null;

      final map = Map<String, dynamic>.from(result);
      final iconBytes = map['icon'] != null
          ? Uint8List.fromList(List<int>.from(map['icon'] as List))
          : null;

      return AllowedApp(
        packageName: map['packageName'] as String,
        appName: map['appName'] as String,
        icon: iconBytes,
      );
    } on PlatformException catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final bool? result = await _channel.invokeMethod<bool>(
        'isAppInstalled',
        {'packageName': packageName},
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  @override
  Future<void> launchApp(String packageName) async {
    try {
      await _channel.invokeMethod('launchApp', {'packageName': packageName});
    } on PlatformException catch (e) {
      throw Exception('Failed to launch $packageName: ${e.message}');
    }
  }
}

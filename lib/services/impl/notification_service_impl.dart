import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../interfaces/notification_service.dart';
import '../../core/utils/app_logger.dart';

class NotificationServiceImpl implements NotificationService {
  static const _channel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  @override
  Future<bool> hasPermission() async {
    return await Permission.notification.isGranted;
  }

  @override
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to open notification settings', error: e);
      // Fallback
      await openAppSettings();
    }
  }

  @override
  Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to start foreground service', error: e);
    }
  }

  @override
  Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to stop foreground service', error: e);
    }
  }
}

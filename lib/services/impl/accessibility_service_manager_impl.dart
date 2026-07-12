import 'package:flutter/services.dart';

import '../interfaces/accessibility_service_manager.dart';
import '../../core/utils/app_logger.dart';

class AccessibilityServiceManagerImpl implements AccessibilityServiceManager {
  static const _channel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');

  @override
  Future<bool> isServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isServiceEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to check accessibility service status', error: e);
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to open accessibility settings', error: e);
    }
  }

  @override
  Future<bool> sendCommand(String command, {Map<String, dynamic>? args}) async {
    try {
      switch (command) {
        case 'startFocusMode':
          await _channel.invokeMethod('startFocusMode');
          return true;
        case 'stopFocusMode':
          await _channel.invokeMethod('stopFocusMode');
          return true;
        case 'updateAllowedApps':
          await _channel.invokeMethod('updateAllowedApps', args);
          return true;
        case 'updateStrictMode':
          await _channel.invokeMethod('updateStrictMode', args);
          return true;
        case 'removeDeviceOwner':
          final result = await _channel.invokeMethod<bool>('removeDeviceOwner');
          return result ?? false;
        case 'setEmergencyOverrideActive':
          await _channel.invokeMethod('setEmergencyOverrideActive', args);
          return true;
        default:
          // Try sending as a generic method call
          try {
            final result = await _channel.invokeMethod(command, args);
            return result is bool ? result : true;
          } catch (_) {
            AppLogger.warning('Unknown command sent to accessibility service: $command');
            return false;
          }
      }
    } on PlatformException catch (e) {
      AppLogger.error('Failed to send command to accessibility service: $command', error: e);
      return false;
    }
  }

  @override
  Future<bool> isBlockingActive() async {
    try {
      final result = await _channel.invokeMethod<bool>('isFocusModeActive');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to check blocking status', error: e);
      return false;
    }
  }

  @override
  Future<bool> isDefaultLauncher() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDefaultLauncher');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to check default launcher status', error: e);
      return false;
    }
  }

  @override
  Future<void> openDefaultLauncherSettings() async {
    try {
      await _channel.invokeMethod('openDefaultLauncherSettings');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to open launcher settings', error: e);
    }
  }

  @override
  Future<void> openLauncherChooser() async {
    try {
      await _channel.invokeMethod('openLauncherChooser');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to open launcher chooser', error: e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getNativeSessionDetails() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getNativeSessionDetails');
      return result;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to get native session details', error: e);
      return null;
    }
  }

  @override
  Future<bool> isDeviceOwner() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceOwner');
      return result ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to check Device Owner status', error: e);
      return false;
    }
  }
}

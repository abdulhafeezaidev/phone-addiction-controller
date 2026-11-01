import 'package:flutter/services.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_logger.dart';

class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List? icon;

  const AppInfo({
    required this.packageName,
    required this.appName,
    this.icon,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfo &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}

class FocusSessionInfo {
  final bool isActive;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isScheduled;
  final String? routineId;
  final List<String> blockedPackages;
  final bool emergencyActive;

  const FocusSessionInfo({
    required this.isActive,
    this.startTime,
    this.endTime,
    this.isScheduled = false,
    this.routineId,
    this.blockedPackages = const [],
    this.emergencyActive = false,
  });

  Duration? get remaining {
    if (endTime == null) return null;
    final diff = endTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

class ProtectionState {
  final bool statusAvailable;
  final bool deviceAdminSupported;
  final bool deviceAdminActive;
  final bool accessibilityServiceEnabled;
  final bool guardEnabled;
  final bool deviceOwner;
  final bool profileOwner;
  final bool ownerUninstallBlocked;

  const ProtectionState({
    this.statusAvailable = false,
    this.deviceAdminSupported = false,
    this.deviceAdminActive = false,
    this.accessibilityServiceEnabled = false,
    this.guardEnabled = false,
    this.deviceOwner = false,
    this.profileOwner = false,
    this.ownerUninstallBlocked = false,
  });

  factory ProtectionState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProtectionState();
    return ProtectionState(
      statusAvailable: map['statusAvailable'] as bool? ?? false,
      deviceAdminSupported: map['deviceAdminSupported'] as bool? ?? false,
      deviceAdminActive: map['deviceAdminActive'] as bool? ?? false,
      accessibilityServiceEnabled:
          map['accessibilityServiceEnabled'] as bool? ?? false,
      guardEnabled: map['guardEnabled'] as bool? ?? false,
      deviceOwner: map['deviceOwner'] as bool? ?? false,
      profileOwner: map['profileOwner'] as bool? ?? false,
      ownerUninstallBlocked: map['ownerUninstallBlocked'] as bool? ?? false,
    );
  }

  bool get ownerMode => deviceOwner || profileOwner;
}

Future<bool> runAuthenticatedProtectionAction({
  required Future<bool> Function() authenticate,
  required Future<bool> Function() action,
}) async {
  if (!await authenticate()) return false;
  return action();
}

class NativeBridgeService {
  static const MethodChannel _channel =
      MethodChannel(AppConstants.accessibilityChannel);

  // ── Permissions & System ──────────────────────────────────────────────────

  Future<String> getStorageDirectory() async {
    try {
      final res = await _channel.invokeMethod<String>('getStorageDirectory');
      if (res != null && res.isNotEmpty) return res;
    } catch (e) {
      AppLogger.error('getStorageDirectory failed', error: e);
    }
    return '.';
  }

  Future<bool> isServiceEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('isServiceEnabled');
      return res ?? false;
    } catch (e) {
      AppLogger.error('isServiceEnabled failed', error: e);
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      AppLogger.error('openAccessibilitySettings failed', error: e);
    }
  }

  Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return res ?? false;
    } catch (e) {
      AppLogger.error('isBatteryOptimizationDisabled failed', error: e);
      return false;
    }
  }

  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      AppLogger.error('openBatteryOptimizationSettings failed', error: e);
    }
  }

  Future<bool> areNotificationsEnabled() async {
    try {
      final res = await _channel.invokeMethod<bool>('areNotificationsEnabled');
      return res ?? true;
    } catch (e) {
      AppLogger.error('areNotificationsEnabled failed', error: e);
      return true;
    }
  }

  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (e) {
      AppLogger.error('openNotificationSettings failed', error: e);
    }
  }

  // ── Session Control ───────────────────────────────────────────────────────

  Future<void> startSession({
    required DateTime endTime,
    required List<String> packages,
  }) async {
    try {
      await _channel.invokeMethod('startSession', {
        'endTimeMs': endTime.millisecondsSinceEpoch,
        'packages': packages,
      });
    } catch (e) {
      AppLogger.error('startSession failed', error: e);
      rethrow;
    }
  }

  Future<void> stopSession() async {
    try {
      await _channel.invokeMethod('stopSession');
    } catch (e) {
      AppLogger.error('stopSession failed', error: e);
    }
  }

  Future<FocusSessionInfo> getSession() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getSession');
      if (raw == null) return const FocusSessionInfo(isActive: false);

      final isActive = raw['isActive'] as bool? ?? false;
      final startMs = raw['startTimeMs'] as int? ?? 0;
      final endMs = raw['endTimeMs'] as int? ?? 0;
      final isScheduled = raw['isScheduled'] as bool? ?? false;
      final routineId = raw['routineId'] as String?;
      final blocked =
          List<String>.from(raw['blockedPackages'] as List? ?? const []);
      final emergencyActive = raw['emergencyActive'] as bool? ?? false;

      return FocusSessionInfo(
        isActive: isActive,
        startTime:
            startMs > 0 ? DateTime.fromMillisecondsSinceEpoch(startMs) : null,
        endTime: endMs > 0 ? DateTime.fromMillisecondsSinceEpoch(endMs) : null,
        isScheduled: isScheduled,
        routineId: routineId,
        blockedPackages: blocked,
        emergencyActive: emergencyActive,
      );
    } catch (e) {
      AppLogger.error('getSession failed', error: e);
      return const FocusSessionInfo(isActive: false);
    }
  }

  Future<List<String>> getBlockedPackages() async {
    try {
      final res = await _channel.invokeListMethod<String>('getBlockedPackages');
      return res ?? const [];
    } catch (e) {
      AppLogger.error('getBlockedPackages failed', error: e);
      return const [];
    }
  }

  Future<void> setEmergencyOverrideActive({
    required bool active,
    required int expirationTimeMs,
  }) async {
    try {
      await _channel.invokeMethod('setEmergencyOverrideActive', {
        'active': active,
        'expirationTime': expirationTimeMs,
      });
    } catch (e) {
      AppLogger.error('setEmergencyOverrideActive failed', error: e);
    }
  }

  // ── Installed Apps ────────────────────────────────────────────────────────

  Future<List<AppInfo>> getInstalledApps() async {
    try {
      final rawList = await _channel
          .invokeListMethod<Map<dynamic, dynamic>>('getInstalledApps');
      if (rawList == null) return const [];

      return rawList
          .map((map) {
            return AppInfo(
              packageName: map['packageName'] as String? ?? '',
              appName: map['appName'] as String? ?? '',
              icon: map['icon'] as Uint8List?,
            );
          })
          .where((app) => app.packageName.isNotEmpty && app.appName.isNotEmpty)
          .toList();
    } catch (e) {
      AppLogger.error('getInstalledApps failed', error: e);
      return const [];
    }
  }

  // ── Schedule ──────────────────────────────────────────────────────────────

  Future<void> scheduleRoutine(String routineJson) async {
    try {
      await _channel
          .invokeMethod('scheduleRoutine', {'routineJson': routineJson});
    } catch (e) {
      AppLogger.error('scheduleRoutine failed', error: e);
    }
  }

  Future<void> cancelRoutine(String routineId) async {
    try {
      await _channel.invokeMethod('cancelRoutine', {'routineId': routineId});
    } catch (e) {
      AppLogger.error('cancelRoutine failed', error: e);
    }
  }

  Future<bool> isAnyRoutineActive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAnyRoutineActive');
      return res ?? false;
    } catch (e) {
      AppLogger.error('isAnyRoutineActive failed', error: e);
      return false;
    }
  }

  // ── Tamper Protection & Admin Control ─────────────────────────────────────

  Future<bool> enableProtectionGuard() async {
    try {
      return await _channel.invokeMethod<bool>('enableProtectionGuard') ??
          false;
    } catch (e) {
      AppLogger.error('enableProtectionGuard failed', error: e);
      rethrow;
    }
  }

  Future<bool> disableProtectionGuardAfterAuthentication() async {
    try {
      return await _channel.invokeMethod<bool>(
            'disableProtectionGuardAfterAuthentication',
          ) ??
          false;
    } catch (e) {
      AppLogger.error('disableProtectionGuardAfterAuthentication failed',
          error: e);
      rethrow;
    }
  }

  Future<ProtectionState> getProtectionState() async {
    try {
      final map =
          await _channel.invokeMapMethod<String, dynamic>('getProtectionState');
      return ProtectionState.fromMap(map);
    } catch (e) {
      AppLogger.error('getProtectionState failed', error: e);
      return const ProtectionState();
    }
  }

  Future<bool> isDeviceAdminActive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isDeviceAdminActive');
      return res ?? false;
    } catch (e) {
      AppLogger.error('isDeviceAdminActive failed', error: e);
      return false;
    }
  }

  Future<bool> requestDeviceAdmin() async {
    try {
      return await _channel.invokeMethod<bool>('requestDeviceAdmin') ?? false;
    } catch (e) {
      AppLogger.error('requestDeviceAdmin failed', error: e);
      rethrow;
    }
  }

  Future<bool> speakLumi(String text) async {
    try {
      return await _channel.invokeMethod<bool>(
            'speakLumi',
            <String, dynamic>{'text': text},
          ) ??
          false;
    } catch (e) {
      AppLogger.error('speakLumi failed', error: e);
      rethrow;
    }
  }

  Future<bool> stopSpeakingLumi() async {
    try {
      return await _channel.invokeMethod<bool>('stopSpeakingLumi') ?? false;
    } catch (e) {
      AppLogger.error('stopSpeakingLumi failed', error: e);
      return false;
    }
  }

  Future<bool> playSoundscape(String token) async {
    try {
      return await _channel.invokeMethod<bool>(
            'playSoundscape',
            <String, dynamic>{'token': token},
          ) ??
          false;
    } catch (e) {
      AppLogger.error('playSoundscape failed', error: e);
      return false;
    }
  }

  Future<bool> startAmbientSoundscape(String scene) async {
    try {
      return await _channel.invokeMethod<bool>(
            'startAmbientSoundscape',
            <String, dynamic>{'scene': scene},
          ) ??
          false;
    } catch (e) {
      AppLogger.error('startAmbientSoundscape failed', error: e);
      return false;
    }
  }

  Future<bool> stopAmbientSoundscape() async {
    try {
      return await _channel.invokeMethod<bool>('stopAmbientSoundscape') ?? false;
    } catch (e) {
      AppLogger.error('stopAmbientSoundscape failed', error: e);
      return false;
    }
  }

  Future<bool> deactivateDeviceAdminAfterAuthentication() async {
    try {
      return await _channel.invokeMethod<bool>(
            'deactivateDeviceAdminAfterAuthentication',
          ) ??
          false;
    } catch (e) {
      AppLogger.error('deactivateDeviceAdminAfterAuthentication failed',
          error: e);
      rethrow;
    }
  }

  Future<bool> setOwnerUninstallBlocked() async {
    try {
      return await _channel.invokeMethod<bool>(
            'setOwnerUninstallBlocked',
            {'blocked': true},
          ) ??
          false;
    } catch (e) {
      AppLogger.error('setOwnerUninstallBlocked failed', error: e);
      rethrow;
    }
  }

  Future<bool> disableOwnerUninstallBlockedAfterAuthentication() async {
    try {
      return await _channel.invokeMethod<bool>(
            'disableOwnerUninstallBlockedAfterAuthentication',
          ) ??
          false;
    } catch (e) {
      AppLogger.error('disableOwnerUninstallBlockedAfterAuthentication failed',
          error: e);
      rethrow;
    }
  }

  Future<bool> prepareUninstall() async {
    try {
      final res = await _channel.invokeMethod<bool>('prepareUninstall');
      return res ?? false;
    } catch (e) {
      AppLogger.error('prepareUninstall failed', error: e);
      rethrow;
    }
  }
}

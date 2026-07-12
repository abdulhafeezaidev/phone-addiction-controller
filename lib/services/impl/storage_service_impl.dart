import 'package:hive_flutter/hive_flutter.dart';

import '../interfaces/storage_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';
import '../../domain/models/allowed_app.dart';
import '../../domain/models/admin_settings.dart';
import '../../domain/models/focus_session.dart';
import '../../domain/models/focus_session_snapshot.dart';
import '../../domain/models/emergency_override_state.dart';
import '../../domain/models/routine.dart';
import '../../domain/models/app_settings.dart';

/// Concrete implementation of [StorageService] backed by Hive.
///
/// Features try-catch fallback handling for typed Hive boxes to prevent
/// generic mismatch runtime errors from ever crashing Riverpod providers or UI.
class StorageServiceImpl implements StorageService {
  Box _getBox(String boxName) {
    if (!Hive.isBoxOpen(boxName)) {
      AppLogger.warning('Box "$boxName" is not open');
    }
    try {
      return Hive.box(boxName);
    } catch (_) {
      switch (boxName) {
        case AppConstants.focusSessionBox:
          return Hive.box<FocusSession>(boxName);
        case AppConstants.allowedAppsBox:
          return Hive.box<AllowedApp>(boxName);
        case AppConstants.routinesBox:
          return Hive.box<Routine>(boxName);
        case AppConstants.adminSettingsBox:
          return Hive.box<AdminSettings>(boxName);
        case AppConstants.appSettingsBox:
          return Hive.box<AppSettings>(boxName);
        case AppConstants.focusSessionSnapshotBox:
          return Hive.box<FocusSessionSnapshot>(boxName);
        case AppConstants.emergencyOverrideBox:
          return Hive.box<EmergencyOverrideState>(boxName);
        default:
          return Hive.box<dynamic>(boxName);
      }
    }
  }

  @override
  Future<void> put<T>(String boxName, String key, T value) async {
    try {
      final box = _getBox(boxName);
      await box.put(key, value);
    } catch (e) {
      AppLogger.error('Failed to put key "$key" in box "$boxName"', error: e);
    }
  }

  @override
  T? get<T>(String boxName, String key, {T? defaultValue}) {
    if (!Hive.isBoxOpen(boxName)) return defaultValue;
    try {
      final box = _getBox(boxName);
      final val = box.get(key, defaultValue: defaultValue);
      if (val is T) return val;
      return defaultValue;
    } catch (e) {
      AppLogger.error('Failed to get key "$key" from box "$boxName"', error: e);
      return defaultValue;
    }
  }

  @override
  Future<void> delete(String boxName, String key) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      final box = _getBox(boxName);
      await box.delete(key);
    } catch (e) {
      AppLogger.error('Failed to delete key "$key" from box "$boxName"', error: e);
    }
  }

  @override
  List<T> getAll<T>(String boxName) {
    if (!Hive.isBoxOpen(boxName)) return <T>[];
    try {
      final box = _getBox(boxName);
      return box.values.whereType<T>().toList();
    } catch (e) {
      AppLogger.error('Failed to getAll from box "$boxName"', error: e);
      return <T>[];
    }
  }

  @override
  Future<void> clearBox(String boxName) async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      final box = _getBox(boxName);
      await box.clear();
    } catch (e) {
      AppLogger.error('Failed to clear box "$boxName"', error: e);
    }
  }

  @override
  bool containsKey(String boxName, String key) {
    if (!Hive.isBoxOpen(boxName)) return false;
    try {
      final box = _getBox(boxName);
      return box.containsKey(key);
    } catch (_) {
      return false;
    }
  }
}

import 'package:hive/hive.dart';

import '../../domain/models/admin_settings.dart';
import '../../domain/models/emergency_override_state.dart';
import '../../domain/models/routine.dart';
import '../../domain/models/time_slot.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

/// Centralized Hive box management with safe initialization and error recovery.
class HiveBoxes {
  HiveBoxes._();

  /// Opens all Hive boxes required by the app.
  static Future<void> openAllBoxes() async {
    _registerAdapters();

    await _openBoxSafely<Routine>(AppConstants.routinesBox);
    await _openBoxSafely<AdminSettings>(AppConstants.adminSettingsBox);
    await _openBoxSafely<EmergencyOverrideState>(AppConstants.emergencyOverrideBox);
    await _openBoxSafely<dynamic>(AppConstants.settingsBox);
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(AppConstants.routineTypeId)) {
      Hive.registerAdapter(RoutineAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.adminSettingsTypeId)) {
      Hive.registerAdapter(AdminSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.timeSlotTypeId)) {
      Hive.registerAdapter(TimeSlotAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.emergencyOverrideTypeId)) {
      Hive.registerAdapter(EmergencyOverrideStateAdapter());
    }
  }

  /// Opens a Hive box safely. Checks if already open first to avoid HiveError.
  static Future<Box<T>> _openBoxSafely<T>(String boxName) async {
    try {
      if (Hive.isBoxOpen(boxName)) {
        return Hive.box<T>(boxName);
      }
      return await Hive.openBox<T>(boxName);
    } catch (e) {
      AppLogger.error('Failed to open box "$boxName", attempting recovery', error: e);
      try {
        await Hive.deleteBoxFromDisk(boxName);
        return await Hive.openBox<T>(boxName);
      } catch (e2) {
        AppLogger.error('Recovery failed for box "$boxName"', error: e2);
        rethrow;
      }
    }
  }
}

import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/models/allowed_app.dart';
import '../../domain/models/admin_settings.dart';
import '../../domain/models/focus_session.dart';
import '../../domain/models/focus_session_snapshot.dart';
import '../../domain/models/emergency_override_state.dart';
import '../../domain/models/routine.dart';
import '../../domain/models/time_slot.dart';
import '../../domain/models/app_settings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

/// Centralized Hive box management with error recovery.
class HiveBoxes {
  HiveBoxes._();

  /// Opens all Hive boxes required by the app.
  /// If a box is corrupted or has invalid schema, deletes and recreates it.
  static Future<void> openAllBoxes() async {
    // Register adapters (check prevents duplicates)
    _registerAdapters();

    // Open boxes with safe recovery
    await _openBoxSafely<FocusSession>(AppConstants.focusSessionBox);
    await _openBoxSafely<AllowedApp>(AppConstants.allowedAppsBox);
    await _openBoxSafely<Routine>(AppConstants.routinesBox);
    await _openBoxSafely<AdminSettings>(AppConstants.adminSettingsBox);
    await _openBoxSafely<AppSettings>(AppConstants.appSettingsBox);
    await _openBoxSafely<FocusSessionSnapshot>(AppConstants.focusSessionSnapshotBox);
    await _openBoxSafely<EmergencyOverrideState>(AppConstants.emergencyOverrideBox);
    await _openBoxSafely<dynamic>(AppConstants.settingsBox);
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(AppConstants.focusSessionTypeId)) {
      Hive.registerAdapter(FocusSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.allowedAppTypeId)) {
      Hive.registerAdapter(AllowedAppAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.routineTypeId)) {
      Hive.registerAdapter(RoutineAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.adminSettingsTypeId)) {
      Hive.registerAdapter(AdminSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.appSettingsTypeId)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.sessionTriggerTypeId)) {
      Hive.registerAdapter(SessionTriggerTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.sessionStopTypeId)) {
      Hive.registerAdapter(SessionStopTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.timeSlotTypeId)) {
      Hive.registerAdapter(TimeSlotAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.focusSessionSnapshotTypeId)) {
      Hive.registerAdapter(FocusSessionSnapshotAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.emergencyOverrideTypeId)) {
      Hive.registerAdapter(EmergencyOverrideStateAdapter());
    }
    if (!Hive.isAdapterRegistered(200)) {
      Hive.registerAdapter(DurationAdapter());
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
      AppLogger.error('Failed to open box "$boxName", attempting disk recovery',
          error: e);
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

class DurationAdapter extends TypeAdapter<Duration> {
  @override
  final int typeId = 200;

  @override
  Duration read(BinaryReader reader) {
    return Duration(microseconds: reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Duration obj) {
    writer.writeInt(obj.inMicroseconds);
  }
}

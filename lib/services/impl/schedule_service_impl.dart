import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../domain/models/routine.dart';
import '../../domain/models/time_slot.dart';
import '../interfaces/schedule_service.dart';
import '../interfaces/storage_service.dart';
import '../native_bridge_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class ScheduleServiceImpl implements ScheduleService {
  ScheduleServiceImpl({
    required this.storageService,
    required this.nativeBridgeService,
  });

  final StorageService storageService;
  final NativeBridgeService nativeBridgeService;
  final _uuid = const Uuid();

  @override
  Future<List<Routine>> getRoutines() async {
    final routines = storageService.getAll<Routine>(AppConstants.routinesBox);
    return routines.toList();
  }

  @override
  Future<Routine?> getRoutine(String id) async {
    return storageService.get<Routine>(AppConstants.routinesBox, id);
  }

  @override
  Future<Routine> addRoutine({
    required List<int> weekdays,
    required DateTime startTime,
    required DateTime endTime,
    required String label,
    bool enabled = true,
    List<TimeSlot>? slots,
  }) async {
    final routine = Routine(
      id: _uuid.v4(),
      weekdays: weekdays,
      startTime: startTime,
      endTime: endTime,
      label: label,
      enabled: enabled,
      slots: slots,
    );

    await storageService.put(
      AppConstants.routinesBox,
      routine.id,
      routine,
    );

    await _syncWithNative(routine);
    return routine;
  }

  @override
  Future<Routine> updateRoutine(Routine routine) async {
    await storageService.put(
      AppConstants.routinesBox,
      routine.id,
      routine,
    );

    await _syncWithNative(routine);
    return routine;
  }

  @override
  Future<void> deleteRoutine(String id) async {
    await storageService.delete(AppConstants.routinesBox, id);
    await cancelRoutine(id);
  }

  @override
  Future<void> toggleRoutine(String id, bool enabled) async {
    final routine = await getRoutine(id);
    if (routine != null) {
      final updated = routine.copyWith(enabled: enabled);
      await updateRoutine(updated);
    }
  }

  @override
  Future<bool> hasOverlappingRoutines(Routine routine) async {
    final routines = await getRoutines();

    final startMinutes = routine.startTime.hour * 60 + routine.startTime.minute;
    final endMinutes = routine.endTime.hour * 60 + routine.endTime.minute;
    final isOvernight = startMinutes >= endMinutes;

    for (final existing in routines) {
      if (existing.id == routine.id || !existing.enabled) continue;

      final hasSharedDays = routine.weekdays.any((d) => existing.weekdays.contains(d));
      if (!hasSharedDays) continue;

      final eStartMinutes = existing.startTime.hour * 60 + existing.startTime.minute;
      final eEndMinutes = existing.endTime.hour * 60 + existing.endTime.minute;
      final eIsOvernight = eStartMinutes >= eEndMinutes;

      if (!isOvernight && !eIsOvernight) {
        if (startMinutes < eEndMinutes && endMinutes > eStartMinutes) return true;
      } else {
        return true;
      }
    }
    return false;
  }

  @override
  Future<void> scheduleAllRoutines(List<Routine> routines) async {
    for (final r in routines) {
      if (r.enabled) {
        await _syncWithNative(r);
      }
    }
  }

  @override
  Future<void> cancelRoutine(String routineId) async {
    try {
      await nativeBridgeService.cancelRoutine(routineId);
    } catch (e) {
      AppLogger.error('Failed to cancel routine in native layer', error: e);
    }
  }

  @override
  Future<void> cancelAllRoutines() async {
    final routines = await getRoutines();
    for (final r in routines) {
      await cancelRoutine(r.id);
    }
  }

  @override
  Future<bool> isAnyRoutineActive() async {
    return await nativeBridgeService.isAnyRoutineActive();
  }

  @override
  Future<Routine?> getNextRoutine() async {
    final routines = await getRoutines();
    final enabled = routines.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return null;
    return enabled.first;
  }

  Future<void> _syncWithNative(Routine routine) async {
    try {
      final savedList = storageService.get<List<dynamic>>(
        AppConstants.settingsBox,
        AppConstants.lastBlockedPackagesKey,
      );
      final savedPkgs = savedList
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          const <String>[];
      final blockedPkgs = savedPkgs.isNotEmpty
          ? savedPkgs
          : await nativeBridgeService.getBlockedPackages();

      final jsonStr = jsonEncode({
        'id': routine.id,
        'label': routine.label,
        'weekdays': routine.weekdays,
        'startHour': routine.startTime.hour,
        'startMinute': routine.startTime.minute,
        'endHour': routine.endTime.hour,
        'endMinute': routine.endTime.minute,
        'enabled': routine.enabled,
        'slots': routine.slots.map((s) => s.toJson()).toList(),
        'blockedPackages': blockedPkgs,
      });

      await nativeBridgeService.scheduleRoutine(jsonStr);
    } catch (e) {
      AppLogger.error('Failed to sync routine with native layer', error: e);
    }
  }
}

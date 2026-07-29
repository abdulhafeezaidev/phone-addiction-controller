import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/routine.dart';
import '../../domain/models/time_slot.dart';
import '../interfaces/schedule_service.dart';
import '../interfaces/storage_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_logger.dart';

class ScheduleServiceImpl implements ScheduleService {
  ScheduleServiceImpl({required this.storageService});

  final StorageService storageService;
  
  static const _channel =
      MethodChannel('com.personal.phone_addiction_controller/accessibility');
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

    for (final existing in routines) {
      // Only skip self (when editing)
      if (existing.id == routine.id) continue;

      // Check for shared days
      final hasSharedDays = routine.weekdays.any((d) => existing.weekdays.contains(d));
      if (!hasSharedDays) continue;

      // Check all slots of new routine against all slots of existing routine
      for (final newSlot in routine.slots) {
        for (final existingSlot in existing.slots) {
          if (_slotsOverlap(newSlot, existingSlot)) return true;
        }
      }
    }
    return false;
  }

  bool _slotsOverlap(TimeSlot a, TimeSlot b) {
    final aStart = a.startHour * 60 + a.startMinute;
    final aEnd = a.endHour * 60 + a.endMinute;
    final bStart = b.startHour * 60 + b.startMinute;
    final bEnd = b.endHour * 60 + b.endMinute;

    final aOvernight = aStart >= aEnd;
    final bOvernight = bStart >= bEnd;

    if (!aOvernight && !bOvernight) {
      // Both same-day: standard interval overlap
      return aStart < bEnd && aEnd > bStart;
    } else if (aOvernight && !bOvernight) {
      // a wraps midnight, b is same-day
      return bStart < aEnd || bEnd > aStart;
    } else if (!aOvernight && bOvernight) {
      // b wraps midnight, a is same-day
      return aStart < bEnd || aEnd > bStart;
    } else {
      // Both overnight: always overlap
      return true;
    }
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
      await _channel.invokeMethod('cancelRoutine', {'routineId': routineId});
    } on PlatformException catch (e) {
      AppLogger.error('Failed to cancel routine in native layer', error: e);
    }
  }

  @override
  Future<void> cancelAllRoutines() async {
    try {
      await _channel.invokeMethod('cancelAllRoutines');
    } on PlatformException catch (e) {
      AppLogger.error('Failed to cancel all routines in native layer', error: e);
    }
  }

  @override
  Future<bool> isAnyRoutineActive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isAnyRoutineActive');
      return res ?? false;
    } on PlatformException catch (e) {
      AppLogger.error('Failed to check if any routine is active', error: e);
      return false;
    }
  }

  @override
  Future<Routine?> getNextRoutine() async {
    // Return null or basic implementation
    return null; 
  }

  Future<void> _syncWithNative(Routine routine) async {
    try {
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
      });

      await _channel.invokeMethod('scheduleRoutine', {'routineJson': jsonStr});
    } on PlatformException catch (e) {
      AppLogger.error('Failed to sync routine with native layer', error: e);
    }
  }
}

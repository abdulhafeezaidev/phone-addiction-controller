import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/routine.dart';
import 'service_providers.dart';

/// Provider for the list of all routines.
final routinesProvider = StateNotifierProvider<RoutinesNotifier, AsyncValue<List<Routine>>>((ref) {
  return RoutinesNotifier(ref);
});

class RoutinesNotifier extends StateNotifier<AsyncValue<List<Routine>>> {
  RoutinesNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadRoutines();
  }

  final Ref ref;

  Future<void> loadRoutines() async {
    try {
      state = const AsyncValue.loading();
      final scheduleService = ref.read(scheduleServiceProvider);
      final routines = await scheduleService.getRoutines();
      // Sort by start time
      routines.sort((a, b) {
        final aTime = a.startTime.hour * 60 + a.startTime.minute;
        final bTime = b.startTime.hour * 60 + b.startTime.minute;
        return aTime.compareTo(bTime);
      });
      state = AsyncValue.data(routines);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addRoutine(Routine routine) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.addRoutine(
        weekdays: routine.weekdays,
        startTime: routine.startTime,
        endTime: routine.endTime,
        label: routine.label,
        enabled: routine.enabled,
        slots: routine.slots,
      );
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateRoutine(Routine routine) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.updateRoutine(routine);
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleRoutine(String id, bool enabled) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.toggleRoutine(id, enabled);
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRoutine(String id) async {
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      await scheduleService.deleteRoutine(id);
      await loadRoutines();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

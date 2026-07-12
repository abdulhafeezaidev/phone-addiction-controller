import '../../domain/models/routine.dart';
import '../../domain/models/time_slot.dart';

/// Abstract interface for the Schedule Service.
///
/// Manages automatic Focus Mode activation based on user-defined routines.
abstract class ScheduleService {
  /// Returns all configured routines.
  Future<List<Routine>> getRoutines();

  /// Gets a specific routine by ID.
  Future<Routine?> getRoutine(String id);

  /// Adds a new routine.
  Future<Routine> addRoutine({
    required List<int> weekdays,
    required DateTime startTime,
    required DateTime endTime,
    required String label,
    bool enabled = true,
    List<TimeSlot>? slots,
  });

  /// Updates an existing routine.
  Future<Routine> updateRoutine(Routine routine);

  /// Deletes a routine by ID.
  Future<void> deleteRoutine(String id);

  /// Toggles routine enabled state.
  Future<void> toggleRoutine(String id, bool enabled);

  /// Returns true if the routine overlaps with any existing routine.
  Future<bool> hasOverlappingRoutines(Routine routine);

  /// Schedules all enabled routines with the Android alarm manager.
  Future<void> scheduleAllRoutines(List<Routine> routines);

  /// Cancels a specific routine schedule.
  Future<void> cancelRoutine(String routineId);

  /// Cancels all scheduled routines.
  Future<void> cancelAllRoutines();

  /// Returns true if any routine is currently active at this moment.
  Future<bool> isAnyRoutineActive();

  /// Returns the next upcoming routine, if any.
  Future<Routine?> getNextRoutine();
}

import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';
import 'time_slot.dart';

part 'routine.g.dart';

/// Represents a scheduled Focus Mode routine with support for multiple custom daily time slots.
@HiveType(typeId: AppConstants.routineTypeId)
// ignore: must_be_immutable
class Routine extends HiveObject with EquatableMixin {
  /// Selected weekdays (0 = Monday, 6 = Sunday).
  @HiveField(0)
  List<int> weekdays;

  /// Legacy primary start time (kept for backward compatibility).
  @HiveField(1)
  DateTime startTime;

  /// Legacy primary end time (kept for backward compatibility).
  @HiveField(2)
  DateTime endTime;

  /// Unique identifier.
  @HiveField(3)
  String id;

  /// Human-readable label for this routine.
  @HiveField(4)
  String label;

  /// Whether this routine is currently active.
  @HiveField(5)
  bool enabled;

  /// List of custom time slots for this routine (e.g. 11:00 PM – 9:00 AM, 10:00 AM – 2:00 PM).
  @HiveField(6)
  List<TimeSlot> slots;

  Routine({
    required this.id,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    this.label = '',
    this.enabled = true,
    List<TimeSlot>? slots,
  }) : slots = (slots != null && slots.isNotEmpty)
            ? slots
            : [
                TimeSlot(
                  startHour: startTime.hour,
                  startMinute: startTime.minute,
                  endHour: endTime.hour,
                  endMinute: endTime.minute,
                )
              ];

  /// Checks whether this routine is active at the given [now] timestamp.
  bool isCurrentlyActive(DateTime now) {
    if (!enabled) return false;
    final currentWeekday = (now.weekday - 1); // 0 = Mon, 6 = Sun
    if (!weekdays.contains(currentWeekday)) return false;

    for (final slot in slots) {
      if (slot.isCurrentlyActive(now)) {
        return true;
      }
    }
    return false;
  }

  Routine copyWith({
    String? id,
    List<int>? weekdays,
    DateTime? startTime,
    DateTime? endTime,
    String? label,
    bool? enabled,
    List<TimeSlot>? slots,
  }) {
    return Routine(
      id: id ?? this.id,
      weekdays: weekdays ?? this.weekdays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      slots: slots ?? this.slots,
    );
  }

  static const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  List<Object?> get props => [id, weekdays, startTime, endTime, label, enabled, slots];
}

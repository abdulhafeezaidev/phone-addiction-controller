import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'time_slot.g.dart';

/// Represents a time window within a routine (e.g. 11:00 PM to 09:00 AM).
@HiveType(typeId: AppConstants.timeSlotTypeId)
// ignore: must_be_immutable
class TimeSlot extends HiveObject with EquatableMixin {
  /// Start hour (0 - 23)
  @HiveField(0)
  int startHour;

  /// Start minute (0 - 59)
  @HiveField(1)
  int startMinute;

  /// End hour (0 - 23)
  @HiveField(2)
  int endHour;

  /// End minute (0 - 59)
  @HiveField(3)
  int endMinute;

  TimeSlot({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
  });

  /// Helper to check if a specific [DateTime] falls within this slot.
  /// Correctly handles overnight time slots (e.g. 23:00 to 09:00).
  bool isCurrentlyActive(DateTime now) {
    final startMins = startHour * 60 + startMinute;
    final endMins = endHour * 60 + endMinute;
    final currentMins = now.hour * 60 + now.minute;

    if (startMins < endMins) {
      // Daytime slot (e.g. 10:00 AM to 2:00 PM)
      return currentMins >= startMins && currentMins < endMins;
    } else if (startMins > endMins) {
      // Overnight slot (e.g. 11:00 PM to 9:00 AM)
      return currentMins >= startMins || currentMins < endMins;
    } else {
      // 24-hour slot
      return true;
    }
  }

  /// Formats the slot into human readable string e.g. "11:00 PM – 9:00 AM"
  String format(BuildContext context) {
    final sTime = TimeOfDay(hour: startHour, minute: startMinute).format(context);
    final eTime = TimeOfDay(hour: endHour, minute: endMinute).format(context);
    return '$sTime – $eTime';
  }

  Map<String, dynamic> toJson() {
    return {
      'startHour': startHour,
      'startMinute': startMinute,
      'endHour': endHour,
      'endMinute': endMinute,
    };
  }

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startHour: json['startHour'] as int? ?? 0,
      startMinute: json['startMinute'] as int? ?? 0,
      endHour: json['endHour'] as int? ?? 0,
      endMinute: json['endMinute'] as int? ?? 0,
    );
  }

  TimeSlot copyWith({
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
  }) {
    return TimeSlot(
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  @override
  List<Object?> get props => [startHour, startMinute, endHour, endMinute];
}

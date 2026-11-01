import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import '../../../core/constants/app_constants.dart';

part 'emergency_override_state.g.dart';

@HiveType(typeId: AppConstants.emergencyOverrideTypeId)
// ignore: must_be_immutable
class EmergencyOverrideState extends HiveObject with EquatableMixin {
  @HiveField(0)
  final bool isInReflection;

  @HiveField(1)
  final DateTime? reflectionStartTime;

  @HiveField(2)
  final bool isOverrideActive;

  @HiveField(3)
  final DateTime? overrideStartTime;

  @HiveField(4)
  final DateTime? lastActivationTime;

  @HiveField(5)
  final List<DateTime> activationHistory;

  EmergencyOverrideState({
    this.isInReflection = false,
    this.reflectionStartTime,
    this.isOverrideActive = false,
    this.overrideStartTime,
    this.lastActivationTime,
    List<DateTime>? activationHistory,
  }) : activationHistory = activationHistory ?? const [];

  EmergencyOverrideState copyWith({
    bool? isInReflection,
    DateTime? reflectionStartTime,
    bool? isOverrideActive,
    DateTime? overrideStartTime,
    DateTime? lastActivationTime,
    List<DateTime>? activationHistory,
  }) {
    return EmergencyOverrideState(
      isInReflection: isInReflection ?? this.isInReflection,
      reflectionStartTime: reflectionStartTime ?? this.reflectionStartTime,
      isOverrideActive: isOverrideActive ?? this.isOverrideActive,
      overrideStartTime: overrideStartTime ?? this.overrideStartTime,
      lastActivationTime: lastActivationTime ?? this.lastActivationTime,
      activationHistory: activationHistory ?? this.activationHistory,
    );
  }

  @override
  List<Object?> get props => [
        isInReflection,
        reflectionStartTime,
        isOverrideActive,
        overrideStartTime,
        lastActivationTime,
        activationHistory,
      ];
}

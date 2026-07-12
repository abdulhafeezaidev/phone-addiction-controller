// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'emergency_override_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EmergencyOverrideStateAdapter
    extends TypeAdapter<EmergencyOverrideState> {
  @override
  final int typeId = 9;

  @override
  EmergencyOverrideState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmergencyOverrideState(
      isInReflection: fields[0] as bool,
      reflectionStartTime: fields[1] as DateTime?,
      isOverrideActive: fields[2] as bool,
      overrideStartTime: fields[3] as DateTime?,
      lastActivationTime: fields[4] as DateTime?,
      activationHistory: (fields[5] as List?)?.cast<DateTime>(),
    );
  }

  @override
  void write(BinaryWriter writer, EmergencyOverrideState obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.isInReflection)
      ..writeByte(1)
      ..write(obj.reflectionStartTime)
      ..writeByte(2)
      ..write(obj.isOverrideActive)
      ..writeByte(3)
      ..write(obj.overrideStartTime)
      ..writeByte(4)
      ..write(obj.lastActivationTime)
      ..writeByte(5)
      ..write(obj.activationHistory);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmergencyOverrideStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

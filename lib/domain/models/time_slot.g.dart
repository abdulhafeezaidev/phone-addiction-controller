// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'time_slot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TimeSlotAdapter extends TypeAdapter<TimeSlot> {
  @override
  final int typeId = 7;

  @override
  TimeSlot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TimeSlot(
      startHour: fields[0] as int,
      startMinute: fields[1] as int,
      endHour: fields[2] as int,
      endMinute: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TimeSlot obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.startHour)
      ..writeByte(1)
      ..write(obj.startMinute)
      ..writeByte(2)
      ..write(obj.endHour)
      ..writeByte(3)
      ..write(obj.endMinute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimeSlotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

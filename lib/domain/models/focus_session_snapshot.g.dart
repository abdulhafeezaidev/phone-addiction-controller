// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session_snapshot.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FocusSessionSnapshotAdapter extends TypeAdapter<FocusSessionSnapshot> {
  @override
  final int typeId = 8;

  @override
  FocusSessionSnapshot read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusSessionSnapshot(
      sessionId: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime,
      duration: fields[3] as Duration,
      allowedApps: (fields[4] as List).cast<String>(),
      alwaysAllowedApps: (fields[5] as List).cast<String>(),
      activeProfile: fields[6] as String,
      blockingRules: (fields[7] as Map).cast<String, String>(),
      focusSettings: (fields[8] as Map).cast<String, String>(),
      scheduleId: fields[9] as String?,
      creationTimestamp: fields[10] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSessionSnapshot obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.allowedApps)
      ..writeByte(5)
      ..write(obj.alwaysAllowedApps)
      ..writeByte(6)
      ..write(obj.activeProfile)
      ..writeByte(7)
      ..write(obj.blockingRules)
      ..writeByte(8)
      ..write(obj.focusSettings)
      ..writeByte(9)
      ..write(obj.scheduleId)
      ..writeByte(10)
      ..write(obj.creationTimestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionSnapshotAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

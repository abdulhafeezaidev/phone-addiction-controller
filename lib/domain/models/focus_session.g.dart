// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 0;

  @override
  FocusSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusSession(
      id: fields[3] as String,
      startTime: fields[0] as DateTime,
      endTime: fields[1] as DateTime?,
      enabled: fields[2] as bool,
      triggerType: fields[4] as SessionTriggerType,
      stopType: fields[5] as SessionStopType?,
      blockedAttempts: fields[6] as int,
      blockedAppCounts: (fields[7] as Map?)?.cast<String, int>(),
      routineId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.startTime)
      ..writeByte(1)
      ..write(obj.endTime)
      ..writeByte(2)
      ..write(obj.enabled)
      ..writeByte(3)
      ..write(obj.id)
      ..writeByte(4)
      ..write(obj.triggerType)
      ..writeByte(5)
      ..write(obj.stopType)
      ..writeByte(6)
      ..write(obj.blockedAttempts)
      ..writeByte(7)
      ..write(obj.blockedAppCounts)
      ..writeByte(8)
      ..write(obj.routineId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionTriggerTypeAdapter extends TypeAdapter<SessionTriggerType> {
  @override
  final int typeId = 5;

  @override
  SessionTriggerType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SessionTriggerType.manual;
      case 1:
        return SessionTriggerType.scheduled;
      default:
        return SessionTriggerType.manual;
    }
  }

  @override
  void write(BinaryWriter writer, SessionTriggerType obj) {
    switch (obj) {
      case SessionTriggerType.manual:
        writer.writeByte(0);
        break;
      case SessionTriggerType.scheduled:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionTriggerTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionStopTypeAdapter extends TypeAdapter<SessionStopType> {
  @override
  final int typeId = 6;

  @override
  SessionStopType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SessionStopType.manual;
      case 1:
        return SessionStopType.scheduled;
      case 2:
        return SessionStopType.completed;
      case 3:
        return SessionStopType.appRestart;
      default:
        return SessionStopType.manual;
    }
  }

  @override
  void write(BinaryWriter writer, SessionStopType obj) {
    switch (obj) {
      case SessionStopType.manual:
        writer.writeByte(0);
        break;
      case SessionStopType.scheduled:
        writer.writeByte(1);
        break;
      case SessionStopType.completed:
        writer.writeByte(2);
        break;
      case SessionStopType.appRestart:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStopTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

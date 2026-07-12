// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AdminSettingsAdapter extends TypeAdapter<AdminSettings> {
  @override
  final int typeId = 3;

  @override
  AdminSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AdminSettings(
      passwordHash: fields[0] as String,
      isLockEnabled: fields[1] as bool,
      maxFailedAttempts: fields[2] as int,
      lastFailedAttempt: fields[3] as DateTime?,
      failedAttemptCount: fields[4] as int,
      recoveryChallenge: fields[5] as String?,
      recoveryAnswerHash: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AdminSettings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.passwordHash)
      ..writeByte(1)
      ..write(obj.isLockEnabled)
      ..writeByte(2)
      ..write(obj.maxFailedAttempts)
      ..writeByte(3)
      ..write(obj.lastFailedAttempt)
      ..writeByte(4)
      ..write(obj.failedAttemptCount)
      ..writeByte(5)
      ..write(obj.recoveryChallenge)
      ..writeByte(6)
      ..write(obj.recoveryAnswerHash);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdminSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

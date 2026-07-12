// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'allowed_app.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AllowedAppAdapter extends TypeAdapter<AllowedApp> {
  @override
  final int typeId = 1;

  @override
  AllowedApp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AllowedApp(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      icon: fields[2] as Uint8List?,
      isAllowed: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AllowedApp obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.isAllowed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AllowedAppAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

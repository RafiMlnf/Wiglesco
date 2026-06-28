// GENERATED CODE - DO NOT MODIFY BY HAND
// Manually updated 2026-06-28: renamed outputUrl→outputPath, thumbnailUrl→thumbnailPath,
// removed depthMapUrl (field 3), added isLocal (field 8), width (field 9), height (field 10).
// HiveField IDs preserved for backward-compat where possible.

part of 'history_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HistoryItemAdapter extends TypeAdapter<HistoryItem> {
  @override
  final int typeId = 0;

  @override
  HistoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HistoryItem(
      id:              fields[0]  as String,
      filename:        fields[1]  as String,
      outputPath:      (fields[2]  as String?) ?? '',
      thumbnailPath:   (fields[3]  as String?) ?? '',
      processingTime:  (fields[4]  as double?) ?? 0.0,
      style:           (fields[5]  as String?) ?? 'normal',
      format:          (fields[6]  as String?) ?? 'mp4',
      createdAt:       (fields[7]  as DateTime?) ?? DateTime.now(),
      isLocal:         (fields[8]  as bool?)   ?? true,
      width:           (fields[9]  as int?)    ?? 0,
      height:          (fields[10] as int?)    ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, HistoryItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.filename)
      ..writeByte(2)
      ..write(obj.outputPath)
      ..writeByte(3)
      ..write(obj.thumbnailPath)
      ..writeByte(4)
      ..write(obj.processingTime)
      ..writeByte(5)
      ..write(obj.style)
      ..writeByte(6)
      ..write(obj.format)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.isLocal)
      ..writeByte(9)
      ..write(obj.width)
      ..writeByte(10)
      ..write(obj.height);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

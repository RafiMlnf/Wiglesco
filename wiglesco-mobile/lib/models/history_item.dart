import 'package:hive_flutter/hive_flutter.dart';

part 'history_item.g.dart';

/// Persisted render history item.
/// Field IDs are fixed — changing them would break existing stored data.
/// isLocal = true means outputPath/thumbnailPath are local file paths.
@HiveType(typeId: 0)
class HistoryItem extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String filename;

  /// Primary output — local file path (on-device mode)
  @HiveField(2)
  late String outputPath;

  /// Thumbnail — local JPEG path
  @HiveField(3)
  late String thumbnailPath;

  @HiveField(4)
  late double processingTime;

  @HiveField(5)
  late String style;

  @HiveField(6)
  late String format;

  @HiveField(7)
  late DateTime createdAt;

  /// true = local file path (on-device), false = remote URL (legacy)
  @HiveField(8)
  late bool isLocal;

  @HiveField(9)
  late int width;

  @HiveField(10)
  late int height;

  HistoryItem({
    required this.id,
    required this.filename,
    required this.outputPath,
    required this.thumbnailPath,
    required this.processingTime,
    required this.style,
    required this.format,
    required this.createdAt,
    this.isLocal = true,
    this.width = 0,
    this.height = 0,
  });
}

import 'package:isar/isar.dart';

part 'media_record.g.dart';

/// Persistent representation of a media item within the Isar database.
@collection
class MediaRecord {
  MediaRecord({
    required this.id,
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.lastModified,
    required this.directoryId,
    List<String>? tagIds,
    this.bookmarkData,
    this.thumbnailPath,
    this.width,
    this.height,
    this.durationSeconds,
    this.metadataJson,
  }) : tagIds = tagIds ?? <String>[];

  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  late String path;

  late String name;

  /// Serialized enum value for [MediaType].
  late int type;

  late int size;

  late DateTime lastModified;

  List<String> tagIds;

  @Index()
  late String directoryId;

  String? bookmarkData;

  String? thumbnailPath;

  int? width;

  int? height;

  double? durationSeconds;

  /// JSON representation of extended metadata (EXIF, codec, etc.).
  String? metadataJson;
}

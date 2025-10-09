import 'package:isar/isar.dart';

part 'directory_record.g.dart';

/// Persistent representation of a directory inside the Isar database.
@collection
class DirectoryRecord {
  DirectoryRecord({
    required this.id,
    required this.path,
    required this.name,
    this.thumbnailPath,
    List<String>? tagIds,
    required this.lastModified,
    this.bookmarkData,
  }) : tagIds = tagIds ?? <String>[];

  /// Auto-incremented identifier required by Isar.
  Id isarId = Isar.autoIncrement;

  /// Stable string identifier used across repositories and the UI.
  @Index(unique: true, replace: true)
  late String id;

  late String path;

  late String name;

  String? thumbnailPath;

  List<String> tagIds;

  late DateTime lastModified;

  String? bookmarkData;
}

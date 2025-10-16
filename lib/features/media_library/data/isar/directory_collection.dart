import 'package:isar/isar.dart';

import '../models/directory_model.dart';

part 'directory_collection.g.dart';

/// Isar collection representing a directory record stored on disk.
@collection
class DirectoryCollection {
  DirectoryCollection({
    required this.directoryId,
    required this.path,
    required this.name,
    this.thumbnailPath,
    List<String>? tagIds,
    required this.lastModified,
    this.bookmarkData,
  }) : tagIds = tagIds != null ? List<String>.from(tagIds) : <String>[];

  /// Unique hash-based identifier used by Isar for this record.
  Id get id => Isar.fastHash(directoryId);
  set id(Id value) {}

  /// Stable directory identifier used by higher layers in the app.
  @Index(unique: true, replace: true)
  String directoryId;

  /// Absolute path on disk for the directory.
  @Index(unique: true, replace: true, caseSensitive: false)
  String path;

  /// Human-readable name of the directory.
  String name;

  /// Optional thumbnail preview for the directory.
  String? thumbnailPath;

  /// Tags assigned to the directory.
  List<String> tagIds;

  /// Timestamp of the last modification to the directory metadata.
  DateTime lastModified;

  /// Optional bookmark information for restoring access on macOS.
  String? bookmarkData;
}

extension DirectoryCollectionMapper on DirectoryCollection {
  /// Converts the [DirectoryCollection] into the existing [DirectoryModel].
  DirectoryModel toModel() {
    return DirectoryModel(
      id: directoryId,
      path: path,
      name: name,
      thumbnailPath: thumbnailPath,
      tagIds: List.unmodifiable(tagIds),
      lastModified: lastModified,
      bookmarkData: bookmarkData,
    );
  }
}

extension DirectoryModelIsarMapper on DirectoryModel {
  /// Converts the [DirectoryModel] into a persisted [DirectoryCollection].
  DirectoryCollection toCollection() {
    return DirectoryCollection(
      directoryId: id,
      path: path,
      name: name,
      thumbnailPath: thumbnailPath,
      tagIds: tagIds,
      lastModified: lastModified,
      bookmarkData: bookmarkData,
    );
  }
}

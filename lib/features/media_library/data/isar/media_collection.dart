import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../domain/entities/media_entity.dart';
import '../models/media_model.dart';
import 'directory_collection.dart';

part 'media_collection.g.dart';

/// Isar collection representing a media item stored on disk.
@collection
class MediaCollection {
  MediaCollection({
    required this.mediaId,
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.lastModified,
    required this.tagIds,
    required this.directoryId,
    this.bookmarkData,
  });

  /// Unique hash-based identifier used by Isar for this record.
  Id get id {
    final hash = sha256.convert(utf8.encode(mediaId)).bytes;
    return hash.fold<int>(0, (prev, element) => prev + element);
  }
  set id(Id value) {}

  /// Stable media identifier used throughout the app.
  @Index(unique: true, replace: true)
  String mediaId;

  /// Absolute path to the media file on disk.
  @Index(unique: true, replace: true, caseSensitive: false)
  String path;

  /// Human-readable media name.
  String name;

  /// Type of media (image, video, text, directory).
  @Enumerated(EnumType.name)
  MediaType type;

  /// Size of the media file in bytes.
  int size;

  /// Timestamp of the last modification to the media metadata.
  DateTime lastModified;

  /// Tags assigned to the media item.
  @Index(type: IndexType.hashElements)
  List<String> tagIds;

  /// Identifier of the parent directory.
  @Index(type: IndexType.hash)
  String directoryId;

  /// Optional bookmark information for restoring access on macOS.
  String? bookmarkData;

  /// Link to the parent directory record.
  final IsarLink<DirectoryCollection> directory = IsarLink<DirectoryCollection>();
}

extension MediaCollectionMapper on MediaCollection {
  /// Converts this [MediaCollection] into the existing [MediaModel].
  MediaModel toModel() {
    return MediaModel(
      id: mediaId,
      path: path,
      name: name,
      type: type,
      size: size,
      lastModified: lastModified,
      tagIds: List.unmodifiable(tagIds),
      directoryId: directoryId,
      bookmarkData: bookmarkData,
    );
  }
}

extension MediaModelIsarMapper on MediaModel {
  /// Converts the [MediaModel] into a persisted [MediaCollection].
  MediaCollection toCollection() {
    return MediaCollection(
      mediaId: id,
      path: path,
      name: name,
      type: type,
      size: size,
      lastModified: lastModified,
      tagIds: tagIds,
      directoryId: directoryId,
      bookmarkData: bookmarkData,
    );
  }
}

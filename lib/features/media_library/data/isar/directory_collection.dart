import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../models/directory_model.dart';

part 'directory_collection.g.dart';

/// Converts a directory identifier into a deterministic Isar [Id].
///
/// The first 16 hex characters (64 bits) of the SHA-256 hash are parsed and
/// masked to the maximum signed 64-bit integer value. This avoids
/// `FormatException` on platforms where `int` cannot represent unsigned 64-bit
/// values while keeping the high-entropy portion of the hash for collision
/// resistance.
Id computeDirectoryCollectionId(String directoryId) {
  final hash = sha256.convert(utf8.encode(directoryId)).toString();
  final first64Bits = hash.substring(0, 16);

  // Use BigInt to safely parse large unsigned values, then clamp to the
  // maximum signed 64-bit integer to stay within Isar's `Id` range.
  final parsed = BigInt.parse(first64Bits, radix: 16);
  const maxSignedInt64 = 0x7FFFFFFFFFFFFFFF;

  return (parsed & BigInt.from(maxSignedInt64)).toInt();
}

/// Isar collection representing a directory record stored on disk.
@collection
class DirectoryCollection {
  DirectoryCollection({
    required this.directoryId,
    required this.path,
    required this.name,
    this.thumbnailPath,
    required this.tagIds,
    required this.lastModified,
    this.bookmarkData,
  });

  /// Unique hash-based identifier used by Isar for this record.
  Id get id {
    return computeDirectoryCollectionId(directoryId);
  }
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
  @Index(type: IndexType.hashElements)
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

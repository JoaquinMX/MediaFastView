import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../models/directory_model.dart';

part 'directory_collection.g.dart';

/// Converts a directory identifier into a deterministic Isar [Id].
///
/// Delegates to [isarIdFromKey], which is bit-for-bit identical to the
/// hand-rolled BigInt version this replaced — so existing directory rows keep
/// their keys and need no migration.
Id computeDirectoryCollectionId(String directoryId) => isarIdFromKey(directoryId);

/// Isar collection representing a directory record stored on disk.
@collection
class DirectoryCollection {
  DirectoryCollection({
    required this.directoryId,
    required this.path,
    required this.name,
    this.thumbnailPath,
    required this.tagIds,
    required this.profileIds,
    required this.lastModified,
    this.bookmarkData,
    this.lastScanAt,
    this.lastKnownTreeModified,
    this.lastKnownChildDirectoryCount,
    this.lastKnownMediaFileCount,
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
  ///
  /// A directory shared between profiles carries tag ids from all of them. The
  /// repository filters this down to the active profile's tags on read and
  /// merges on write, so nothing above the data layer ever sees a foreign tag.
  @Index(type: IndexType.hashElements)
  List<String> tagIds;

  /// Profiles this directory belongs to.
  ///
  /// A directory is shared, not copied: one row, one bookmark, one scan cache,
  /// reused across every profile that tracks the folder. Empty only on rows
  /// written before profiles existed, which is what the migration detects.
  @Index(type: IndexType.hashElements)
  List<String> profileIds;

  /// Timestamp of the last modification to the directory metadata.
  DateTime lastModified;

  /// Optional bookmark information for restoring access on macOS.
  String? bookmarkData;

  /// Timestamp of the last successful full-library refresh for this root.
  DateTime? lastScanAt;

  /// Latest modification timestamp observed anywhere in the subtree.
  DateTime? lastKnownTreeModified;

  /// Total descendant directory count observed during the last refresh.
  int? lastKnownChildDirectoryCount;

  /// Total supported media file count observed during the last refresh.
  int? lastKnownMediaFileCount;
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
      profileIds: List.unmodifiable(profileIds),
      lastModified: lastModified,
      bookmarkData: bookmarkData,
      lastScanAt: lastScanAt,
      lastKnownTreeModified: lastKnownTreeModified,
      lastKnownChildDirectoryCount: lastKnownChildDirectoryCount,
      lastKnownMediaFileCount: lastKnownMediaFileCount,
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
      tagIds: List<String>.from(tagIds),
      profileIds: List<String>.from(profileIds),
      lastModified: lastModified,
      bookmarkData: bookmarkData,
      lastScanAt: lastScanAt,
      lastKnownTreeModified: lastKnownTreeModified,
      lastKnownChildDirectoryCount: lastKnownChildDirectoryCount,
      lastKnownMediaFileCount: lastKnownMediaFileCount,
    );
  }
}

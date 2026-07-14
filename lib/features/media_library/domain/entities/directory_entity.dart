import 'directory_media_counts.dart';

/// Domain entity representing a directory.
class DirectoryEntity {
  const DirectoryEntity({
    required this.id,
    required this.path,
    required this.name,
    required this.thumbnailPath,
    required this.tagIds,
    this.profileIds = const <String>[],
    required this.lastModified,
    this.bookmarkData,
    this.lastScanAt,
    this.lastKnownTreeModified,
    this.lastKnownChildDirectoryCount,
    this.lastKnownMediaFileCount,
    this.mediaCounts = const DirectoryMediaCounts(),
  });

  final String id;
  final String path;
  final String name;
  final String? thumbnailPath;

  /// Tags the active profile has assigned to this directory.
  ///
  /// Already scoped: the repository filters out tag ids owned by other profiles
  /// that share this directory, so this list can be rendered and counted
  /// directly.
  final List<String> tagIds;

  /// Profiles this directory belongs to.
  final List<String> profileIds;

  final DateTime lastModified;
  final String? bookmarkData;
  final DateTime? lastScanAt;
  final DateTime? lastKnownTreeModified;
  final int? lastKnownChildDirectoryCount;
  final int? lastKnownMediaFileCount;
  final DirectoryMediaCounts mediaCounts;

  /// Creates a copy with updated fields.
  DirectoryEntity copyWith({
    String? id,
    String? path,
    String? name,
    String? thumbnailPath,
    List<String>? tagIds,
    List<String>? profileIds,
    DateTime? lastModified,
    String? bookmarkData,
    DateTime? lastScanAt,
    DateTime? lastKnownTreeModified,
    int? lastKnownChildDirectoryCount,
    int? lastKnownMediaFileCount,
    DirectoryMediaCounts? mediaCounts,
  }) {
    return DirectoryEntity(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      tagIds: tagIds ?? this.tagIds,
      profileIds: profileIds ?? this.profileIds,
      lastModified: lastModified ?? this.lastModified,
      bookmarkData: bookmarkData ?? this.bookmarkData,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      lastKnownTreeModified:
          lastKnownTreeModified ?? this.lastKnownTreeModified,
      lastKnownChildDirectoryCount:
          lastKnownChildDirectoryCount ?? this.lastKnownChildDirectoryCount,
      lastKnownMediaFileCount:
          lastKnownMediaFileCount ?? this.lastKnownMediaFileCount,
      mediaCounts: mediaCounts ?? this.mediaCounts,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectoryEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'DirectoryEntity('
        'id: $id, '
        'path: $path, '
        'name: $name, '
        'thumbnailPath: $thumbnailPath, '
        'tagIds: $tagIds, '
        'profileIds: $profileIds, '
        'lastModified: $lastModified, '
        'bookmarkData: $bookmarkData, '
        'lastScanAt: $lastScanAt, '
        'lastKnownTreeModified: $lastKnownTreeModified, '
        'lastKnownChildDirectoryCount: $lastKnownChildDirectoryCount, '
        'lastKnownMediaFileCount: $lastKnownMediaFileCount, '
        'mediaCounts: $mediaCounts'
        ')';
  }
}

import 'directory_media_counts.dart';

/// Domain entity representing a directory.
class DirectoryEntity {
  const DirectoryEntity({
    required this.id,
    required this.path,
    required this.name,
    required this.thumbnailPath,
    required this.tagIds,
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
  final List<String> tagIds;
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

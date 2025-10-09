/// Enum representing different types of media.
enum MediaType { image, video, text, audio, document, directory }

/// Domain entity representing a media item.
class MediaEntity {
  const MediaEntity({
    required this.id,
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.lastModified,
    required this.tagIds,
    required this.directoryId,
    this.bookmarkData,
    this.thumbnailPath,
    this.width,
    this.height,
    this.duration,
    this.metadata,
  });

  final String id;
  final String path;
  final String name;
  final MediaType type;
  final int size;
  final DateTime lastModified;
  final List<String> tagIds;
  final String directoryId;
  final String? bookmarkData;
  final String? thumbnailPath;
  final int? width;
  final int? height;
  final Duration? duration;
  final Map<String, dynamic>? metadata;

  /// Creates a copy with updated fields.
  MediaEntity copyWith({
    String? id,
    String? path,
    String? name,
    MediaType? type,
    int? size,
    DateTime? lastModified,
    List<String>? tagIds,
    String? directoryId,
    String? bookmarkData,
    String? thumbnailPath,
    int? width,
    int? height,
    Duration? duration,
    Map<String, dynamic>? metadata,
  }) {
    return MediaEntity(
      id: id ?? this.id,
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      tagIds: tagIds ?? this.tagIds,
      directoryId: directoryId ?? this.directoryId,
      bookmarkData: bookmarkData ?? this.bookmarkData,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MediaEntity(id: $id, path: $path, name: $name, type: $type, size: $size, lastModified: $lastModified, tagIds: $tagIds, directoryId: $directoryId, bookmarkData: $bookmarkData, thumbnailPath: $thumbnailPath, width: $width, height: $height, duration: $duration, metadata: $metadata)';
}

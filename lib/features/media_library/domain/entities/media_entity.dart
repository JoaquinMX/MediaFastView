/// Enum representing different types of media.
enum MediaType { image, video, text, directory }

extension MediaTypeX on MediaType {
  String get label => switch (this) {
        MediaType.image => 'Images',
        MediaType.video => 'Videos',
        MediaType.text => 'Text',
        MediaType.directory => 'Directories',
      };
}

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
    this.signature,
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
  final String? signature;

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
    String? signature,
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
      signature: signature ?? this.signature,
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
      'MediaEntity(id: $id, path: $path, name: $name, type: $type, size: $size, lastModified: $lastModified, tagIds: $tagIds, directoryId: $directoryId, bookmarkData: $bookmarkData, signature: $signature)';
}

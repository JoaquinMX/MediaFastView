import '../../../media_library/domain/entities/media_entity.dart';

/// A user-selected image or video used as a visual lookup query.
class ImageLookupSource {
  const ImageLookupSource({
    required this.path,
    required this.name,
    required this.size,
    required this.lastModified,
    this.mediaType = MediaType.image,
    this.bookmarkData,
  });

  final String path;
  final String name;
  final int size;
  final DateTime lastModified;
  final MediaType mediaType;

  /// A macOS security-scoped bookmark used to reopen saved-history queries.
  final String? bookmarkData;

  ImageLookupSource copyWith({
    String? path,
    String? name,
    int? size,
    DateTime? lastModified,
    MediaType? mediaType,
    String? bookmarkData,
  }) {
    return ImageLookupSource(
      path: path ?? this.path,
      name: name ?? this.name,
      size: size ?? this.size,
      lastModified: lastModified ?? this.lastModified,
      mediaType: mediaType ?? this.mediaType,
      bookmarkData: bookmarkData ?? this.bookmarkData,
    );
  }
}

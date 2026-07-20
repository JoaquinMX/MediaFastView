import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

/// Quantized output sizes keep the cache from accumulating one file per layout
/// width while still supporting small previews and large grid cards.
enum ThumbnailSize {
  small(256),
  medium(512),
  large(1024);

  const ThumbnailSize(this.maxPixelSize);

  final int maxPixelSize;

  static ThumbnailSize forPhysicalPixels(double pixels) {
    if (pixels <= small.maxPixelSize) {
      return small;
    }
    if (pixels <= medium.maxPixelSize) {
      return medium;
    }
    return large;
  }
}

/// Immutable source fingerprint and generation policy for one thumbnail.
class ThumbnailRequest {
  const ThumbnailRequest({
    required this.path,
    required this.mediaType,
    required this.sourceSize,
    required this.sourceLastModified,
    required this.thumbnailSize,
    required this.diskCacheEnabled,
    this.bookmarkData,
  });

  factory ThumbnailRequest.fromMedia(
    MediaEntity media, {
    required ThumbnailSize thumbnailSize,
    required bool diskCacheEnabled,
    String? bookmarkData,
  }) {
    return ThumbnailRequest(
      path: media.path,
      mediaType: media.type,
      sourceSize: media.size,
      sourceLastModified: media.lastModified,
      thumbnailSize: thumbnailSize,
      diskCacheEnabled: diskCacheEnabled,
      bookmarkData: bookmarkData ?? media.bookmarkData,
    );
  }

  final String path;
  final MediaType mediaType;
  final int sourceSize;
  final DateTime sourceLastModified;
  final ThumbnailSize thumbnailSize;
  final bool diskCacheEnabled;
  final String? bookmarkData;

  bool get isSupported =>
      mediaType == MediaType.image || mediaType == MediaType.video;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ThumbnailRequest &&
            path == other.path &&
            mediaType == other.mediaType &&
            sourceSize == other.sourceSize &&
            sourceLastModified == other.sourceLastModified &&
            thumbnailSize == other.thumbnailSize &&
            diskCacheEnabled == other.diskCacheEnabled &&
            bookmarkData == other.bookmarkData;
  }

  @override
  int get hashCode => Object.hash(
    path,
    mediaType,
    sourceSize,
    sourceLastModified,
    thumbnailSize,
    diskCacheEnabled,
    bookmarkData,
  );
}

import '../../domain/entities/media_entity.dart';

/// Describes the visual source selected for a directory card.
sealed class DirectoryPreview {
  const DirectoryPreview({
    required this.sourcePath,
    this.hasStaleCustomCover = false,
  });

  /// The media file represented by this preview.
  final String sourcePath;

  /// Whether the persisted custom source was confirmed missing during resolve.
  final bool hasStaleCustomCover;
}

/// Uses a user-selected direct-child image or video as the preview.
final class DirectoryCustomPreview extends DirectoryPreview {
  DirectoryCustomPreview({required this.media}) : super(sourcePath: media.path);

  final MediaEntity media;
}

/// Uses an image file from the directory as its preview.
final class DirectoryImagePreview extends DirectoryPreview {
  const DirectoryImagePreview({
    required super.sourcePath,
    super.hasStaleCustomCover,
  });
}

/// Uses an existing cached thumbnail for a video in the directory.
final class DirectoryVideoPreview extends DirectoryPreview {
  const DirectoryVideoPreview({
    required super.sourcePath,
    required this.thumbnailPath,
    super.hasStaleCustomCover,
  });

  /// The generated thumbnail file that can be rendered directly.
  final String thumbnailPath;
}

/// Represents an empty automatic fallback while a stale cover is cleaned up.
final class DirectoryEmptyPreview extends DirectoryPreview {
  const DirectoryEmptyPreview()
    : super(sourcePath: '', hasStaleCustomCover: true);
}

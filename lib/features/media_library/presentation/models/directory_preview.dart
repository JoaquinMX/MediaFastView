/// Describes the visual source selected for a directory card.
sealed class DirectoryPreview {
  const DirectoryPreview({required this.sourcePath});

  /// The media file represented by this preview.
  final String sourcePath;
}

/// Uses an image file from the directory as its preview.
final class DirectoryImagePreview extends DirectoryPreview {
  const DirectoryImagePreview({required super.sourcePath});
}

/// Uses an existing cached thumbnail for a video in the directory.
final class DirectoryVideoPreview extends DirectoryPreview {
  const DirectoryVideoPreview({
    required super.sourcePath,
    required this.thumbnailPath,
  });

  /// The generated thumbnail file that can be rendered directly.
  final String thumbnailPath;
}

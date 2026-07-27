import '../../domain/entities/media_entity.dart';

/// Describes one visual source selected for a directory preview catalog.
sealed class DirectoryPreview {
  const DirectoryPreview({
    required this.sourcePath,
    this.bookmarkData,
    this.hasStaleCustomCover = false,
  });

  /// The media file represented by this preview.
  final String sourcePath;

  /// The security-scoped bookmark that grants access to [sourcePath], when
  /// one was inherited while resolving the catalog.
  final String? bookmarkData;

  /// Whether the persisted custom source was confirmed missing during resolve.
  final bool hasStaleCustomCover;
}

/// Uses a user-selected direct-child image or video as the preview.
final class DirectoryCustomPreview extends DirectoryPreview {
  DirectoryCustomPreview({required this.media, super.bookmarkData})
    : super(sourcePath: media.path);

  final MediaEntity media;
}

/// Uses an image file from the directory as its preview.
final class DirectoryImagePreview extends DirectoryPreview {
  const DirectoryImagePreview({
    required super.sourcePath,
    super.bookmarkData,
    super.hasStaleCustomCover,
  });
}

/// Uses an existing cached thumbnail for a video in the directory.
final class DirectoryVideoPreview extends DirectoryPreview {
  const DirectoryVideoPreview({
    required super.sourcePath,
    required this.thumbnailPath,
    super.bookmarkData,
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

/// The bounded set of previews available for one directory.
///
/// A custom cover, when present, is always the first item. Automatic images
/// and cached video frames follow in deterministic filename order. The catalog
/// intentionally stores sources rather than a rendered composite, so cards can
/// use a collage while richer browsing surfaces can use the same individual
/// previews later.
class DirectoryPreviewCatalog {
  const DirectoryPreviewCatalog({
    required this.previews,
    this.missingCustomCoverFileNames = const <String>[],
  });

  /// Ordered previews, with valid custom selections first when present.
  final List<DirectoryPreview> previews;

  /// Persisted selections proven absent by a successful direct-child scan.
  final List<String> missingCustomCoverFileNames;

  /// Whether a successful scan proved at least one stored selection is gone.
  bool get hasStaleCustomCover => missingCustomCoverFileNames.isNotEmpty;

  /// Whether [previews] begins with at least one user-selected cover.
  bool get hasCustomCover =>
      previews.isNotEmpty && previews.first is DirectoryCustomPreview;

  /// Valid user-selected previews in their persisted collage order.
  List<DirectoryPreview> get customPreviews =>
      previews.whereType<DirectoryCustomPreview>().toList(growable: false);

  /// The preview that should fill a single-preview surface.
  DirectoryPreview? get primaryPreview =>
      previews.isEmpty ? null : previews.first;

  /// Automatic previews, excluding every custom cover selection.
  List<DirectoryPreview> get automaticPreviews => previews
      .where((preview) => preview is! DirectoryCustomPreview)
      .toList(growable: false);

  /// Whether the catalog has nothing that can be rendered.
  bool get isEmpty => previews.isEmpty;
}

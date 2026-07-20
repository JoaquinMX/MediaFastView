import 'dart:typed_data';

/// The renderable payload produced by the thumbnail pipeline.
sealed class ThumbnailPayload {
  const ThumbnailPayload();
}

final class FileThumbnailPayload extends ThumbnailPayload {
  const FileThumbnailPayload(this.path);

  final String path;
}

final class MemoryThumbnailPayload extends ThumbnailPayload {
  const MemoryThumbnailPayload(this.bytes);

  final Uint8List bytes;
}

/// A thumbnail together with whether it avoided native generation.
class ThumbnailResult {
  const ThumbnailResult({required this.payload, required this.isCacheHit});

  final ThumbnailPayload payload;
  final bool isCacheHit;
}

class ThumbnailCancelledException implements Exception {
  const ThumbnailCancelledException();

  @override
  String toString() => 'Thumbnail generation was cancelled';
}

import '../../../media_library/domain/entities/media_entity.dart';
import '../../../thumbnails/data/thumbnail_coordinator.dart';
import '../../../thumbnails/domain/thumbnail_request.dart';
import '../../../thumbnails/domain/thumbnail_result.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import 'perceptual_hasher.dart';

/// Produces the perceptual hash used to compare a video's generated miniature.
abstract interface class VideoThumbnailHasher {
  Future<ImageHashResult?> hashVideo({
    required String path,
    required int size,
    required DateTime lastModified,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  });
}

/// Reuses the shared AVFoundation thumbnail pipeline and its disk cache.
class CachedVideoThumbnailHasher implements VideoThumbnailHasher {
  const CachedVideoThumbnailHasher({
    required ThumbnailCoordinator coordinator,
    PerceptualHasher perceptualHasher = const PerceptualHasher(),
    bool diskCacheEnabled = true,
  }) : _coordinator = coordinator,
       _perceptualHasher = perceptualHasher,
       _diskCacheEnabled = diskCacheEnabled;

  final ThumbnailCoordinator _coordinator;
  final PerceptualHasher _perceptualHasher;
  final bool _diskCacheEnabled;

  @override
  Future<ImageHashResult?> hashVideo({
    required String path,
    required int size,
    required DateTime lastModified,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  }) async {
    final thumbnailCancellation = ThumbnailCancellationToken();
    final removeCancellationListener = cancellation?.addListener(
      thumbnailCancellation.cancel,
    );
    try {
      final result = await _coordinator.load(
        ThumbnailRequest(
          path: path,
          mediaType: MediaType.video,
          sourceSize: size,
          sourceLastModified: lastModified,
          thumbnailSize: ThumbnailSize.medium,
          diskCacheEnabled: _diskCacheEnabled,
          bookmarkData: bookmarkData,
        ),
        priority: ThumbnailPriority.background,
        cancellationToken: thumbnailCancellation,
      );
      if (cancellation?.isCancelled ?? false) {
        return null;
      }
      return switch (result.payload) {
        FileThumbnailPayload(:final path) => _perceptualHasher.hashFile(path),
        MemoryThumbnailPayload(:final bytes) => _perceptualHasher.hashBytes(
          bytes,
        ),
      };
    } on ThumbnailCancelledException {
      return null;
    } catch (_) {
      return null;
    } finally {
      removeCancellationListener?.call();
    }
  }
}

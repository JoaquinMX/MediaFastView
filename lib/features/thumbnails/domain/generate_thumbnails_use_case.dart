import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_batch_progress.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';
import 'package:media_fast_view/shared/utils/bookmark_resolver.dart';

typedef ThumbnailBatchProgressCallback =
    void Function(ThumbnailBatchProgress progress);

/// Pre-generates the standard thumbnail variant for the active library.
class GenerateThumbnailsUseCase {
  const GenerateThumbnailsUseCase({
    required MediaRepository mediaRepository,
    required DirectoryRepository directoryRepository,
    required ThumbnailCoordinator coordinator,
    required ThumbnailDiskCache cache,
  }) : _mediaRepository = mediaRepository,
       _directoryRepository = directoryRepository,
       _coordinator = coordinator,
       _cache = cache;

  final MediaRepository _mediaRepository;
  final DirectoryRepository _directoryRepository;
  final ThumbnailCoordinator _coordinator;
  final ThumbnailDiskCache _cache;

  Future<ThumbnailBatchProgress> call({
    required ThumbnailCancellationToken cancellationToken,
    ThumbnailBatchProgressCallback? onProgress,
  }) async {
    final allMedia = await _mediaRepository.getAllMedia();
    final media = allMedia.where(_supportsThumbnails).toList(growable: false);
    final directories = await _directoryRepository.getDirectories();
    var progress = ThumbnailBatchProgress(
      status: ThumbnailBatchStatus.running,
      total: media.length,
      completed: 0,
      generated: 0,
      cacheHits: 0,
      failed: 0,
    );
    onProgress?.call(progress);

    for (final item in media) {
      if (cancellationToken.isCancelled) {
        break;
      }
      progress = progress.copyWith(currentName: item.name);
      onProgress?.call(progress);

      try {
        final bookmark =
            item.bookmarkData ?? resolveBookmarkForPath(item.path, directories);
        final result = await _coordinator.load(
          ThumbnailRequest.fromMedia(
            item,
            thumbnailSize: ThumbnailSize.medium,
            diskCacheEnabled: true,
            bookmarkData: bookmark,
          ),
          priority: ThumbnailPriority.background,
          cancellationToken: cancellationToken,
        );
        if (result.payload is MemoryThumbnailPayload) {
          // Visible thumbnails may fall back to memory when a disk write fails,
          // but a batch item is only successful if it was actually persisted.
          progress = progress.copyWith(
            completed: progress.completed + 1,
            failed: progress.failed + 1,
          );
        } else {
          progress = progress.copyWith(
            completed: progress.completed + 1,
            generated: progress.generated + (result.isCacheHit ? 0 : 1),
            cacheHits: progress.cacheHits + (result.isCacheHit ? 1 : 0),
          );
        }
      } on ThumbnailCancelledException {
        break;
      } catch (_) {
        progress = progress.copyWith(
          completed: progress.completed + 1,
          failed: progress.failed + 1,
        );
      }
      onProgress?.call(progress);
    }

    try {
      await _cache.trim();
    } catch (_) {
      // Trimming is best-effort and should not discard an otherwise accurate
      // batch summary.
    }
    final finalStatus = cancellationToken.isCancelled
        ? ThumbnailBatchStatus.cancelled
        : ThumbnailBatchStatus.completed;
    progress = progress.copyWith(status: finalStatus, clearCurrentName: true);
    onProgress?.call(progress);
    return progress;
  }

  bool _supportsThumbnails(MediaEntity media) {
    return media.type == MediaType.image || media.type == MediaType.video;
  }
}

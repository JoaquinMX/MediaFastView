import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/domain/generate_thumbnails_use_case.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_batch_progress.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/active_profile_provider.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/providers/settings_providers.dart';

final generateThumbnailsUseCaseProvider = Provider<GenerateThumbnailsUseCase>((
  ref,
) {
  return GenerateThumbnailsUseCase(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    directoryRepository: ref.watch(directoryRepositoryProvider),
    coordinator: ref.watch(thumbnailCoordinatorProvider),
    cache: ref.watch(thumbnailDiskCacheProvider),
  );
});

final thumbnailBatchControllerProvider =
    NotifierProvider<ThumbnailBatchController, ThumbnailBatchProgress>(
      ThumbnailBatchController.new,
    );

class ThumbnailBatchController extends Notifier<ThumbnailBatchProgress> {
  ThumbnailCancellationToken? _cancellationToken;

  @override
  ThumbnailBatchProgress build() {
    ref.watch(activeProfileIdProvider);
    ref.listen<bool>(thumbnailDiskCacheEnabledProvider, (_, enabled) {
      if (!enabled) {
        cancel();
      }
    });
    ref.onDispose(() {
      _cancellationToken?.cancel();
      _cancellationToken = null;
    });
    return const ThumbnailBatchProgress.idle();
  }

  Future<void> start() async {
    if (state.isActive || !ref.read(thumbnailDiskCacheEnabledProvider)) {
      return;
    }

    final cancellationToken = ThumbnailCancellationToken();
    _cancellationToken = cancellationToken;
    state = const ThumbnailBatchProgress(
      status: ThumbnailBatchStatus.running,
      total: 0,
      completed: 0,
      generated: 0,
      cacheHits: 0,
      failed: 0,
    );

    try {
      final result = await ref.read(generateThumbnailsUseCaseProvider)(
        cancellationToken: cancellationToken,
        onProgress: (progress) {
          if (!identical(_cancellationToken, cancellationToken)) {
            return;
          }
          state = state.status == ThumbnailBatchStatus.cancelling
              ? progress.copyWith(status: ThumbnailBatchStatus.cancelling)
              : progress;
        },
      );
      if (!identical(_cancellationToken, cancellationToken)) {
        return;
      }
      state = result;
    } catch (error) {
      if (!identical(_cancellationToken, cancellationToken)) {
        return;
      }
      state = state.copyWith(
        status: ThumbnailBatchStatus.failed,
        errorMessage: '$error',
        clearCurrentName: true,
      );
    } finally {
      if (identical(_cancellationToken, cancellationToken)) {
        _cancellationToken = null;
        ref.invalidate(thumbnailCacheUsageProvider);
      }
    }
  }

  void cancel() {
    if (!state.isActive) {
      return;
    }
    state = state.copyWith(status: ThumbnailBatchStatus.cancelling);
    _cancellationToken?.cancel();
  }

  Future<bool> clearCache() async {
    if (state.isActive) {
      return false;
    }
    try {
      await ref.read(thumbnailDiskCacheProvider).clear();
      ref.invalidate(thumbnailProvider);
      ref.invalidate(thumbnailCacheUsageProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}

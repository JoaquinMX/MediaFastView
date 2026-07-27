import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_catalog_invalidator.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/generate_thumbnails_use_case.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_batch_progress.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_batch_controller.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/active_profile_provider.dart';
import 'package:media_fast_view/shared/providers/settings_providers.dart';

class _GenerateThumbnailsUseCaseFake extends Fake
    implements GenerateThumbnailsUseCase {
  @override
  Future<ThumbnailBatchProgress> call({
    required ThumbnailCancellationToken cancellationToken,
    ThumbnailBatchProgressCallback? onProgress,
  }) async {
    const result = ThumbnailBatchProgress(
      status: ThumbnailBatchStatus.completed,
      total: 0,
      completed: 0,
      generated: 0,
      cacheHits: 0,
      failed: 0,
    );
    onProgress?.call(result);
    return result;
  }
}

class _ThumbnailDiskCacheFake extends Fake implements ThumbnailDiskCache {
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls += 1;
  }
}

ProviderContainer _createContainer({
  required int Function() onPreviewBuild,
  required ThumbnailDiskCache thumbnailDiskCache,
}) {
  return ProviderContainer(
    overrides: <Override>[
      activeProfileIdProvider.overrideWith(
        () => ActiveProfileIdNotifier('profile-1'),
      ),
      thumbnailDiskCacheEnabledProvider.overrideWithValue(true),
      generateThumbnailsUseCaseProvider.overrideWithValue(
        _GenerateThumbnailsUseCaseFake(),
      ),
      thumbnailDiskCacheProvider.overrideWithValue(thumbnailDiskCache),
      directoryPreviewCatalogProvider.overrideWith((ref, query) {
        ref.watch(
          directoryPreviewCatalogPathRevisionProvider(query.directoryPath),
        );
        onPreviewBuild();
        return const DirectoryPreviewCatalog(previews: <DirectoryPreview>[]);
      }),
    ],
  );
}

void main() {
  test(
    'refreshes directory previews after batch generation finishes',
    () async {
      var previewBuilds = 0;
      final container = _createContainer(
        onPreviewBuild: () => previewBuilds += 1,
        thumbnailDiskCache: _ThumbnailDiskCacheFake(),
      );
      addTearDown(container.dispose);
      final provider = directoryPreviewCatalogProvider(
        const DirectoryPreviewCatalogQuery(directoryPath: '/library/folder'),
      );
      final subscription = container
          .listen<AsyncValue<DirectoryPreviewCatalog>>(
            provider,
            (_, __) {},
            fireImmediately: true,
          );
      addTearDown(subscription.close);
      await container.read(provider.future);

      await container.read(thumbnailBatchControllerProvider.notifier).start();
      await container.pump();
      await container.read(provider.future);

      expect(previewBuilds, 2);
    },
  );

  test('refreshes directory previews after clearing the cache', () async {
    var previewBuilds = 0;
    final thumbnailDiskCache = _ThumbnailDiskCacheFake();
    final container = _createContainer(
      onPreviewBuild: () => previewBuilds += 1,
      thumbnailDiskCache: thumbnailDiskCache,
    );
    addTearDown(container.dispose);
    final provider = directoryPreviewCatalogProvider(
      const DirectoryPreviewCatalogQuery(directoryPath: '/library/folder'),
    );
    final subscription = container.listen<AsyncValue<DirectoryPreviewCatalog>>(
      provider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.read(provider.future);

    final cleared = await container
        .read(thumbnailBatchControllerProvider.notifier)
        .clearCache();
    await container.pump();
    await container.read(provider.future);

    expect(cleared, isTrue);
    expect(thumbnailDiskCache.clearCalls, 1);
    expect(previewBuilds, 2);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/thumbnails/data/native_thumbnail_generator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:media_fast_view/shared/utils/media_id_utils.dart';

final thumbnailGeneratorProvider = Provider<ThumbnailGenerator>((ref) {
  return const NativeThumbnailGenerator();
});

final thumbnailDiskCacheProvider = Provider<ThumbnailDiskCache>((ref) {
  return ThumbnailDiskCache();
});

final thumbnailCoordinatorProvider = Provider<ThumbnailCoordinator>((ref) {
  final coordinator = ThumbnailCoordinator(
    generator: ref.watch(thumbnailGeneratorProvider),
    cache: ref.watch(thumbnailDiskCacheProvider),
  );
  ref.onDispose(() => unawaited(coordinator.dispose()));
  return coordinator;
});

final thumbnailProvider = FutureProvider.autoDispose
    .family<ThumbnailResult, ThumbnailRequest>((ref, request) async {
      final cancellationToken = ThumbnailCancellationToken();
      ref.onDispose(cancellationToken.cancel);
      return ref
          .watch(thumbnailCoordinatorProvider)
          .load(request, cancellationToken: cancellationToken);
    });

final thumbnailCacheUsageProvider = FutureProvider.autoDispose<int>((ref) {
  return ref.watch(thumbnailDiskCacheProvider).sizeInBytes();
});

/// Library roots are loaded once so global thumbnail surfaces can resolve the
/// bookmark inherited by persisted media rows.
final thumbnailLibraryDirectoriesProvider =
    FutureProvider<List<DirectoryEntity>>(
      (ref) => ref.watch(directoryRepositoryProvider).getDirectories(),
    );

/// Supplies the source fingerprint needed to cache decorative path-only image
/// previews without changing the directory preview providers' public API.
final previewImageMediaProvider = FutureProvider.autoDispose
    .family<MediaEntity, String>((ref, filePath) async {
      final file = File(filePath);
      final stat = await file.stat();
      final name = p.basename(filePath);
      return MediaEntity(
        id: generateMediaIdFromMetadata(
          size: stat.size,
          lastModified: stat.modified,
          fileName: name,
        ),
        path: filePath,
        name: name,
        type: MediaType.image,
        size: stat.size,
        lastModified: stat.modified,
        tagIds: const <String>[],
        directoryId: generateDirectoryId(p.dirname(filePath)),
      );
    });

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
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_catalog_invalidator.dart';
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
      final catalogInvalidator = request.diskCacheEnabled
          ? ref.watch(directoryPreviewCatalogInvalidatorProvider)
          : null;
      final result = await ref
          .watch(thumbnailCoordinatorProvider)
          .load(request, cancellationToken: cancellationToken);
      if (!result.isCacheHit && catalogInvalidator != null) {
        catalogInvalidator.invalidateDirectory(p.dirname(request.path));
      }
      return result;
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

/// Identifies a lazy image preview and the bookmark that covers its source.
class PreviewImageMediaQuery {
  const PreviewImageMediaQuery({required this.path, this.bookmarkData});

  final String path;
  final String? bookmarkData;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PreviewImageMediaQuery &&
            path == other.path &&
            bookmarkData == other.bookmarkData;
  }

  @override
  int get hashCode => Object.hash(path, bookmarkData);
}

/// Supplies the source fingerprint needed to cache decorative path-only image
/// previews. The small stat operation opens an inherited security scope on
/// Apple platforms, then the normal [MediaThumbnail] request opens it again for
/// native decoding as needed.
final previewImageMediaProvider = FutureProvider.autoDispose
    .family<MediaEntity, PreviewImageMediaQuery>((ref, query) async {
      final bookmarkData = query.bookmarkData;
      final bookmarkService = ref.read(bookmarkServiceProvider);
      var startedAccess = false;
      if (bookmarkData != null && bookmarkData.isNotEmpty) {
        try {
          await bookmarkService.startAccessingBookmark(bookmarkData);
          startedAccess = true;
        } catch (_) {
          // The stat below still works for ordinary filesystem paths and for
          // scopes that remain available without an explicit new acquisition.
        }
      }

      try {
        final file = File(query.path);
        final stat = await file.stat();
        final name = p.basename(query.path);
        return MediaEntity(
          id: generateMediaIdFromMetadata(
            size: stat.size,
            lastModified: stat.modified,
            fileName: name,
          ),
          path: query.path,
          name: name,
          type: MediaType.image,
          size: stat.size,
          lastModified: stat.modified,
          tagIds: const <String>[],
          directoryId: generateDirectoryId(p.dirname(query.path)),
          bookmarkData: bookmarkData,
        );
      } finally {
        if (startedAccess) {
          try {
            await bookmarkService.stopAccessingBookmark(bookmarkData!);
          } catch (_) {
            // Cleanup failures are non-fatal and must not discard a valid stat.
          }
        }
      }
    });

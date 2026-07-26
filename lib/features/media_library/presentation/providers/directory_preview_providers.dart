import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/media_id_utils.dart';
import '../../../thumbnails/data/thumbnail_disk_cache.dart';
import '../../../thumbnails/domain/thumbnail_request.dart';
import '../../../thumbnails/presentation/thumbnail_providers.dart';
import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../models/directory_preview.dart';
import 'directory_cover_providers.dart';

const Duration _previewProviderKeepAliveDuration = Duration(milliseconds: 500);

void _configurePreviewProviderKeepAlive(Ref ref) {
  final keepAliveLink = ref.keepAlive();
  Timer? disposeTimer;

  ref.onCancel(() {
    disposeTimer = Timer(
      _previewProviderKeepAliveDuration,
      keepAliveLink.close,
    );
  });

  ref.onResume(() {
    disposeTimer?.cancel();
    disposeTimer = null;
  });

  ref.onDispose(() {
    disposeTimer?.cancel();
    disposeTimer = null;
  });
}

/// Selects the custom or automatic preview shown by a directory card.
final directoryPreviewProvider = FutureProvider.autoDispose
    .family<DirectoryPreview?, String>((ref, directoryPath) async {
      _configurePreviewProviderKeepAlive(ref);
      final fileService = ref.watch(fileServiceProvider);
      final customCover = await ref.watch(
        directoryCoverProvider(directoryPath).future,
      );
      if (customCover?.mode == DirectoryCoverMode.none) {
        return null;
      }
      final diskCacheEnabled = ref.watch(thumbnailDiskCacheEnabledProvider);
      final thumbnailDiskCache = diskCacheEnabled
          ? ref.watch(thumbnailDiskCacheProvider)
          : null;

      try {
        final contents = await fileService.getDirectoryContents(directoryPath);
        final files = contents.whereType<File>().toList(growable: false);
        var hasStaleCustomCover = false;

        if (customCover != null) {
          final sourceFileName = customCover.sourceFileName!;
          final mediaType = customCover.mediaType!;
          final customPath = p.normalize(p.join(directoryPath, sourceFileName));
          final customFile = files
              .where(
                (file) =>
                    p.normalize(file.path).toLowerCase() ==
                    customPath.toLowerCase(),
              )
              .firstOrNull;
          if (customFile != null) {
            final stat = await customFile.stat();
            final media = MediaEntity(
              id: generateMediaIdFromMetadata(
                size: stat.size,
                lastModified: stat.modified,
                fileName: sourceFileName,
              ),
              path: customFile.path,
              name: sourceFileName,
              type: mediaType,
              size: stat.size,
              lastModified: stat.modified,
              tagIds: const <String>[],
              directoryId: generateDirectoryId(directoryPath),
            );
            return DirectoryCustomPreview(media: media);
          }
          hasStaleCustomCover = true;
        }

        for (final file in files) {
          if (fileService.getMediaTypeFromExtension(file.path) == 'image') {
            return DirectoryImagePreview(
              sourcePath: file.path,
              hasStaleCustomCover: hasStaleCustomCover,
            );
          }
        }

        if (thumbnailDiskCache == null) {
          return hasStaleCustomCover ? const DirectoryEmptyPreview() : null;
        }

        for (final file in files) {
          if (fileService.getMediaTypeFromExtension(file.path) != 'video') {
            continue;
          }
          final thumbnailPath = await _findCachedVideoThumbnail(
            file,
            thumbnailDiskCache,
          );
          if (thumbnailPath != null) {
            return DirectoryVideoPreview(
              sourcePath: file.path,
              thumbnailPath: thumbnailPath,
              hasStaleCustomCover: hasStaleCustomCover,
            );
          }
        }
      } catch (_) {
        return null;
      }
      return customCover != null ? const DirectoryEmptyPreview() : null;
    });

/// Builds the five-item directory hover strip, with a custom cover first.
final directoryPreviewStripProvider = FutureProvider.autoDispose
    .family<DirectoryPreviewResolutionList, String>((ref, directoryPath) async {
      _configurePreviewProviderKeepAlive(ref);
      final fileService = ref.watch(fileServiceProvider);
      final customCover = await ref.watch(
        directoryCoverProvider(directoryPath).future,
      );
      if (customCover?.mode == DirectoryCoverMode.none) {
        return const DirectoryPreviewResolutionList(previews: []);
      }

      try {
        final contents = await fileService.getDirectoryContents(directoryPath);
        final files = contents.whereType<File>().toList(growable: false);
        final previews = <DirectoryPreview>[];
        String? customPath;
        var hasStaleCustomCover = false;

        if (customCover != null) {
          final sourceFileName = customCover.sourceFileName!;
          final mediaType = customCover.mediaType!;
          customPath = p.normalize(p.join(directoryPath, sourceFileName));
          final file = files
              .where(
                (candidate) =>
                    p.normalize(candidate.path).toLowerCase() ==
                    customPath!.toLowerCase(),
              )
              .firstOrNull;
          if (file == null) {
            hasStaleCustomCover = true;
          } else {
            final stat = await file.stat();
            previews.add(
              DirectoryCustomPreview(
                media: MediaEntity(
                  id: generateMediaIdFromMetadata(
                    size: stat.size,
                    lastModified: stat.modified,
                    fileName: sourceFileName,
                  ),
                  path: file.path,
                  name: sourceFileName,
                  type: mediaType,
                  size: stat.size,
                  lastModified: stat.modified,
                  tagIds: const <String>[],
                  directoryId: generateDirectoryId(directoryPath),
                ),
              ),
            );
          }
        }

        for (final file in files) {
          if (previews.length == 5) {
            break;
          }
          if (fileService.getMediaTypeFromExtension(file.path) != 'image' ||
              (customPath != null &&
                  p.normalize(file.path).toLowerCase() ==
                      customPath.toLowerCase())) {
            continue;
          }
          previews.add(DirectoryImagePreview(sourcePath: file.path));
        }
        return DirectoryPreviewResolutionList(
          previews: List.unmodifiable(previews),
          hasStaleCustomCover: hasStaleCustomCover,
        );
      } catch (_) {
        return const DirectoryPreviewResolutionList(previews: []);
      }
    });

class DirectoryPreviewResolutionList {
  const DirectoryPreviewResolutionList({
    required this.previews,
    this.hasStaleCustomCover = false,
  });

  final List<DirectoryPreview> previews;
  final bool hasStaleCustomCover;
}

Future<String?> _findCachedVideoThumbnail(
  File video,
  ThumbnailDiskCache thumbnailDiskCache,
) async {
  try {
    final stat = await video.stat();
    if (stat.type != FileSystemEntityType.file) {
      return null;
    }
    final request = ThumbnailRequest(
      path: video.path,
      mediaType: MediaType.video,
      sourceSize: stat.size,
      sourceLastModified: stat.modified,
      thumbnailSize: ThumbnailSize.medium,
      diskCacheEnabled: true,
    );
    return (await thumbnailDiskCache.read(request))?.path;
  } catch (_) {
    return null;
  }
}

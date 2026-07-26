import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../thumbnails/data/thumbnail_disk_cache.dart';
import '../../../thumbnails/domain/thumbnail_request.dart';
import '../../../thumbnails/presentation/thumbnail_providers.dart';
import '../../domain/entities/media_entity.dart';
import '../models/directory_preview.dart';

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

/// Selects the image or cached video thumbnail shown by a directory card.
final directoryPreviewProvider = FutureProvider.autoDispose
    .family<DirectoryPreview?, String>((ref, directoryPath) async {
      _configurePreviewProviderKeepAlive(ref);
      final fileService = ref.watch(fileServiceProvider);
      final diskCacheEnabled = ref.watch(thumbnailDiskCacheEnabledProvider);
      final thumbnailDiskCache = diskCacheEnabled
          ? ref.watch(thumbnailDiskCacheProvider)
          : null;

      try {
        final contents = await fileService.getDirectoryContents(directoryPath);
        final files = contents.whereType<File>().toList(growable: false);

        for (final file in files) {
          if (fileService.getMediaTypeFromExtension(file.path) == 'image') {
            return DirectoryImagePreview(sourcePath: file.path);
          }
        }

        if (thumbnailDiskCache == null) {
          return null;
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
            );
          }
        }
      } catch (_) {
        return null;
      }
      return null;
    });

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

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/utils/file_utils.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/utils/bookmark_resolver.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/media_id_utils.dart';
import '../../../thumbnails/data/thumbnail_disk_cache.dart';
import '../../../thumbnails/domain/thumbnail_request.dart';
import '../../../thumbnails/presentation/thumbnail_providers.dart';
import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../models/directory_preview.dart';
import 'directory_cover_providers.dart';
import 'directory_preview_catalog_invalidator.dart';

const Duration _previewProviderKeepAliveDuration = Duration(milliseconds: 500);
const int _directoryPreviewLimit = 5;
const int _videoProbeLimit = 50;

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

/// Identifies one directory catalog and the bookmark that directly covers it.
///
/// The value type has structural equality so equal queries share one
/// auto-disposed catalog rather than scanning the same directory repeatedly.
class DirectoryPreviewCatalogQuery {
  const DirectoryPreviewCatalogQuery({
    required this.directoryPath,
    this.bookmarkData,
  });

  final String directoryPath;
  final String? bookmarkData;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DirectoryPreviewCatalogQuery &&
            directoryPath == other.directoryPath &&
            bookmarkData == other.bookmarkData;
  }

  @override
  int get hashCode => Object.hash(directoryPath, bookmarkData);
}

/// Minimal bookmark access seam for catalog scans and focused tests.
abstract interface class DirectoryPreviewBookmarkAccess {
  Future<String> startAccessingBookmark(String bookmarkData);

  Future<void> stopAccessingBookmark(String bookmarkData);
}

class _DirectoryPreviewBookmarkServiceAccess
    implements DirectoryPreviewBookmarkAccess {
  const _DirectoryPreviewBookmarkServiceAccess(this._bookmarkService);

  final BookmarkService _bookmarkService;

  @override
  Future<String> startAccessingBookmark(String bookmarkData) {
    return _bookmarkService.startAccessingBookmark(bookmarkData);
  }

  @override
  Future<void> stopAccessingBookmark(String bookmarkData) {
    return _bookmarkService.stopAccessingBookmark(bookmarkData);
  }
}

final directoryPreviewBookmarkAccessProvider =
    Provider<DirectoryPreviewBookmarkAccess>((ref) {
      return _DirectoryPreviewBookmarkServiceAccess(
        ref.watch(bookmarkServiceProvider),
      );
    });

/// Resolves a directory's inherited bookmark from the deepest tracked root.
///
/// Security-scoped access only exists on Apple platforms. Avoiding the library
/// root lookup elsewhere keeps plain filesystem browsing cheap and makes the
/// provider a no-op on unsupported platforms.
final directoryPreviewInheritedBookmarkProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, directoryPath) async {
      if (!Platform.isMacOS && !Platform.isIOS) {
        return null;
      }
      final directories = await ref.watch(
        thumbnailLibraryDirectoriesProvider.future,
      );
      return resolveBookmarkForPath(directoryPath, directories);
    });

/// Resolves the shared, bounded preview catalog for a directory.
///
/// No preview image is decoded here. Automatic image entries are handed to the
/// existing thumbnail widgets later, while automatic videos are represented
/// only when a medium cached frame already exists. This prevents browsing from
/// starting video thumbnail generation.
final directoryPreviewCatalogProvider = FutureProvider.autoDispose
    .family<DirectoryPreviewCatalog, DirectoryPreviewCatalogQuery>((
      ref,
      query,
    ) async {
      _configurePreviewProviderKeepAlive(ref);
      ref.watch(directoryPreviewCatalogInvalidatorProvider);
      ref.watch(
        directoryPreviewCatalogPathRevisionProvider(query.directoryPath),
      );

      final customCover = await ref.watch(
        directoryCoverProvider(query.directoryPath).future,
      );
      if (customCover?.mode == DirectoryCoverMode.none) {
        return const DirectoryPreviewCatalog(previews: <DirectoryPreview>[]);
      }

      final diskCacheEnabled = ref.watch(thumbnailDiskCacheEnabledProvider);
      final thumbnailDiskCache = diskCacheEnabled
          ? ref.watch(thumbnailDiskCacheProvider)
          : null;
      final effectiveBookmarkData =
          query.bookmarkData ??
          await ref.watch(
            directoryPreviewInheritedBookmarkProvider(
              query.directoryPath,
            ).future,
          );

      final fileService = ref.watch(fileServiceProvider);
      return _withPreviewBookmarkScope(
        ref: ref,
        directoryPath: query.directoryPath,
        bookmarkData: effectiveBookmarkData,
        resolve: (scanTarget) async {
          final scan = await _scanDirectFiles(fileService, scanTarget);
          if (scan == null) {
            // A scan failure never proves a custom cover stale. Returning an
            // empty catalog makes a broken folder isolated from its neighbours.
            return const DirectoryPreviewCatalog(
              previews: <DirectoryPreview>[],
            );
          }

          final files = scan;
          final previews = <DirectoryPreview>[];
          final customSourcePaths = <String>{};
          final missingCustomCoverFileNames = <String>[];

          if (customCover?.mode == DirectoryCoverMode.media) {
            for (final selection in customCover!.selections) {
              final customFile = _findDirectChildByName(
                files,
                selection.sourceFileName,
              );
              if (customFile == null) {
                // Missing entries are only reported after [_scanDirectFiles]
                // succeeds. Inaccessible directories therefore retain every
                // persisted selection.
                missingCustomCoverFileNames.add(selection.sourceFileName);
                continue;
              }
              customSourcePaths.add(_normalizedSourcePath(customFile.path));
              final customPreview = await _createCustomPreview(
                file: customFile,
                fileService: fileService,
                mediaType: selection.mediaType,
                directoryPath: query.directoryPath,
                bookmarkData: effectiveBookmarkData,
              );
              if (customPreview != null) {
                previews.add(customPreview);
              }
            }
          }

          final hasStaleCustomCover = missingCustomCoverFileNames.isNotEmpty;
          for (final file in files) {
            if (previews.length >= _directoryPreviewLimit) {
              break;
            }
            if (customSourcePaths.contains(_normalizedSourcePath(file.path)) ||
                _mediaTypeForPath(fileService, file.path) != MediaType.image) {
              continue;
            }
            previews.add(
              DirectoryImagePreview(
                sourcePath: file.path,
                bookmarkData: effectiveBookmarkData,
                hasStaleCustomCover: hasStaleCustomCover,
              ),
            );
          }

          if (thumbnailDiskCache != null &&
              previews.length < _directoryPreviewLimit) {
            var probedVideos = 0;
            for (final file in files) {
              if (previews.length >= _directoryPreviewLimit ||
                  probedVideos >= _videoProbeLimit) {
                break;
              }
              if (customSourcePaths.contains(
                    _normalizedSourcePath(file.path),
                  ) ||
                  _mediaTypeForPath(fileService, file.path) !=
                      MediaType.video) {
                continue;
              }
              probedVideos += 1;
              final thumbnailPath = await _findCachedVideoThumbnail(
                file,
                thumbnailDiskCache,
                fileService: fileService,
                bookmarkData: effectiveBookmarkData,
              );
              if (thumbnailPath != null) {
                previews.add(
                  DirectoryVideoPreview(
                    sourcePath: file.path,
                    thumbnailPath: thumbnailPath,
                    bookmarkData: effectiveBookmarkData,
                    hasStaleCustomCover: hasStaleCustomCover,
                  ),
                );
              }
            }
          }

          return DirectoryPreviewCatalog(
            previews: List<DirectoryPreview>.unmodifiable(previews),
            missingCustomCoverFileNames: List<String>.unmodifiable(
              missingCustomCoverFileNames,
            ),
          );
        },
      );
    });

/// Selects the first preview for existing single-preview callers.
///
/// New code should consume [directoryPreviewCatalogProvider] so card, popup,
/// and carousel surfaces share a single resolution and ordering policy.
final directoryPreviewProvider = FutureProvider.autoDispose
    .family<DirectoryPreview?, String>((ref, directoryPath) async {
      final catalog = await ref.watch(
        directoryPreviewCatalogProvider(
          DirectoryPreviewCatalogQuery(directoryPath: directoryPath),
        ).future,
      );
      return catalog.primaryPreview ??
          (catalog.hasStaleCustomCover ? const DirectoryEmptyPreview() : null);
    });

/// Builds the legacy five-item hover strip from the shared catalog.
///
/// Retained until the strip is replaced by the interactive carousel. It no
/// longer scans separately, so cards and the Tags popup always agree.
final directoryPreviewStripProvider = FutureProvider.autoDispose
    .family<DirectoryPreviewResolutionList, String>((ref, directoryPath) async {
      final catalog = await ref.watch(
        directoryPreviewCatalogProvider(
          DirectoryPreviewCatalogQuery(directoryPath: directoryPath),
        ).future,
      );
      return DirectoryPreviewResolutionList(
        previews: catalog.previews,
        hasStaleCustomCover: catalog.hasStaleCustomCover,
      );
    });

/// Temporary compatibility value used by the pre-carousel Tags strip.
class DirectoryPreviewResolutionList {
  const DirectoryPreviewResolutionList({
    required this.previews,
    this.hasStaleCustomCover = false,
  });

  final List<DirectoryPreview> previews;
  final bool hasStaleCustomCover;
}

Future<T> _withPreviewBookmarkScope<T>({
  required Ref ref,
  required String directoryPath,
  required String? bookmarkData,
  required Future<T> Function(String scanTarget) resolve,
}) async {
  final bookmarkAccess = ref.read(directoryPreviewBookmarkAccessProvider);
  var startedAccess = false;
  var scanTarget = directoryPath;

  if (bookmarkData != null && bookmarkData.isNotEmpty) {
    try {
      final scopePath = await bookmarkAccess.startAccessingBookmark(
        bookmarkData,
      );
      startedAccess = true;
      scanTarget = resolveScanTarget(directoryPath, scopePath);
    } catch (_) {
      // Some scopes remain readable without a fresh start. Continue with the
      // stored path, but never report a stale custom cover on an eventual scan
      // failure.
    }
  }

  try {
    return await resolve(scanTarget);
  } finally {
    if (startedAccess) {
      try {
        await bookmarkAccess.stopAccessingBookmark(bookmarkData!);
      } catch (_) {
        // A failed cleanup must not discard a successfully resolved catalog.
      }
    }
  }
}

Future<List<File>?> _scanDirectFiles(
  FileService fileService,
  String directoryPath,
) async {
  try {
    final contents = await fileService.getDirectoryContents(directoryPath);
    final files = contents
        .whereType<File>()
        .where((file) => !isExcludedMediaFileName(p.basename(file.path)))
        .toList(growable: false);
    files.sort(_compareFilesByName);
    return files;
  } catch (_) {
    return null;
  }
}

int _compareFilesByName(File first, File second) {
  final firstName = p.basename(first.path);
  final secondName = p.basename(second.path);
  final insensitive = firstName.toLowerCase().compareTo(
    secondName.toLowerCase(),
  );
  return insensitive == 0 ? firstName.compareTo(secondName) : insensitive;
}

String _normalizedSourcePath(String sourcePath) {
  return p.normalize(sourcePath).toLowerCase();
}

File? _findDirectChildByName(List<File> files, String sourceFileName) {
  final expectedName = p.basename(sourceFileName).toLowerCase();
  for (final file in files) {
    if (p.basename(file.path).toLowerCase() == expectedName) {
      return file;
    }
  }
  return null;
}

MediaType? _mediaTypeForPath(FileService fileService, String path) {
  return switch (fileService.getMediaTypeFromExtension(path)) {
    'image' => MediaType.image,
    'video' => MediaType.video,
    _ => null,
  };
}

Future<DirectoryCustomPreview?> _createCustomPreview({
  required File file,
  required FileService fileService,
  required MediaType mediaType,
  required String directoryPath,
  required String? bookmarkData,
}) async {
  try {
    final stat = await fileService.getFileStat(file.path);
    if (stat.type != FileSystemEntityType.file) {
      return null;
    }
    final name = p.basename(file.path);
    return DirectoryCustomPreview(
      media: MediaEntity(
        id: generateMediaIdFromMetadata(
          size: stat.size,
          lastModified: stat.modified,
          fileName: name,
        ),
        path: file.path,
        name: name,
        type: mediaType,
        size: stat.size,
        lastModified: stat.modified,
        tagIds: const <String>[],
        directoryId: generateDirectoryId(directoryPath),
        bookmarkData: bookmarkData,
      ),
      bookmarkData: bookmarkData,
    );
  } catch (_) {
    // A corrupt or disappearing custom file must not fail the entire catalog.
    // Its presence still prevents a stale-cover cleanup; a later successful
    // scan can decide whether it has actually gone away.
    return null;
  }
}

Future<String?> _findCachedVideoThumbnail(
  File video,
  ThumbnailDiskCache thumbnailDiskCache, {
  required FileService fileService,
  required String? bookmarkData,
}) async {
  try {
    final stat = await fileService.getFileStat(video.path);
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
      bookmarkData: bookmarkData,
    );
    return (await thumbnailDiskCache.read(request))?.path;
  } catch (_) {
    // A cache problem or one unreadable video should not suppress subsequent
    // entries in the same directory.
    return null;
  }
}

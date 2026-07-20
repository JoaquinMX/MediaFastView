import 'package:path/path.dart' as p;

import '../../../favorites/domain/entities/favorite_item_type.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/repositories/tag_repository.dart';
import '../entities/sidecar_file_entry.dart';
import '../entities/sidecar_manifest.dart';
import '../entities/sidecar_result.dart';
import '../repositories/sidecar_repository.dart';

/// Writes the active profile's tags and favorites into per-folder
/// `.mediafastview.json` manifests.
///
/// Reads entirely from the cache (no disk scan): a folder's per-file tags come
/// from the media rows, folder-level tags from the tracked-root directory rows,
/// and favorites from the favorites store. Folders with nothing to record are
/// skipped so the library is never littered with empty manifests.
class ExportSidecarsUseCase {
  const ExportSidecarsUseCase({
    required this.mediaRepository,
    required this.directoryRepository,
    required this.favoritesRepository,
    required this.tagRepository,
    required this.sidecarRepository,
  });

  final MediaRepository mediaRepository;
  final DirectoryRepository directoryRepository;
  final FavoritesRepository favoritesRepository;
  final TagRepository tagRepository;
  final SidecarRepository sidecarRepository;

  Future<SidecarExportResult> call({
    void Function(int done, int total)? onProgress,
  }) async {
    final directories = await directoryRepository.getDirectories();
    if (directories.isEmpty) {
      return const SidecarExportResult();
    }

    final allMedia = await mediaRepository.getAllMedia();
    final favorites = await favoritesRepository.getFavorites();
    final tags = await tagRepository.getTags();

    final tagsById = <String, TagEntity>{for (final tag in tags) tag.id: tag};
    final favoriteMediaIds = <String>{
      for (final favorite in favorites)
        if (favorite.itemType == FavoriteItemType.media) favorite.itemId,
    };
    final favoriteDirectoryIds = <String>{
      for (final favorite in favorites)
        if (favorite.itemType == FavoriteItemType.directory) favorite.itemId,
    };

    // File media grouped by the folder they sit directly in. Directory-type
    // entries are excluded — folder-level tags come from the tracked-root rows.
    final mediaByFolder = <String, List<MediaEntity>>{};
    for (final media in allMedia) {
      if (media.type == MediaType.directory) {
        continue;
      }
      final folder = p.normalize(p.dirname(media.path));
      mediaByFolder.putIfAbsent(folder, () => <MediaEntity>[]).add(media);
    }

    final rootByFolder = <String, DirectoryEntity>{
      for (final directory in directories)
        p.normalize(directory.path): directory,
    };

    // Every folder that might carry a manifest: those with media, plus tracked
    // roots that have folder tags or are favorited.
    final candidateFolders = <String>{...mediaByFolder.keys};
    for (final directory in directories) {
      if (directory.tagIds.isNotEmpty ||
          favoriteDirectoryIds.contains(directory.id)) {
        candidateFolders.add(p.normalize(directory.path));
      }
    }

    final manifestsByFolder = <String, SidecarManifest>{};

    for (final folder in candidateFolders) {
      final vocab = <String, SidecarTagDef>{};
      final files = <String, SidecarFileEntry>{};

      for (final media in mediaByFolder[folder] ?? const <MediaEntity>[]) {
        final tagNames = <String>[];
        for (final tagId in media.tagIds) {
          final tag = tagsById[tagId];
          if (tag == null) {
            continue;
          }
          tagNames.add(tag.name);
          vocab[tag.name] = SidecarTagDef(color: tag.color);
        }
        final isFavorite = favoriteMediaIds.contains(media.id);
        if (tagNames.isEmpty && !isFavorite) {
          continue;
        }
        files[media.name] = SidecarFileEntry(
          size: media.size,
          mtimeMs: media.lastModified.millisecondsSinceEpoch,
          tags: tagNames,
          favorite: isFavorite,
        );
      }

      final root = rootByFolder[folder];
      final folderTagNames = <String>[];
      var folderFavorite = false;
      if (root != null) {
        for (final tagId in root.tagIds) {
          final tag = tagsById[tagId];
          if (tag == null) {
            continue;
          }
          folderTagNames.add(tag.name);
          vocab[tag.name] = SidecarTagDef(color: tag.color);
        }
        folderFavorite = favoriteDirectoryIds.contains(root.id);
      }

      final manifest = SidecarManifest(
        generatedAt: DateTime.now(),
        folderTags: folderTagNames,
        folderFavorite: folderFavorite,
        tags: vocab,
        files: files,
      );
      if (manifest.isEmpty) {
        continue;
      }
      manifestsByFolder[folder] = manifest;
    }

    // Assign each manifest folder to the deepest tracked root that can grant it
    // write access, and write per root so scope is opened once per root.
    final manifestsByRootId = <String, Map<String, SidecarManifest>>{};
    final rootsById = <String, DirectoryEntity>{};
    final failures = <String>[];
    for (final entry in manifestsByFolder.entries) {
      final root = _deepestRootCovering(entry.key, directories);
      if (root == null) {
        failures.add(entry.key);
        continue;
      }
      rootsById[root.id] = root;
      manifestsByRootId
          .putIfAbsent(root.id, () => <String, SidecarManifest>{})[entry.key] =
          entry.value;
    }

    final total = manifestsByFolder.length;
    var processed = 0;
    final writtenFolders = <String>[];
    var foldersSkippedMissing = 0;
    for (final rootEntry in manifestsByRootId.entries) {
      final root = rootsById[rootEntry.key]!;
      final report = await sidecarRepository.writeManifestsUnderRoot(
        root,
        rootEntry.value,
        onFolderProcessed: () {
          processed++;
          onProgress?.call(processed, total);
        },
      );
      writtenFolders.addAll(report.written);
      foldersSkippedMissing += report.missingFolders.length;
      failures.addAll(report.failures);
    }

    // Count only what actually reached disk, so the summary never claims a file
    // was saved when its folder was missing or its write failed.
    var filesCovered = 0;
    var favoritesCovered = 0;
    for (final folder in writtenFolders) {
      final manifest = manifestsByFolder[folder]!;
      filesCovered += manifest.files.length;
      favoritesCovered += _favoritesIn(manifest);
    }

    return SidecarExportResult(
      foldersWritten: writtenFolders.length,
      filesCovered: filesCovered,
      favoritesCovered: favoritesCovered,
      foldersSkippedMissing: foldersSkippedMissing,
      failures: failures,
    );
  }

  /// Number of favorite entries a manifest records: favorited files plus the
  /// folder itself when favorited.
  int _favoritesIn(SidecarManifest manifest) {
    final favoriteFiles =
        manifest.files.values.where((entry) => entry.favorite).length;
    return favoriteFiles + (manifest.folderFavorite ? 1 : 0);
  }

  /// The tracked root with a bookmark whose scope covers [folder], preferring
  /// the deepest (longest path) when roots are nested. Mirrors
  /// `resolveBookmarkForPath` but returns the entity so its scope can be reused.
  DirectoryEntity? _deepestRootCovering(
    String folder,
    List<DirectoryEntity> directories,
  ) {
    DirectoryEntity? best;
    for (final directory in directories) {
      if (directory.bookmarkData == null) {
        continue;
      }
      final covers = p.equals(directory.path, folder) ||
          p.isWithin(directory.path, folder);
      if (!covers) {
        continue;
      }
      if (best == null || directory.path.length > best.path.length) {
        best = directory;
      }
    }
    return best;
  }
}

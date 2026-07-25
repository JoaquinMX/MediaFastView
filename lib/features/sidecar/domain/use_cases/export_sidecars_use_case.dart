import 'package:path/path.dart' as p;

import '../../../favorites/domain/entities/favorite_item_type.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/repositories/tag_repository.dart';
import '../entities/sidecar_backup.dart';
import '../entities/sidecar_file_entry.dart';
import '../entities/sidecar_manifest.dart';
import '../entities/sidecar_result.dart';

/// Builds a portable backup of the active profile's tags and favorites.
///
/// The existing per-folder manifest shape remains embedded in the backup, while
/// library roots and root-relative folder paths make it possible to restore
/// from a separately selected file.
class ExportSidecarsUseCase {
  const ExportSidecarsUseCase({
    required this.mediaRepository,
    required this.directoryRepository,
    required this.favoritesRepository,
    required this.tagRepository,
  });

  final MediaRepository mediaRepository;
  final DirectoryRepository directoryRepository;
  final FavoritesRepository favoritesRepository;
  final TagRepository tagRepository;

  Future<SidecarExportPreparation> call({
    void Function(int done, int total)? onProgress,
  }) async {
    final directories = await directoryRepository.getDirectories();
    if (directories.isEmpty) {
      return SidecarExportPreparation(
        backup: SidecarBackup(generatedAt: DateTime.now()),
        result: const SidecarExportResult(),
      );
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

    final generatedAt = DateTime.now();
    final manifestsByFolder = <String, SidecarManifest>{};
    final sortedCandidateFolders = candidateFolders.toList()..sort();
    var processed = 0;

    for (final folder in sortedCandidateFolders) {
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
        generatedAt: generatedAt,
        folderTags: folderTagNames,
        folderFavorite: folderFavorite,
        tags: vocab,
        files: files,
      );
      if (manifest.isEmpty) {
        processed++;
        onProgress?.call(processed, sortedCandidateFolders.length);
        continue;
      }
      manifestsByFolder[folder] = manifest;
      processed++;
      onProgress?.call(processed, sortedCandidateFolders.length);
    }

    // Assign each manifest folder to the deepest tracked root and store a
    // root-relative path. No media-root filesystem access is needed to create a
    // metadata-only backup, so stale cached entries remain recoverable.
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
      final relativeFolder = p.relative(entry.key, from: root.path);
      final portableRelativeFolder = relativeFolder == '.'
          ? '.'
          : relativeFolder.split(p.separator).join('/');
      manifestsByRootId.putIfAbsent(
        root.id,
        () => <String, SidecarManifest>{},
      )[portableRelativeFolder] = entry.value;
    }

    final backupRoots = <SidecarBackupRoot>[
      for (final entry in manifestsByRootId.entries)
        SidecarBackupRoot(
          originalPath: rootsById[entry.key]!.path,
          name: rootsById[entry.key]!.name,
          manifestsByRelativeFolder: entry.value,
        ),
    ];

    // Count only manifests that made it into a saved-root record.
    final embeddedManifests = <SidecarManifest>[
      for (final root in backupRoots) ...root.manifestsByRelativeFolder.values,
    ];
    final filesCovered = embeddedManifests.fold<int>(
      0,
      (count, manifest) => count + manifest.files.length,
    );
    final favoritesCovered = embeddedManifests.fold<int>(
      0,
      (count, manifest) => count + _favoritesIn(manifest),
    );

    return SidecarExportPreparation(
      backup: SidecarBackup(generatedAt: generatedAt, roots: backupRoots),
      result: SidecarExportResult(
        rootsSaved: backupRoots.length,
        manifestsSaved: embeddedManifests.length,
        filesCovered: filesCovered,
        favoritesCovered: favoritesCovered,
        failures: failures,
      ),
    );
  }

  /// Number of favorite entries a manifest records: favorited files plus the
  /// folder itself when favorited.
  int _favoritesIn(SidecarManifest manifest) {
    final favoriteFiles = manifest.files.values
        .where((entry) => entry.favorite)
        .length;
    return favoriteFiles + (manifest.folderFavorite ? 1 : 0);
  }

  /// The tracked root covering [folder], preferring the deepest nested root.
  DirectoryEntity? _deepestRootCovering(
    String folder,
    List<DirectoryEntity> directories,
  ) {
    DirectoryEntity? best;
    for (final directory in directories) {
      final covers =
          p.equals(directory.path, folder) ||
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

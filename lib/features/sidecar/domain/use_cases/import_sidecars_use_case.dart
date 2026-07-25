import 'package:path/path.dart' as p;

import '../../../../core/services/file_service.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/media_id_utils.dart';
import '../../../favorites/domain/entities/favorite_entity.dart';
import '../../../favorites/domain/entities/favorite_item_type.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/repositories/tag_repository.dart';
import '../../../tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../../tagging/domain/use_cases/create_tag_use_case.dart';
import '../entities/sidecar_backup.dart';
import '../entities/sidecar_folder_data.dart';
import '../entities/sidecar_import_preparation.dart';
import '../entities/sidecar_result.dart';
import '../repositories/sidecar_repository.dart';

/// Resolves a file path to the media type the app would assign it, or null when
/// the extension is unsupported. Injectable for testing.
typedef MediaTypeResolver = MediaType? Function(String path);

/// Restores a portable sidecar backup into the active profile.
///
/// Import remains additive: tags are matched by name, assignments are unioned,
/// and favorites are restored without deleting existing profile data.
class ImportSidecarsUseCase {
  ImportSidecarsUseCase({
    required this.directoryRepository,
    required this.mediaRepository,
    required this.favoritesRepository,
    required this.tagRepository,
    required this.createTagUseCase,
    required this.assignTagUseCase,
    required this.sidecarRepository,
    MediaTypeResolver? mediaTypeResolver,
  }) : mediaTypeResolver = mediaTypeResolver ?? _defaultMediaTypeResolver;

  final DirectoryRepository directoryRepository;
  final MediaRepository mediaRepository;
  final FavoritesRepository favoritesRepository;
  final TagRepository tagRepository;
  final CreateTagUseCase createTagUseCase;
  final AssignTagUseCase assignTagUseCase;
  final SidecarRepository sidecarRepository;
  final MediaTypeResolver mediaTypeResolver;

  static const int _defaultTagColor = 0xFF9E9E9E;

  /// Matches unchanged saved roots and identifies roots requiring user mapping.
  Future<SidecarImportPreparation> prepare(SidecarBackup backup) async {
    final currentRoots = await directoryRepository.getDirectories();
    final automaticMappings = <String, String>{};
    final unmatchedRoots = <SidecarBackupRoot>[];
    final usedCurrentRootIds = <String>{};

    for (final savedRoot in backup.roots) {
      DirectoryEntity? match;
      for (final currentRoot in currentRoots) {
        if (!usedCurrentRootIds.contains(currentRoot.id) &&
            p.equals(savedRoot.originalPath, currentRoot.path)) {
          match = currentRoot;
          break;
        }
      }
      if (match == null) {
        unmatchedRoots.add(savedRoot);
      } else {
        automaticMappings[savedRoot.originalPath] = match.id;
        usedCurrentRootIds.add(match.id);
      }
    }

    return SidecarImportPreparation(
      backup: backup,
      currentRoots: currentRoots,
      automaticRootMappings: automaticMappings,
      unmatchedRoots: unmatchedRoots,
    );
  }

  Future<SidecarImportResult> call({
    required SidecarBackup backup,
    required Map<String, String?> rootMappings,
    void Function(int done, int total)? onProgress,
  }) async {
    final directories = await directoryRepository.getDirectories();
    final currentRootsById = <String, DirectoryEntity>{
      for (final directory in directories) directory.id: directory,
    };
    _validateMappings(backup, rootMappings, currentRootsById);

    final folderDataByPath = <String, SidecarFolderData>{};
    final failures = <String>[];
    final total = backup.manifestCount;
    var processed = 0;
    var rootsSkipped = 0;

    void advanceProgress([int amount = 1]) {
      processed += amount;
      onProgress?.call(processed, total);
    }

    for (final savedRoot in backup.roots) {
      final currentRootId = rootMappings[savedRoot.originalPath];
      if (currentRootId == null) {
        rootsSkipped++;
        advanceProgress(savedRoot.manifestsByRelativeFolder.length);
        continue;
      }

      final currentRoot = currentRootsById[currentRootId];
      if (currentRoot == null) {
        failures.add(savedRoot.originalPath);
        advanceProgress(savedRoot.manifestsByRelativeFolder.length);
        continue;
      }

      var rootProcessed = 0;
      try {
        final report = await sidecarRepository.resolveBackupRoot(
          savedRoot,
          currentRoot,
          onFolderProcessed: () {
            rootProcessed++;
            advanceProgress();
          },
        );
        failures.addAll(report.failures);
        for (final data in report.folders) {
          folderDataByPath.putIfAbsent(
            p.normalize(data.folderPath),
            () => data,
          );
        }
      } catch (error) {
        LoggingService.instance.warning(
          '[Sidecar] Failed to access mapped root "${currentRoot.path}": $error',
        );
        failures.add(currentRoot.path);
        advanceProgress(
          savedRoot.manifestsByRelativeFolder.length - rootProcessed,
        );
      }
    }

    if (folderDataByPath.isEmpty) {
      return SidecarImportResult(
        rootsSkipped: rootsSkipped,
        failures: failures,
      );
    }

    final existingTags = await tagRepository.getTags();
    final tagByName = <String, TagEntity>{
      for (final tag in existingTags) tag.name.trim().toLowerCase(): tag,
    };

    final allMedia = await mediaRepository.getAllMedia();
    final currentTagIdsByMedia = <String, Set<String>>{
      for (final media in allMedia) media.id: media.tagIds.toSet(),
    };
    final existingMediaById = <String, MediaEntity>{
      for (final media in allMedia) media.id: media,
    };
    final rootByFolder = <String, DirectoryEntity>{
      for (final directory in directories)
        p.normalize(directory.path): directory,
    };

    final now = DateTime.now();
    var tagsCreated = 0;
    var filesLinked = 0;
    var filesNotFound = 0;
    var favoritesApplied = 0;
    final mediaToUpsert = <MediaEntity>[];
    final favoritesToAdd = <FavoriteEntity>[];
    final directoryTagAssignments = <String, List<String>>{};

    Future<String?> resolveTagId(String name, int color) async {
      final key = name.trim().toLowerCase();
      if (key.isEmpty) {
        return null;
      }
      final existing = tagByName[key];
      if (existing != null) {
        return existing.id;
      }
      try {
        final created = await createTagUseCase.createTag(
          name: name.trim(),
          color: color,
        );
        tagByName[key] = created;
        tagsCreated++;
        return created.id;
      } catch (error) {
        LoggingService.instance.warning(
          '[Sidecar] Skipping tag "$name": $error',
        );
        return null;
      }
    }

    for (final data in folderDataByPath.values) {
      final manifest = data.manifest;
      filesNotFound += data.missingFileNames.length;

      for (final entry in manifest.files.entries) {
        final fileName = entry.key;
        final fileEntry = entry.value;
        final stat = data.liveStats[fileName];
        if (stat == null) {
          continue;
        }

        final filePath = p.join(data.folderPath, fileName);
        final mediaType = mediaTypeResolver(filePath);
        if (mediaType == null) {
          continue;
        }

        final lastModified = DateTime.fromMillisecondsSinceEpoch(stat.mtimeMs);
        final mediaId = generateMediaIdFromMetadata(
          size: stat.size,
          lastModified: lastModified,
          fileName: fileName,
        );

        final tagIds = <String>{...?currentTagIdsByMedia[mediaId]};
        for (final tagName in fileEntry.tags) {
          final color = manifest.tags[tagName]?.color ?? _defaultTagColor;
          final id = await resolveTagId(tagName, color);
          if (id != null) {
            tagIds.add(id);
          }
        }

        final existing = existingMediaById[mediaId];
        mediaToUpsert.add(
          MediaEntity(
            id: mediaId,
            path: filePath,
            name: fileName,
            type: mediaType,
            size: stat.size,
            lastModified: lastModified,
            tagIds: tagIds.toList(),
            directoryId:
                existing?.directoryId ?? generateDirectoryId(data.folderPath),
            bookmarkData: existing?.bookmarkData,
          ),
        );
        filesLinked++;

        if (fileEntry.favorite) {
          favoritesToAdd.add(
            FavoriteEntity(
              itemId: mediaId,
              itemType: FavoriteItemType.media,
              addedAt: now,
            ),
          );
        }
      }

      final root = rootByFolder[p.normalize(data.folderPath)];
      if (root != null &&
          (manifest.folderTags.isNotEmpty || manifest.folderFavorite)) {
        if (manifest.folderTags.isNotEmpty) {
          final tagIds = <String>{...root.tagIds};
          for (final tagName in manifest.folderTags) {
            final color = manifest.tags[tagName]?.color ?? _defaultTagColor;
            final id = await resolveTagId(tagName, color);
            if (id != null) {
              tagIds.add(id);
            }
          }
          directoryTagAssignments[root.id] = tagIds.toList();
        }
        if (manifest.folderFavorite) {
          favoritesToAdd.add(
            FavoriteEntity(
              itemId: root.id,
              itemType: FavoriteItemType.directory,
              addedAt: now,
            ),
          );
        }
      }
    }

    if (mediaToUpsert.isNotEmpty) {
      await mediaRepository.upsertMedia(mediaToUpsert);
    }
    for (final entry in directoryTagAssignments.entries) {
      await assignTagUseCase.setTagsForDirectory(entry.key, entry.value);
    }
    if (favoritesToAdd.isNotEmpty) {
      await favoritesRepository.addFavorites(favoritesToAdd);
      favoritesApplied = favoritesToAdd.length;
    }

    return SidecarImportResult(
      manifestsRead: folderDataByPath.length,
      filesLinked: filesLinked,
      tagsCreated: tagsCreated,
      favoritesApplied: favoritesApplied,
      filesNotFound: filesNotFound,
      rootsSkipped: rootsSkipped,
      failures: failures,
    );
  }

  void _validateMappings(
    SidecarBackup backup,
    Map<String, String?> rootMappings,
    Map<String, DirectoryEntity> currentRootsById,
  ) {
    final usedCurrentRootIds = <String>{};
    for (final savedRoot in backup.roots) {
      if (!rootMappings.containsKey(savedRoot.originalPath)) {
        throw ArgumentError(
          'Missing mapping for saved root ${savedRoot.originalPath}.',
        );
      }
      final currentRootId = rootMappings[savedRoot.originalPath];
      if (currentRootId == null) {
        continue;
      }
      if (!currentRootsById.containsKey(currentRootId)) {
        throw ArgumentError('Mapped library root is no longer available.');
      }
      if (!usedCurrentRootIds.add(currentRootId)) {
        throw ArgumentError(
          'Each current library root can be mapped only once.',
        );
      }
    }
  }
}

MediaType? _defaultMediaTypeResolver(String path) {
  switch (FileService().getMediaTypeFromExtension(path)) {
    case 'image':
      return MediaType.image;
    case 'video':
      return MediaType.video;
    case 'audio':
      return MediaType.audio;
    case 'text':
      return MediaType.text;
    default:
      return null;
  }
}

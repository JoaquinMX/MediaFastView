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
import '../entities/sidecar_folder_data.dart';
import '../entities/sidecar_result.dart';
import '../repositories/sidecar_repository.dart';

/// Resolves a file path to the media type the app would assign it, or null when
/// the extension is not a supported media type. Injectable for testing.
typedef MediaTypeResolver = MediaType? Function(String path);

/// Reads per-folder `.mediafastview.json` manifests back into the active profile.
///
/// The merge is strictly additive: tags are matched to existing profile tags by
/// name (creating any that are missing), assignments are unioned onto whatever a
/// file already carries, and favorites are restored. Each file is re-linked by
/// recomputing the scanner's media id from its **live** size/mtime/name, so the
/// import works even against an empty cache (e.g. right after "Clear cache").
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

  /// Colour used for a tag a manifest references but does not define.
  static const int _defaultTagColor = 0xFF9E9E9E;

  Future<SidecarImportResult> call({
    void Function(int done, int total)? onProgress,
  }) async {
    final directories = await directoryRepository.getDirectories();
    if (directories.isEmpty) {
      return const SidecarImportResult();
    }

    // Read every manifest across all roots, deduped by folder (nested roots can
    // surface the same subtree twice).
    final folderDataByPath = <String, SidecarFolderData>{};
    for (final root in directories) {
      final datas = await sidecarRepository.readManifestsUnderRoot(root);
      for (final data in datas) {
        folderDataByPath.putIfAbsent(
          p.normalize(data.folderPath),
          () => data,
        );
      }
    }
    if (folderDataByPath.isEmpty) {
      return const SidecarImportResult();
    }

    // Existing profile tags, indexed by normalized name for find-or-create.
    final existingTags = await tagRepository.getTags();
    final tagByName = <String, TagEntity>{
      for (final tag in existingTags) tag.name.trim().toLowerCase(): tag,
    };

    // Current per-media tags (this profile), so assignments union rather than
    // replace. Empty after a cache clear, which is fine — union with nothing.
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
    final failures = <String>[];

    final mediaToUpsert = <MediaEntity>[];
    final favoritesToAdd = <FavoriteEntity>[];
    final directoryTagAssignments = <String, List<String>>{};

    // Resolves a tag name to an id in the active profile, creating it (with the
    // manifest's colour) when absent. Returns null for an invalid/rejected name.
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
        final created =
            await createTagUseCase.createTag(name: name.trim(), color: color);
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

    final total = folderDataByPath.length;
    var processed = 0;

    for (final data in folderDataByPath.values) {
      final manifest = data.manifest;
      filesNotFound += data.missingFileNames.length;

      for (final entry in manifest.files.entries) {
        final fileName = entry.key;
        final fileEntry = entry.value;
        final stat = data.liveStats[fileName];
        if (stat == null) {
          continue; // Already counted in missingFileNames.
        }

        final filePath = p.join(data.folderPath, fileName);
        final mediaType = mediaTypeResolver(filePath);
        if (mediaType == null) {
          continue; // Not a media type the app can represent.
        }

        final lastModified =
            DateTime.fromMillisecondsSinceEpoch(stat.mtimeMs);
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

      // Folder-level tags/favorite apply only to tracked roots (the only folders
      // that carry a directory row); subfolders never export folder tags.
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

      processed++;
      onProgress?.call(processed, total);
    }

    // Apply. Upsert creates missing media rows and merges tags while preserving
    // other profiles' assignments; directory tags and favorites go through their
    // own merge-aware paths.
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
      failures: failures,
    );
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

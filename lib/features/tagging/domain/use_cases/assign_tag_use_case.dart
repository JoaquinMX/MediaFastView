import 'dart:collection';

import 'package:path/path.dart' as p;

import '../../../../core/utils/batch_update_result.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../entities/tag_entity.dart';

/// Use case for assigning tags to directories and media items.
/// Handles the business logic for tag assignment operations.
class AssignTagUseCase {
  const AssignTagUseCase({
    required this.directoryRepository,
    required this.mediaRepository,
  });

  final DirectoryRepository directoryRepository;
  final MediaRepository mediaRepository;

  /// Replaces the tags assigned to a directory with the provided collection.
  ///
  /// The [tagIds] list will be de-duplicated while keeping the first
  /// occurrence of each identifier so the repository only persists meaningful
  /// updates.
  Future<void> setTagsForDirectory(
    String directoryId,
    List<String> tagIds, {
    bool applyToMediaRecursively = false,
  }) async {
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory == null) {
      return;
    }

    final sanitizedTagIds =
        List<String>.unmodifiable(LinkedHashSet<String>.from(tagIds));
    await directoryRepository.updateDirectoryTags(
      directoryId,
      sanitizedTagIds,
    );

    if (applyToMediaRecursively) {
      await _applyTagsToMediaRecursively(
        directories: [directory],
        tagIds: sanitizedTagIds,
      );
    }
  }

  /// Replaces the tags assigned to multiple directories.
  Future<BatchUpdateResult> setTagsForDirectories(
    List<String> directoryIds,
    List<String> tagIds, {
    bool applyToMediaRecursively = false,
  }) async {
    if (directoryIds.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final sanitizedTagIds =
        List<String>.unmodifiable(LinkedHashSet<String>.from(tagIds));
    final sanitizedDirectoryIds = LinkedHashSet<String>.from(
      directoryIds.where((id) => id.isNotEmpty),
    );

    if (sanitizedDirectoryIds.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final payload = {
      for (final directoryId in sanitizedDirectoryIds)
        directoryId: sanitizedTagIds,
    };

    final result = await directoryRepository.updateDirectoryTagsBatch(payload);

    if (applyToMediaRecursively && result.successfulIds.isNotEmpty) {
      final directories = await directoryRepository.getDirectories();
      final updatedDirectories = directories
          .where((dir) => result.successfulIds.contains(dir.id))
          .toList();
      await _applyTagsToMediaRecursively(
        directories: updatedDirectories,
        tagIds: sanitizedTagIds,
      );
    }

    return result;
  }

  /// Assigns a tag to a directory.
  Future<void> assignTagToDirectory(String directoryId, TagEntity tag) async {
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory != null && !directory.tagIds.contains(tag.id)) {
      final updatedTagIds = [...directory.tagIds, tag.id];
      await directoryRepository.updateDirectoryTags(directoryId, updatedTagIds);
    }
  }

  /// Removes a tag from a directory.
  Future<void> removeTagFromDirectory(String directoryId, TagEntity tag) async {
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory != null) {
      final updatedTagIds = directory.tagIds
          .where((id) => id != tag.id)
          .toList();
      await directoryRepository.updateDirectoryTags(directoryId, updatedTagIds);
    }
  }

  /// Assigns a tag to a media item.
  Future<void> assignTagToMedia(String mediaId, TagEntity tag) async {
    final media = await mediaRepository.getMediaById(mediaId);
    if (media != null && !media.tagIds.contains(tag.id)) {
      final updatedTagIds = [...media.tagIds, tag.id];
      await mediaRepository.updateMediaTags(mediaId, updatedTagIds);
    }
  }

  /// Removes a tag from a media item.
  Future<void> removeTagFromMedia(String mediaId, TagEntity tag) async {
    final media = await mediaRepository.getMediaById(mediaId);
    if (media != null) {
      final updatedTagIds = media.tagIds.where((id) => id != tag.id).toList();
      await mediaRepository.updateMediaTags(mediaId, updatedTagIds);
    }
  }

  /// Replaces the tags assigned to multiple media items.
  Future<BatchUpdateResult> setTagsForMedia(
    List<String> mediaIds,
    List<String> tagIds,
  ) async {
    if (mediaIds.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final sanitizedTagIds =
        List<String>.unmodifiable(LinkedHashSet<String>.from(tagIds));
    final sanitizedMediaIds = LinkedHashSet<String>.from(
      mediaIds.where((id) => id.isNotEmpty),
    );

    if (sanitizedMediaIds.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final payload = {
      for (final mediaId in sanitizedMediaIds) mediaId: sanitizedTagIds,
    };

    return mediaRepository.updateMediaTagsBatch(payload);
  }

  /// Toggles a tag on a directory (adds if not present, removes if present).
  Future<void> toggleTagOnDirectory(String directoryId, TagEntity tag) async {
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory != null) {
      if (directory.tagIds.contains(tag.id)) {
        await removeTagFromDirectory(directoryId, tag);
      } else {
        await assignTagToDirectory(directoryId, tag);
      }
    }
  }

  /// Toggles a tag on a media item (adds if not present, removes if present).
  Future<void> toggleTagOnMedia(String mediaId, TagEntity tag) async {
    final media = await mediaRepository.getMediaById(mediaId);
    if (media != null) {
      if (media.tagIds.contains(tag.id)) {
        await removeTagFromMedia(mediaId, tag);
      } else {
        await assignTagToMedia(mediaId, tag);
      }
    }
  }

  Future<void> _applyTagsToMediaRecursively({
    required List<DirectoryEntity> directories,
    required List<String> tagIds,
  }) async {
    if (directories.isEmpty || tagIds.isEmpty) {
      return;
    }

    final directoryIds = await _expandDirectoryIdsRecursively(directories);
    if (directoryIds.isEmpty) {
      return;
    }

    final media = await mediaRepository.getAllMedia();
    final payload = <String, List<String>>{};

    for (final item in media) {
      if (!directoryIds.contains(item.directoryId)) {
        continue;
      }

      final mergedTags = LinkedHashSet<String>.from(item.tagIds)..addAll(tagIds);
      payload[item.id] = List<String>.unmodifiable(mergedTags);
    }

    if (payload.isNotEmpty) {
      await mediaRepository.updateMediaTagsBatch(payload);
    }
  }

  Future<Set<String>> _expandDirectoryIdsRecursively(
    List<DirectoryEntity> roots,
  ) async {
    if (roots.isEmpty) {
      return <String>{};
    }

    final normalizedRoots = roots
        .map((dir) => (id: dir.id, path: _normalizePath(dir.path)))
        .toList(growable: false);

    final allDirectories = await directoryRepository.getDirectories();
    final expanded = <String>{};

    for (final directory in allDirectories) {
      final normalizedPath = _normalizePath(directory.path);
      final isWithinRoot = normalizedRoots.any(
        (root) =>
            p.equals(root.path, normalizedPath) ||
            p.isWithin(root.path, normalizedPath),
      );

      if (isWithinRoot) {
        expanded.add(directory.id);
      }
    }

    return expanded;
  }

  String _normalizePath(String path) => p.normalize(path.trim());
}

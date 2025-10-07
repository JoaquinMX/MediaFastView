import 'dart:collection';

import '../../../../core/services/logging_service.dart';
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
    List<String> tagIds,
  ) async {
    LoggingService.instance.info(
      'AssignTagUseCase.setTagsForDirectory invoked',
      {
        'directoryId': directoryId,
        'incomingTagIds': tagIds,
      },
    );
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory == null) {
      LoggingService.instance.warning(
        'Directory not found when setting tags',
        {'directoryId': directoryId},
      );
      return;
    }

    final sanitizedTagIds =
        List<String>.unmodifiable(LinkedHashSet<String>.from(tagIds));
    LoggingService.instance.debug(
      'Persisting sanitized directory tag assignments',
      {
        'directoryId': directoryId,
        'sanitizedTagIds': sanitizedTagIds,
      },
    );
    await directoryRepository.updateDirectoryTags(
      directoryId,
      sanitizedTagIds,
    );
  }

  /// Assigns a tag to a directory.
  Future<void> assignTagToDirectory(String directoryId, TagEntity tag) async {
    LoggingService.instance.debug(
      'Assigning tag to directory',
      {
        'directoryId': directoryId,
        'tagId': tag.id,
      },
    );
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory != null && !directory.tagIds.contains(tag.id)) {
      final updatedTagIds = [...directory.tagIds, tag.id];
      await directoryRepository.updateDirectoryTags(directoryId, updatedTagIds);
      LoggingService.instance.info(
        'Tag assigned to directory',
        {
          'directoryId': directoryId,
          'tagId': tag.id,
          'updatedTagIds': updatedTagIds,
        },
      );
    } else {
      LoggingService.instance.debug(
        'Skipping directory tag assignment (directory missing or already tagged)',
        {
          'directoryId': directoryId,
          'tagId': tag.id,
          'directoryFound': directory != null,
        },
      );
    }
  }

  /// Removes a tag from a directory.
  Future<void> removeTagFromDirectory(String directoryId, TagEntity tag) async {
    LoggingService.instance.debug(
      'Removing tag from directory',
      {
        'directoryId': directoryId,
        'tagId': tag.id,
      },
    );
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory != null) {
      final updatedTagIds = directory.tagIds
          .where((id) => id != tag.id)
          .toList();
      await directoryRepository.updateDirectoryTags(directoryId, updatedTagIds);
      LoggingService.instance.info(
        'Tag removed from directory',
        {
          'directoryId': directoryId,
          'tagId': tag.id,
          'updatedTagIds': updatedTagIds,
        },
      );
    } else {
      LoggingService.instance.warning(
        'Attempted to remove tag from missing directory',
        {
          'directoryId': directoryId,
          'tagId': tag.id,
        },
      );
    }
  }

  /// Assigns a tag to a media item.
  Future<void> assignTagToMedia(String mediaId, TagEntity tag) async {
    LoggingService.instance.debug(
      'Assigning tag to media',
      {
        'mediaId': mediaId,
        'tagId': tag.id,
      },
    );
    final media = await mediaRepository.getMediaById(mediaId);
    if (media != null && !media.tagIds.contains(tag.id)) {
      final updatedTagIds = [...media.tagIds, tag.id];
      await mediaRepository.updateMediaTags(mediaId, updatedTagIds);
      LoggingService.instance.info(
        'Tag assigned to media',
        {
          'mediaId': mediaId,
          'tagId': tag.id,
          'updatedTagIds': updatedTagIds,
        },
      );
    } else {
      LoggingService.instance.debug(
        'Skipping media tag assignment (media missing or already tagged)',
        {
          'mediaId': mediaId,
          'tagId': tag.id,
          'mediaFound': media != null,
        },
      );
    }
  }

  /// Removes a tag from a media item.
  Future<void> removeTagFromMedia(String mediaId, TagEntity tag) async {
    LoggingService.instance.debug(
      'Removing tag from media',
      {
        'mediaId': mediaId,
        'tagId': tag.id,
      },
    );
    final media = await mediaRepository.getMediaById(mediaId);
    if (media != null) {
      final updatedTagIds = media.tagIds.where((id) => id != tag.id).toList();
      await mediaRepository.updateMediaTags(mediaId, updatedTagIds);
      LoggingService.instance.info(
        'Tag removed from media',
        {
          'mediaId': mediaId,
          'tagId': tag.id,
          'updatedTagIds': updatedTagIds,
        },
      );
    } else {
      LoggingService.instance.warning(
        'Attempted to remove tag from missing media',
        {
          'mediaId': mediaId,
          'tagId': tag.id,
        },
      );
    }
  }

  /// Toggles a tag on a directory (adds if not present, removes if present).
  Future<void> toggleTagOnDirectory(String directoryId, TagEntity tag) async {
    LoggingService.instance.debug(
      'Toggling directory tag',
      {
        'directoryId': directoryId,
        'tagId': tag.id,
      },
    );
    final directory = await directoryRepository.getDirectoryById(directoryId);
    if (directory != null) {
      if (directory.tagIds.contains(tag.id)) {
        await removeTagFromDirectory(directoryId, tag);
      } else {
        await assignTagToDirectory(directoryId, tag);
      }
    } else {
      LoggingService.instance.warning(
        'Cannot toggle tag on missing directory',
        {
          'directoryId': directoryId,
          'tagId': tag.id,
        },
      );
    }
  }

  /// Toggles a tag on a media item (adds if not present, removes if present).
  Future<void> toggleTagOnMedia(String mediaId, TagEntity tag) async {
    LoggingService.instance.debug(
      'Toggling media tag',
      {
        'mediaId': mediaId,
        'tagId': tag.id,
      },
    );
    final media = await mediaRepository.getMediaById(mediaId);
    if (media != null) {
      if (media.tagIds.contains(tag.id)) {
        await removeTagFromMedia(mediaId, tag);
      } else {
        await assignTagToMedia(mediaId, tag);
      }
    } else {
      LoggingService.instance.warning(
        'Cannot toggle tag on missing media',
        {
          'mediaId': mediaId,
          'tagId': tag.id,
        },
      );
    }
  }
}

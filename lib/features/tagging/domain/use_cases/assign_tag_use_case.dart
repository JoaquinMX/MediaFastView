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
}

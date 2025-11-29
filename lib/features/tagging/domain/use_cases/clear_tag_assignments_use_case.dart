import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';

/// Use case for removing tag assignments from all directories and media items.
class ClearTagAssignmentsUseCase {
  const ClearTagAssignmentsUseCase({
    required this.directoryRepository,
    required this.mediaRepository,
  });

  final DirectoryRepository directoryRepository;
  final MediaRepository mediaRepository;

  /// Clears all tag assignments while leaving tag definitions intact.
  Future<void> call() async {
    final directories = await directoryRepository.getDirectories();
    if (directories.isNotEmpty) {
      final directoryPayload = {
        for (final directory in directories) directory.id: const <String>[],
      };
      await directoryRepository.updateDirectoryTagsBatch(directoryPayload);
    }

    final mediaItems = await mediaRepository.getAllMedia();
    if (mediaItems.isEmpty) {
      return;
    }

    final mediaPayload = <String, List<String>>{};
    for (final media in mediaItems) {
      if (media.tagIds.isNotEmpty) {
        mediaPayload[media.id] = const <String>[];
      }
    }

    if (mediaPayload.isNotEmpty) {
      await mediaRepository.updateMediaTagsBatch(mediaPayload);
    }
  }
}

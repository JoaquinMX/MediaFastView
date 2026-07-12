import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../entities/tag_entity.dart';
import '../entities/tag_usage.dart';
import '../repositories/tag_repository.dart';

/// Counts how many files and folders carry each tag.
///
/// Tallies every tag in **one pass** over the library rather than querying per
/// tag: `filterMediaByTags([tagId])` in a loop would be N round trips for N
/// tags, and the caller (the Manage Tags list) always wants all of them at once.
class GetTagUsageUseCase {
  const GetTagUsageUseCase({
    required TagRepository tagRepository,
    required MediaRepository mediaRepository,
    required DirectoryRepository directoryRepository,
  })  : _tagRepository = tagRepository,
        _mediaRepository = mediaRepository,
        _directoryRepository = directoryRepository;

  final TagRepository _tagRepository;
  final MediaRepository _mediaRepository;
  final DirectoryRepository _directoryRepository;

  /// Usage for every known tag, keyed by tag id.
  ///
  /// Tags nothing references come back as [TagUsage.none] rather than missing,
  /// so the UI can say "Unused" instead of showing nothing.
  Future<Map<String, TagUsage>> call() async {
    final List<TagEntity> tags = await _tagRepository.getTags();
    final List<MediaEntity> media = await _mediaRepository.getAllMedia();
    final List<DirectoryEntity> directories =
        await _directoryRepository.getDirectories();

    final usage = <String, TagUsage>{
      for (final tag in tags) tag.id: TagUsage.none,
    };

    void tally(String tagId, {required bool isDirectory}) {
      // Only count against tags that still exist. An id left on an item by a tag
      // that has since been deleted would otherwise invent a row nothing can act
      // on.
      final current = usage[tagId];
      if (current == null) {
        return;
      }
      usage[tagId] = isDirectory
          ? current.copyWith(directoryCount: current.directoryCount + 1)
          : current.copyWith(mediaCount: current.mediaCount + 1);
    }

    for (final item in media) {
      for (final tagId in item.tagIds) {
        tally(tagId, isDirectory: false);
      }
    }
    for (final directory in directories) {
      for (final tagId in directory.tagIds) {
        tally(tagId, isDirectory: true);
      }
    }

    return usage;
  }
}

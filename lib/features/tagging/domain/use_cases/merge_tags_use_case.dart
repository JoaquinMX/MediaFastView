import 'dart:collection';

import '../../../../core/utils/batch_update_result.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../entities/tag_entity.dart';
import '../repositories/tag_repository.dart';
import '../tag_validation.dart';

/// What a merge moved, and what it could not.
class TagMergeResult {
  const TagMergeResult({
    required this.mediaMoved,
    required this.directoriesMoved,
    this.failureReasons = const <String, String>{},
  });

  final int mediaMoved;
  final int directoriesMoved;

  /// Items whose tags could not be rewritten, keyed by id.
  final Map<String, String> failureReasons;

  int get itemsMoved => mediaMoved + directoriesMoved;

  bool get hasFailures => failureReasons.isNotEmpty;

  @override
  String toString() =>
      'TagMergeResult(media: $mediaMoved, directories: $directoriesMoved, '
      'failures: ${failureReasons.length})';
}

/// Folds one tag into another: everything carrying `source` ends up carrying
/// `target` instead, and `source` is deleted.
///
/// The obvious sequel to renaming, which is how you find out you have both
/// `beach` and `Beach` in the first place. Cheap because tags are referenced by
/// id — nothing has to be re-tagged by hand.
class MergeTagsUseCase {
  const MergeTagsUseCase({
    required TagRepository tagRepository,
    required MediaRepository mediaRepository,
    required DirectoryRepository directoryRepository,
  })  : _tagRepository = tagRepository,
        _mediaRepository = mediaRepository,
        _directoryRepository = directoryRepository;

  final TagRepository _tagRepository;
  final MediaRepository _mediaRepository;
  final DirectoryRepository _directoryRepository;

  Future<TagMergeResult> call({
    required TagEntity source,
    required TagEntity target,
  }) async {
    if (source.id == target.id) {
      throw const TagValidationException('A tag cannot be merged into itself');
    }

    final media = await _mediaRepository.filterMediaByTags([source.id]);
    final directories =
        await _directoryRepository.filterDirectoriesByTags([source.id]);

    // Per-item payloads. Deliberately NOT AssignTagUseCase.setTagsForMedia,
    // which applies one tag list to every item — that would wipe whatever else
    // each item happened to be tagged with.
    final mediaPayload = <String, List<String>>{
      for (final item in media)
        item.id: _rewrite(item.tagIds, source: source.id, target: target.id),
    };
    final directoryPayload = <String, List<String>>{
      for (final directory in directories)
        directory.id:
            _rewrite(directory.tagIds, source: source.id, target: target.id),
    };

    final mediaResult = mediaPayload.isEmpty
        ? BatchUpdateResult.empty
        : await _mediaRepository.updateMediaTagsBatch(mediaPayload);
    final directoryResult = directoryPayload.isEmpty
        ? BatchUpdateResult.empty
        : await _directoryRepository.updateDirectoryTagsBatch(directoryPayload);

    final failureReasons = <String, String>{
      ...mediaResult.failureReasons,
      ...directoryResult.failureReasons,
    };

    // The source tag goes last, and only if every item made it across. Deleting
    // it first — or after a partial failure — would strand assignments pointing
    // at a tag that no longer exists. Leaving it alive means the merge can
    // simply be run again.
    if (failureReasons.isEmpty) {
      await _tagRepository.deleteTag(source.id);
    }

    return TagMergeResult(
      mediaMoved: mediaResult.successfulIds.length,
      directoriesMoved: directoryResult.successfulIds.length,
      failureReasons: failureReasons,
    );
  }

  /// Swaps [source] for [target] while preserving every other tag on the item.
  ///
  /// Through a set, so an item already carrying *both* tags simply loses the
  /// source rather than ending up with the target twice.
  List<String> _rewrite(
    List<String> tagIds, {
    required String source,
    required String target,
  }) {
    final rewritten = LinkedHashSet<String>.from(
      tagIds.where((id) => id != source),
    )..add(target);
    return List<String>.unmodifiable(rewritten);
  }
}

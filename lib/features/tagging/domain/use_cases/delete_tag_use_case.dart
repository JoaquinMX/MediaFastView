import '../repositories/saved_filter_repository.dart';
import '../repositories/tag_repository.dart';

/// Deletes a tag, and strips it from every saved filter.
///
/// The saved filters are the point. A filter that *required* the deleted tag
/// would otherwise keep an id that resolves to nothing, and
/// `TagsViewModel._syncSelectionWithSections` drops unresolvable ids on apply —
/// so the filter would silently stop requiring anything and quietly broaden its
/// results.
///
/// Media and directory rows are deliberately left alone: a dangling tag id on a
/// media row is already tolerated everywhere (`GetTagUsageUseCase` ignores ids
/// with no tag, and the Tags tab builds its sections from the tags that exist),
/// and rewriting every row to strip one id would be a large write for no visible
/// gain.
class DeleteTagUseCase {
  const DeleteTagUseCase({
    required TagRepository tagRepository,
    required SavedFilterRepository savedFilterRepository,
  })  : _tagRepository = tagRepository,
        _savedFilterRepository = savedFilterRepository;

  final TagRepository _tagRepository;
  final SavedFilterRepository _savedFilterRepository;

  Future<void> call(String tagId) async {
    // Filters first: if this half fails, the tag still exists and the filters
    // are still coherent. Deleting the tag first and then failing here would
    // leave filters pointing at a tag that is gone.
    await _savedFilterRepository.removeTagId(tagId);
    await _tagRepository.deleteTag(tagId);
  }
}

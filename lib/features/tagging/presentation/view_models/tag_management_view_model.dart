import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/tag_entity.dart';
import '../../domain/repositories/tag_repository.dart';
import '../../domain/tag_validation.dart';
import '../../domain/use_cases/create_tag_use_case.dart';
import '../../domain/use_cases/delete_tag_use_case.dart';
import '../../domain/use_cases/update_tag_use_case.dart';
import '../states/tag_state.dart';

/// ViewModel for managing tag operations and state.
/// Handles CRUD operations, filtering, and tag management.
///
/// Every mutation goes through a use case, so the domain rules cannot be
/// side-stepped by adding another caller.
class TagViewModel extends StateNotifier<TagState> {
  TagViewModel(
    this._tagRepository,
    this._createTagUseCase,
    this._updateTagUseCase,
    this._deleteTagUseCase,
  ) : super(const TagLoading()) {
    loadTags();
  }

  final TagRepository _tagRepository;
  final CreateTagUseCase _createTagUseCase;
  final UpdateTagUseCase _updateTagUseCase;
  final DeleteTagUseCase _deleteTagUseCase;

  /// Loads all tags from the repository.
  Future<void> loadTags() async {
    state = const TagLoading();
    try {
      final tags = await _tagRepository.getTags();
      if (tags.isEmpty) {
        state = const TagEmpty();
      } else {
        state = TagLoaded(tags);
      }
    } catch (e) {
      state = TagError(e.toString());
    }
  }

  /// Creates a tag named [name] in [color].
  ///
  /// Returns the new tag, or throws [TagValidationException] when the name breaks
  /// the rules or is already taken. Like [updateTag], the exception is left to
  /// propagate rather than flipping the view model into [TagError]: the caller is
  /// a dialog that shows it inline, and erroring the view model would blank the
  /// tag list behind it.
  Future<TagEntity> createTag(String name, int color) async {
    final tag = await _createTagUseCase.createTag(name: name, color: color);

    // Optimistic patch, as in updateTag. A fresh TagLoaded is never `identical`
    // to the previous one, so listeners are notified.
    state = switch (state) {
      TagLoaded(:final tags) => TagLoaded([...tags, tag]),
      _ => TagLoaded([tag]),
    };

    return tag;
  }

  /// Renames [tag] and/or changes its colour.
  ///
  /// Returns the updated tag, or throws [TagValidationException] when the name
  /// breaks the rules or is taken by another tag. The exception is deliberately
  /// left to propagate rather than flipping the view model into [TagError]: the
  /// caller is a dialog that shows it inline, and erroring the view model would
  /// blank the tag list behind it.
  Future<TagEntity> updateTag(
    TagEntity tag, {
    required String name,
    required int color,
  }) async {
    final updatedTag = await _updateTagUseCase(
      tag: tag,
      name: name,
      color: color,
    );

    // Optimistic patch. A fresh TagLoaded is never `identical` to the previous
    // one, so listeners are notified even though TagEntity's `==` is id-only and
    // makes the two lists compare equal.
    state = switch (state) {
      TagLoaded(:final tags) => TagLoaded(
        tags.map((t) => t.id == updatedTag.id ? updatedTag : t).toList(),
      ),
      _ => state, // Keep current state if not loaded
    };

    return updatedTag;
  }

  /// Deletes a tag by its ID.
  ///
  /// Goes through the domain, which also strips the tag from every saved filter
  /// — a filter still holding a dead id would silently stop narrowing by it.
  Future<void> deleteTag(String tagId) async {
    try {
      await _deleteTagUseCase(tagId);

      // Update state optimistically
      state = switch (state) {
        TagLoaded(:final tags) => tags.length <= 1
          ? const TagEmpty()
          : TagLoaded(tags.where((tag) => tag.id != tagId).toList()),
        _ => state, // Keep current state if not loaded
      };
    } catch (e) {
      state = TagError('Failed to delete tag: $e');
    }
  }

  /// Gets a tag by its ID.
  Future<TagEntity?> getTagById(String id) async {
    try {
      return await _tagRepository.getTagById(id);
    } catch (e) {
      state = TagError('Failed to get tag: $e');
      return null;
    }
  }

  /// Filters tags by a search query.
  void filterTags(String query) {
    state = switch (state) {
      TagLoaded(:final tags) => TagLoaded(_filterTagsByQuery(tags, query)),
      _ => state,
    };
  }

  /// Gets all tags (useful for external consumers).
  List<TagEntity> getAllTags() {
    return switch (state) {
      TagLoaded(:final tags) => tags,
      _ => const [],
    };
  }

  /// Whether a tag named [name] already exists, ignoring [excludingId].
  ///
  /// Pass the edited tag's id when validating a rename, or an unchanged name —
  /// a colour-only save, a case fix — would collide with the tag's own row.
  bool tagNameExists(String name, {String? excludingId}) {
    return isTagNameTaken(name, getAllTags(), excludingId: excludingId);
  }

  /// Helper method to filter tags by query.
  List<TagEntity> _filterTagsByQuery(List<TagEntity> tags, String query) {
    if (query.isEmpty) return tags;
    final lowerQuery = query.toLowerCase();
    return tags
        .where((tag) => tag.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

/// Provider for TagViewModel with auto-dispose.
final tagViewModelProvider =
    StateNotifierProvider.autoDispose<TagViewModel, TagState>(
      (ref) => TagViewModel(
        ref.watch(tagRepositoryProvider),
        ref.watch(createTagUseCaseProvider),
        ref.watch(updateTagUseCaseProvider),
        ref.watch(deleteTagUseCaseProvider),
      ),
    );

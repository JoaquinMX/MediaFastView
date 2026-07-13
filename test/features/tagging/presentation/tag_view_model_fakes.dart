import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/entities/saved_filter_entity.dart';
import 'package:media_fast_view/features/tagging/domain/repositories/saved_filter_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/create_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/delete_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/update_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';

/// An in-memory [TagRepository], so a [TagViewModel] can be constructed in a
/// widget test without touching Isar.
class FakeTagRepository implements TagRepository {
  FakeTagRepository([List<TagEntity> tags = const []])
    : _tags = List<TagEntity>.from(tags);

  final List<TagEntity> _tags;

  List<TagEntity> get tags => List<TagEntity>.unmodifiable(_tags);

  @override
  Future<List<TagEntity>> getTags() async => tags;

  @override
  Future<TagEntity?> getTagById(String id) async =>
      _tags.where((tag) => tag.id == id).firstOrNull;

  @override
  Future<void> createTag(TagEntity tag) async => _tags.add(tag);

  @override
  Future<void> updateTag(TagEntity tag) async {
    final index = _tags.indexWhere((existing) => existing.id == tag.id);
    if (index >= 0) {
      _tags[index] = tag;
    }
  }

  @override
  Future<void> deleteTag(String id) async =>
      _tags.removeWhere((tag) => tag.id == id);

  @override
  Future<void> clearTags() async => _tags.clear();
}

/// An in-memory [SavedFilterRepository].
///
/// Implements the two integrity operations for real, so tests can assert that a
/// merge or a delete actually rewrites the filters rather than just being told
/// that it called something.
class FakeSavedFilterRepository implements SavedFilterRepository {
  FakeSavedFilterRepository([List<SavedFilterEntity> filters = const []])
    : _filters = List<SavedFilterEntity>.from(filters);

  final List<SavedFilterEntity> _filters;

  List<SavedFilterEntity> get filters =>
      List<SavedFilterEntity>.unmodifiable(_filters);

  @override
  Future<List<SavedFilterEntity>> getFilters() async => filters;

  @override
  Future<SavedFilterEntity?> getFilterById(String id) async =>
      _filters.where((filter) => filter.id == id).firstOrNull;

  @override
  Future<void> saveFilter(SavedFilterEntity filter) async {
    final index = _filters.indexWhere((existing) => existing.id == filter.id);
    if (index >= 0) {
      _filters[index] = filter;
    } else {
      _filters.add(filter);
    }
  }

  @override
  Future<void> deleteFilter(String id) async =>
      _filters.removeWhere((filter) => filter.id == id);

  @override
  Future<void> rewriteTagId({
    required String sourceTagId,
    required String targetTagId,
  }) async {
    _rewrite(
      (tagIds) => tagIds.contains(sourceTagId)
          // Through a set: a filter already naming the target must not end up
          // holding it twice.
          ? tagIds.map((id) => id == sourceTagId ? targetTagId : id).toSet()
          : tagIds,
    );
  }

  @override
  Future<void> removeTagId(String tagId) async {
    _rewrite(
      (tagIds) => tagIds.where((id) => id != tagId).toSet(),
    );
  }

  void _rewrite(Set<String> Function(Set<String>) rewrite) {
    for (var i = 0; i < _filters.length; i++) {
      final filter = _filters[i];
      final definition = filter.definition;
      _filters[i] = filter.copyWith(
        definition: definition.copyWith(
          requiredTagIds: rewrite(definition.requiredTagIds),
          optionalTagIds: rewrite(definition.optionalTagIds),
          excludedTagIds: rewrite(definition.excludedTagIds),
        ),
      );
    }
  }
}

/// A [TagViewModel] whose state a test can pin directly.
///
/// `tagViewModelProvider.overrideWith(...)` needs a function returning the
/// production `TagViewModel`, so a plain `StateNotifier<TagState>` will not
/// type-check. Extend the real class and stub its async loader instead.
class FakeTagViewModel extends TagViewModel {
  FakeTagViewModel(
    TagState initialState, {
    FakeTagRepository? repository,
    FakeSavedFilterRepository? savedFilters,
  }) : this._(
         initialState,
         repository ?? FakeTagRepository(),
         savedFilters ?? FakeSavedFilterRepository(),
       );

  FakeTagViewModel._(
    TagState initialState,
    this.repository,
    this.savedFilters,
  ) : super(
        repository,
        CreateTagUseCase(repository),
        UpdateTagUseCase(repository),
        DeleteTagUseCase(
          tagRepository: repository,
          savedFilterRepository: savedFilters,
        ),
      ) {
    state = initialState;
  }

  final FakeSavedFilterRepository savedFilters;

  final FakeTagRepository repository;

  /// Every `updateTag` call, so a test can assert what the UI asked for.
  final List<({TagEntity tag, String name, int color})> updatedTags = [];

  /// When set, `updateTag` throws this instead of persisting — lets a test drive
  /// the dialog's error path.
  TagValidationException? updateFailure;

  @override
  Future<void> loadTags() async {
    // No-op: state is pinned by the constructor.
  }

  @override
  Future<TagEntity> updateTag(
    TagEntity tag, {
    required String name,
    required int color,
  }) async {
    updatedTags.add((tag: tag, name: name, color: color));

    final failure = updateFailure;
    if (failure != null) {
      throw failure;
    }

    return super.updateTag(tag, name: name, color: color);
  }
}

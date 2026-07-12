import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/create_tag_use_case.dart';
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

/// A [TagViewModel] whose state a test can pin directly.
///
/// `tagViewModelProvider.overrideWith(...)` needs a function returning the
/// production `TagViewModel`, so a plain `StateNotifier<TagState>` will not
/// type-check. Extend the real class and stub its async loader instead.
class FakeTagViewModel extends TagViewModel {
  FakeTagViewModel(TagState initialState, {FakeTagRepository? repository})
    : this._(initialState, repository ?? FakeTagRepository());

  FakeTagViewModel._(TagState initialState, this.repository)
    : super(
        repository,
        CreateTagUseCase(repository),
        UpdateTagUseCase(repository),
      ) {
    state = initialState;
  }

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

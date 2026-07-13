import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/entities/saved_filter_entity.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/delete_tag_use_case.dart';

import '../../presentation/tag_view_model_fakes.dart';

SavedFilterEntity _filter({
  Set<String> required = const {},
  Set<String> optional = const {},
  Set<String> excluded = const {},
}) {
  return SavedFilterEntity(
    id: 'filter-1',
    name: 'Trips',
    definition: SavedFilterDefinition(
      requiredTagIds: required,
      optionalTagIds: optional,
      excludedTagIds: excluded,
    ),
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

TagEntity _tag(String id) => TagEntity(
      id: id,
      name: id,
      color: 0xFF2196F3,
      createdAt: DateTime(2024),
    );

void main() {
  late FakeTagRepository tags;
  late FakeSavedFilterRepository savedFilters;
  late DeleteTagUseCase useCase;

  setUp(() {
    tags = FakeTagRepository([_tag('tag-beach'), _tag('tag-family')]);
    savedFilters = FakeSavedFilterRepository();
    useCase = DeleteTagUseCase(
      tagRepository: tags,
      savedFilterRepository: savedFilters,
    );
  });

  group('DeleteTagUseCase', () {
    test('deletes the tag', () async {
      await useCase('tag-beach');

      expect(tags.tags.map((tag) => tag.id), ['tag-family']);
    });

    // Without this, a saved filter keeps an id that resolves to nothing — and
    // the Tags tab drops unresolvable ids on apply, so the filter silently stops
    // narrowing by that tag.
    test('strips the tag from every saved filter', () async {
      await savedFilters.saveFilter(
        _filter(
          required: {'tag-beach', 'tag-family'},
          optional: {'tag-beach'},
          excluded: {'tag-beach'},
        ),
      );

      await useCase('tag-beach');

      final definition = savedFilters.filters.single.definition;
      expect(definition.requiredTagIds, {'tag-family'});
      expect(definition.optionalTagIds, isEmpty);
      expect(definition.excludedTagIds, isEmpty);
      expect(definition.allTagIds, isNot(contains('tag-beach')));
    });

    test('leaves filters that never mentioned the tag alone', () async {
      await savedFilters.saveFilter(_filter(required: {'tag-family'}));

      await useCase('tag-beach');

      expect(
        savedFilters.filters.single.definition.requiredTagIds,
        {'tag-family'},
      );
    });
  });
}

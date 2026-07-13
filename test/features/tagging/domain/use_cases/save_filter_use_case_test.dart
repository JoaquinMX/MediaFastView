import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/tagging/domain/entities/saved_filter_entity.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_filter_mode.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_media_type_filter.dart';
import 'package:media_fast_view/features/tagging/domain/tag_validation.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/save_filter_use_case.dart';

import '../../presentation/tag_view_model_fakes.dart';

const _definition = SavedFilterDefinition(
  requiredTagIds: {'tag-beach'},
  excludedTagIds: {'tag-blurry'},
  filterMode: TagFilterMode.all,
  mediaTypeFilter: TagMediaTypeFilter.images,
  directoryPaths: {'/Photos/2024'},
);

void main() {
  late FakeSavedFilterRepository repository;
  late SaveFilterUseCase useCase;

  setUp(() {
    repository = FakeSavedFilterRepository();
    useCase = SaveFilterUseCase(repository, generateId: () => 'generated-id');
  });

  group('SaveFilterUseCase', () {
    test('creates a filter, trimming the name and minting an id', () async {
      final saved = await useCase(
        name: '  Trips 2024  ',
        definition: _definition,
      );

      expect(saved.id, 'generated-id');
      expect(saved.name, 'Trips 2024');
      expect(saved.definition, _definition);
      expect(repository.filters.single.id, 'generated-id');
    });

    test('stores every part of the query', () async {
      final saved = await useCase(name: 'Trips', definition: _definition);

      final stored = repository.filters.single.definition;
      expect(stored.requiredTagIds, {'tag-beach'});
      expect(stored.excludedTagIds, {'tag-blurry'});
      expect(stored.filterMode, TagFilterMode.all);
      expect(stored.mediaTypeFilter, TagMediaTypeFilter.images);
      expect(stored.directoryPaths, {'/Photos/2024'});
      expect(saved.definition, stored);
    });

    group('updating in place', () {
      test('keeps the id and createdAt, and bumps updatedAt', () async {
        final created = await useCase(name: 'Trips', definition: _definition);

        final updated = await useCase(
          name: 'Trips',
          definition: const SavedFilterDefinition(
            requiredTagIds: {'tag-family'},
          ),
          existingId: created.id,
        );

        expect(updated.id, created.id);
        expect(updated.createdAt, created.createdAt);
        expect(
          updated.updatedAt.isBefore(created.updatedAt),
          isFalse,
          reason: 'updatedAt should move forward',
        );
        expect(repository.filters, hasLength(1));
        expect(
          repository.filters.single.definition.requiredTagIds,
          {'tag-family'},
        );
      });

      test('a filter may keep its own name', () async {
        // The self-exclusion trap. Without excludingId, "Update 'Trips'" collides
        // with the filter's own row and is rejected as a duplicate.
        final created = await useCase(name: 'Trips', definition: _definition);

        final updated = await useCase(
          name: 'Trips',
          definition: const SavedFilterDefinition(
            requiredTagIds: {'tag-family'},
          ),
          existingId: created.id,
        );

        expect(updated.name, 'Trips');
      });
    });

    group('rejects', () {
      test('a name already taken by another filter, ignoring case', () async {
        await useCase(name: 'Trips', definition: _definition);

        await expectLater(
          () => useCase(name: 'tRiPs', definition: _definition),
          throwsA(isA<TagValidationException>()),
        );
        expect(repository.filters, hasLength(1));
      });

      test('an empty query', () async {
        // A filter with no tags and no directories selects everything — it is
        // the unfiltered view with a name on it.
        await expectLater(
          () => useCase(
            name: 'Everything',
            definition: SavedFilterDefinition.empty,
          ),
          throwsA(isA<TagValidationException>()),
        );
        expect(repository.filters, isEmpty);
      });

      test('a query narrowed only by media type', () async {
        await expectLater(
          () => useCase(
            name: 'Images',
            definition: const SavedFilterDefinition(
              mediaTypeFilter: TagMediaTypeFilter.images,
            ),
          ),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('a name that is too short', () async {
        await expectLater(
          () => useCase(name: 'a', definition: _definition),
          throwsA(isA<TagValidationException>()),
        );
      });

      test('a name with invalid characters', () async {
        await expectLater(
          () => useCase(name: 'bad/name', definition: _definition),
          throwsA(isA<TagValidationException>()),
        );
      });
    });

    test('a directory-only filter is valid', () async {
      final saved = await useCase(
        name: 'Trips folder',
        definition: const SavedFilterDefinition(
          directoryPaths: {'/Photos/2024/Trips'},
        ),
      );

      expect(saved.definition.directoryPaths, {'/Photos/2024/Trips'});
    });
  });
}

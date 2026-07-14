import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_saved_filter_data_source.dart';
import 'package:media_fast_view/features/tagging/data/isar/saved_filter_collection.dart';
import 'package:media_fast_view/features/tagging/data/models/saved_filter_model.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_filter_mode.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_media_type_filter.dart';

import '../../../../helpers/in_memory_isar_stores.dart';
import '../../../../helpers/isar_id.dart';

SavedFilterModel _filter(
  String id, {
  String name = 'Trips',
  DateTime? createdAt,
}) {
  return SavedFilterModel(
    id: id,
    profileId: 'profile-1',
    name: name,
    requiredTagIds: const ['tag-beach'],
    optionalTagIds: const ['tag-family'],
    excludedTagIds: const ['tag-blurry'],
    filterMode: TagFilterMode.hybrid,
    mediaTypeFilter: TagMediaTypeFilter.images,
    directoryPaths: const ['/Photos/2024/Trips'],
    createdAt: createdAt ?? DateTime(2024),
    updatedAt: DateTime(2024, 6),
  );
}

void main() {
  late FakeIsarDatabase database;
  late InMemorySavedFilterCollectionStore store;
  late IsarSavedFilterDataSource dataSource;

  setUp(() {
    database = FakeIsarDatabase();
    store = InMemorySavedFilterCollectionStore();
    dataSource = IsarSavedFilterDataSource(
      database,
      profileId: 'profile-1',
      storeBuilder: (_) => store,
    );
  });

  group('IsarSavedFilterDataSource', () {
    test('round-trips every field', () async {
      await dataSource.saveFilter(_filter('filter-1'));

      final loaded = (await dataSource.getFilters()).single;

      expect(loaded.id, 'filter-1');
      expect(loaded.name, 'Trips');
      expect(loaded.requiredTagIds, ['tag-beach']);
      expect(loaded.optionalTagIds, ['tag-family']);
      expect(loaded.excludedTagIds, ['tag-blurry']);
      expect(loaded.filterMode, TagFilterMode.hybrid);
      expect(loaded.mediaTypeFilter, TagMediaTypeFilter.images);
      expect(loaded.directoryPaths, ['/Photos/2024/Trips']);
      expect(loaded.createdAt, DateTime(2024));
      expect(loaded.updatedAt, DateTime(2024, 6));
    });

    test('saving the same id replaces rather than duplicates', () async {
      await dataSource.saveFilter(_filter('filter-1', name: 'Trips'));
      await dataSource.saveFilter(_filter('filter-1', name: 'Renamed'));

      final filters = await dataSource.getFilters();
      expect(filters, hasLength(1));
      expect(filters.single.name, 'Renamed');
    });

    test('returns filters oldest first', () async {
      await dataSource.saveFilters([
        _filter('b', name: 'Second', createdAt: DateTime(2024, 2)),
        _filter('a', name: 'First', createdAt: DateTime(2024, 1)),
      ]);

      expect(
        (await dataSource.getFilters()).map((filter) => filter.name),
        ['First', 'Second'],
      );
    });

    test('removeFilter deletes by the key the row was stored under', () async {
      // The delete path recomputes the id; if it ever diverged from the
      // collection's own getter it would delete nothing, or the wrong row.
      await dataSource.saveFilter(_filter('filter-1'));
      await dataSource.saveFilter(_filter('filter-2', name: 'Other'));

      await dataSource.removeFilter('filter-1');

      expect(
        (await dataSource.getFilters()).map((filter) => filter.id),
        ['filter-2'],
      );
    });

    test('is empty to start, and clears', () async {
      expect(await dataSource.getFilters(), isEmpty);

      await dataSource.saveFilter(_filter('filter-1'));
      await dataSource.clearFilters();

      expect(await dataSource.getFilters(), isEmpty);
    });
  });

  group('SavedFilterCollection', () {
    test('keys on the shared Isar id helper', () async {
      final collection = _filter('filter-1').toCollection();

      expect(collection.id, isarIdForString('filter-1'));
      expect(collection.id, savedFilterCollectionId('filter-1'));
      expect(collection.id, isNonNegative);
    });

    test('round-trips back to an equal model', () {
      final model = _filter('filter-1');

      expect(model.toCollection().toModel(), model);
    });
  });
}

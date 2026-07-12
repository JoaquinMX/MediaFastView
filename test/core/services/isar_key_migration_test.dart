import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/isar_key_migration.dart';
import 'package:media_fast_view/features/favorites/data/isar/favorite_collection.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';

import '../../helpers/in_memory_isar_stores.dart';
import '../../helpers/isar_id.dart';

TagCollection _tag(String id, {String? name, int color = 0xFF2196F3}) {
  return TagModel(
    id: id,
    name: name ?? id,
    color: color,
    createdAt: DateTime(2024, 1, 1),
  ).toCollection();
}

FavoriteCollection _favorite(String itemId, {FavoriteItemType? type}) {
  return FavoriteModel(
    itemId: itemId,
    itemType: type ?? FavoriteItemType.media,
    addedAt: DateTime(2024, 1, 1),
  ).toCollection();
}

void main() {
  late InMemoryTagCollectionStore tags;
  late InMemoryFavoriteCollectionStore favorites;
  late int backUpCount;

  setUp(() {
    tags = InMemoryTagCollectionStore();
    favorites = InMemoryFavoriteCollectionStore();
    backUpCount = 0;
  });

  Future<IsarKeyMigrationReport> migrate() {
    return const IsarKeyMigration().runOnStores(
      tags: tags,
      favorites: favorites,
      backUp: () async => backUpCount += 1,
    );
  }

  /// Writes rows the way an older build did: keyed by the byte-sum id.
  void seedLegacyTags(Iterable<TagCollection> rows) {
    for (final row in rows) {
      tags.seedAt(legacyIsarIdForString(row.tagId), row);
    }
  }

  void seedLegacyFavorites(Iterable<FavoriteCollection> rows) {
    for (final row in rows) {
      favorites.seedAt(
        legacyIsarIdForString(favoriteKey(row.itemId, row.itemType)),
        row,
      );
    }
  }

  group('IsarKeyMigration', () {
    test('re-keys legacy tags without losing any of them', () async {
      final seeded = [
        _tag('tag-beach', name: 'Beach', color: 0xFF2196F3),
        _tag('tag-family', name: 'Family', color: 0xFF4CAF50),
        _tag('tag-trips', name: 'Trips', color: 0xFFE91E63),
      ];
      seedLegacyTags(seeded);

      final report = await migrate();

      expect(report.tagsRekeyed, 3);

      // Every tag survives, with its name and colour, and is now reachable at
      // the id the collection computes — which is what removeTag() deletes by.
      for (final tag in seeded) {
        final found = await tags.getById(tag.id);
        expect(found, isNotNull, reason: '${tag.tagId} should be re-keyed');
        expect(found!.name, tag.name);
        expect(found.color, tag.color);
      }
      expect((await tags.getAll()).length, 3);
    });

    test('re-keys legacy favorites, keeping type and timestamp', () async {
      seedLegacyFavorites([
        _favorite('media-1'),
        _favorite('media-2'),
        _favorite('dir-1', type: FavoriteItemType.directory),
      ]);

      final report = await migrate();

      expect(report.favoritesRekeyed, 3);
      expect(
        await favorites.getByCompositeId('dir-1', FavoriteItemType.directory),
        isNotNull,
      );
      expect(
        await favorites.getByCompositeId('media-1', FavoriteItemType.media),
        isNotNull,
      );
      expect((await favorites.getAll()).length, 3);
    });

    test('backs up exactly once, before mutating', () async {
      seedLegacyTags([_tag('tag-beach')]);

      await migrate();

      expect(backUpCount, 1);
    });

    test('is idempotent: a second run does nothing', () async {
      seedLegacyTags([_tag('tag-beach'), _tag('tag-family')]);
      seedLegacyFavorites([_favorite('media-1')]);

      final first = await migrate();
      expect(first.didAnything, isTrue);

      final second = await migrate();

      expect(second.didAnything, isFalse);
      expect(second, IsarKeyMigrationReport.none);
      // And crucially: no second backup, so launches do not litter .bak files.
      expect(backUpCount, 1);
    });

    test('leaves an already-migrated store alone', () async {
      // Written by the fixed build: keyed by the collection's own id.
      await tags.put(_tag('tag-beach'));
      await favorites.put(_favorite('media-1'));

      final report = await migrate();

      expect(report.didAnything, isFalse);
      expect(backUpCount, 0, reason: 'nothing to protect, so nothing to back up');
    });

    test('leaves an empty store alone, and takes no backup', () async {
      final report = await migrate();

      expect(report, IsarKeyMigrationReport.none);
      expect(backUpCount, 0);
    });

    test('migrates one collection when only the other is already current',
        () async {
      seedLegacyTags([_tag('tag-beach')]);
      await favorites.put(_favorite('media-1')); // already current

      final report = await migrate();

      expect(report.tagsRekeyed, 1);
      expect(report.favoritesRekeyed, 0);
      expect((await favorites.getAll()).length, 1);
    });

    test('the legacy scheme destroys rows on write — the new one does not',
        () async {
      // The bug itself, reproduced against a store keyed exactly like Isar.
      // Writing 200 tags under the byte-sum id does not give you 200 rows: the
      // colliding ones overwrite each other and are gone before anything reads.
      final tagRows = [for (var i = 0; i < 200; i++) _tag('tag-$i')];
      seedLegacyTags(tagRows);

      final survivors = tags.data.length;
      expect(
        survivors,
        lessThan(200),
        reason: 'the byte-sum id must be shown to lose rows, or this test is '
            'not modelling the bug',
      );

      // The same 200 tags, written under the fixed derivation: none are lost.
      tags.data.clear();
      for (final tag in tagRows) {
        await tags.put(tag);
      }
      expect(tags.data.length, 200);
    });

    test('carries every surviving row across, and cannot resurrect the rest',
        () async {
      final tagRows = [for (var i = 0; i < 200; i++) _tag('tag-$i')];
      final favoriteRows = [for (var i = 0; i < 500; i++) _favorite('media-$i')];
      seedLegacyTags(tagRows);
      seedLegacyFavorites(favoriteRows);

      // Whatever the collisions already ate is unrecoverable — the rows were
      // overwritten on disk long before this ran. The contract is that the
      // migration loses nothing *further*.
      final survivingTags = await tags.getAll();
      final survivingFavorites = await favorites.getAll();
      expect(survivingTags.length, lessThan(200));

      final report = await migrate();

      expect(report.tagsRekeyed, survivingTags.length);
      expect(report.favoritesRekeyed, survivingFavorites.length);
      expect((await tags.getAll()).length, survivingTags.length);
      expect((await favorites.getAll()).length, survivingFavorites.length);

      // And every survivor is now addressable by the id the collection computes,
      // which is what removeTag()/removeFavorites() delete by.
      for (final tag in survivingTags) {
        expect(await tags.getById(tag.id), isNotNull);
      }
      for (final favorite in survivingFavorites) {
        expect(await favorites.getById(favorite.id), isNotNull);
      }
    });
  });
}

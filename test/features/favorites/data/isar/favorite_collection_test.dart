import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/features/favorites/data/isar/favorite_collection.dart';
import 'package:media_fast_view/features/favorites/data/models/favorite_model.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';

void main() {
  group('FavoriteCollection', () {
    test('maps FavoriteModel to collection and back with metadata', () {
      final model = FavoriteModel(
        itemId: 'media-42',
        itemType: FavoriteItemType.media,
        addedAt: DateTime.parse('2024-05-12T15:30:00.000Z'),
        metadata: const {
          'name': 'Sunset.png',
          'path': '/Users/example/Pictures/Sunset.png',
          'type': 'image',
        },
      );

      final collection = model.toCollection();

      expect(collection.itemId, model.itemId);
      expect(collection.itemType, model.itemType);
      expect(collection.addedAt, model.addedAt);
      expect(
        jsonDecode(collection.metadataJson!) as Map<String, dynamic>,
        equals(model.metadata),
      );
      expect(
        collection.id,
        Isar.fastHash('${model.itemType.name}::${model.itemId}'),
      );

      final roundTrip = collection.toModel();

      expect(roundTrip, model);
      expect(() => roundTrip.metadata!['extra'] = 'nope', throwsUnsupportedError);
    });

    test('links are initialised empty', () {
      final collection = FavoriteModel(
        itemId: 'dir-7',
        itemType: FavoriteItemType.directory,
        addedAt: DateTime.utc(2024, 6, 12),
      ).toCollection();

      expect(collection.media.isAttached, isFalse);
      expect(collection.media.value, isNull);
      expect(collection.directory.isAttached, isFalse);
      expect(collection.directory.value, isNull);
    });

    test('handles null metadata', () {
      final model = FavoriteModel(
        itemId: 'media-99',
        itemType: FavoriteItemType.media,
        addedAt: DateTime.utc(2024, 7, 20),
      );

      final collection = model.toCollection();

      expect(collection.metadataJson, isNull);

      final roundTrip = collection.toModel();

      expect(roundTrip.metadata, isNull);
    });
  });
}

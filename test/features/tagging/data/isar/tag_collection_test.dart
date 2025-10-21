import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/tagging/data/isar/tag_collection.dart';

import '../../../../helpers/isar_id.dart';

void main() {
  group('TagCollection', () {
    test('maps TagModel to collection and back', () {
      final model = TagModel(
        id: 'tag-1',
        name: 'Favorites',
        color: 0xFFAA5500,
        createdAt: DateTime.parse('2024-05-01T10:00:00.000Z'),
      );

      final collection = model.toCollection();

      expect(collection.tagId, model.id);
      expect(collection.name, model.name);
      expect(collection.color, model.color);
      expect(collection.createdAt, model.createdAt);
      expect(collection.id, isarIdForString(model.id));

      final roundTrip = collection.toModel();

      expect(roundTrip, model);
    });

    test('links are initialised empty', () {
      final collection = TagModel(
        id: 'tag-2',
        name: 'To Sort',
        color: 0xFF112233,
        createdAt: DateTime.utc(2024, 6, 1),
      ).toCollection();

      expect(collection.media.isAttached, isFalse);
      expect(collection.media.isEmpty, isTrue);
      expect(collection.directories.isAttached, isFalse);
      expect(collection.directories.isEmpty, isTrue);
    });
  });
}

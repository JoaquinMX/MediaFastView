import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

import '../../../../helpers/isar_id.dart';

void main() {
  group('MediaCollectionMapper', () {
    test('toCollection preserves all fields with correct id mapping', () {
      final model = MediaModel(
        id: 'media-1',
        path: '/Users/example/Documents/photo.png',
        name: 'photo.png',
        type: MediaType.image,
        size: 2048,
        lastModified: DateTime.parse('2024-03-01T08:00:00.000Z'),
        tagIds: const <String>['holiday'],
        directoryId: 'dir-1',
        bookmarkData: 'bookmark',
      );

      final collection = model.toCollection();

      expect(collection.mediaId, equals(model.id));
      expect(collection.path, equals(model.path));
      expect(collection.name, equals(model.name));
      expect(collection.type, equals(model.type));
      expect(collection.size, equals(model.size));
      expect(collection.lastModified, equals(model.lastModified));
      expect(collection.tagIds, equals(model.tagIds));
      expect(collection.directoryId, equals(model.directoryId));
      expect(collection.bookmarkData, equals(model.bookmarkData));
      // ID should be generated, not necessarily equal to the specific hash
      expect(collection.id, isNotNull);
      expect(collection.id, isNot(0));
    });

    test('roundtrip MediaModel → Collection → MediaModel preserves all data', () {
      final original = MediaModel(
        id: 'media-1',
        path: '/Users/example/Documents/photo.png',
        name: 'photo.png',
        type: MediaType.image,
        size: 2048,
        lastModified: DateTime.parse('2024-03-01T08:00:00.000Z'),
        tagIds: const <String>['holiday'],
        directoryId: 'dir-1',
        bookmarkData: 'bookmark',
      );

      final roundTrip = original.toCollection().toModel();

      expect(roundTrip, equals(original));
    });

    test('toCollection initializes directory link as unattached', () {
      final collection = MediaModel(
        id: 'media-2',
        path: '/Users/example/Videos/video.mp4',
        name: 'video.mp4',
        type: MediaType.video,
        size: 4096,
        lastModified: DateTime.utc(2024, 4, 5),
        tagIds: const <String>['fun'],
        directoryId: 'dir-2',
      ).toCollection();

      expect(collection.directory.isAttached, isFalse);
      expect(collection.directory.value, isNull);
    });

    test('toCollection makes tagIds immutable when converting back', () {
      final model = MediaModel(
        id: 'media-3',
        path: '/path/file.jpg',
        name: 'file.jpg',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime.utc(2024, 1, 1),
        tagIds: const <String>['tag1', 'tag2'],
        directoryId: 'dir-3',
      );

      final roundTrip = model.toCollection().toModel();

      expect(roundTrip.tagIds, isA<List<String>>());
      // Verify the list cannot be modified
      expect(
        () => (roundTrip.tagIds as List<String>).add('tag3'),
        throwsUnsupportedError,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/features/media_library/data/isar/media_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';

void main() {
  group('MediaCollection', () {
    test('maps MediaModel to collection and back', () {
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

      expect(collection.mediaId, model.id);
      expect(collection.path, model.path);
      expect(collection.name, model.name);
      expect(collection.type, model.type);
      expect(collection.size, model.size);
      expect(collection.lastModified, model.lastModified);
      expect(collection.tagIds, equals(model.tagIds));
      expect(collection.directoryId, model.directoryId);
      expect(collection.bookmarkData, model.bookmarkData);
      expect(collection.id, Isar.fastHash(model.id));

      final roundTrip = collection.toModel();

      expect(roundTrip, model);
    });

    test('directory link is initialised empty', () {
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
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:media_fast_view/features/media_library/data/isar/directory_collection.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';

void main() {
  group('DirectoryCollection', () {
    test('maps DirectoryModel to collection and back', () {
      final model = DirectoryModel(
        id: 'dir-1',
        path: '/Users/example/Documents',
        name: 'Documents',
        thumbnailPath: '/thumbs/documents.png',
        tagIds: const <String>['work', 'projects'],
        lastModified: DateTime.parse('2024-01-10T12:34:56.000Z'),
        bookmarkData: 'bookmark-info',
      );

      final collection = model.toCollection();

      expect(collection.directoryId, model.id);
      expect(collection.path, model.path);
      expect(collection.name, model.name);
      expect(collection.thumbnailPath, model.thumbnailPath);
      expect(collection.tagIds, equals(model.tagIds));
      expect(collection.lastModified, model.lastModified);
      expect(collection.bookmarkData, model.bookmarkData);
      expect(collection.id, Isar.fastHash(model.id));

      final roundTrip = collection.toModel();

      expect(roundTrip, model);
    });

    test('defensive copy keeps model list immutable', () {
      final model = DirectoryModel(
        id: 'dir-2',
        path: '/Users/example/Pictures',
        name: 'Pictures',
        tagIds: const <String>['family'],
        lastModified: DateTime.utc(2024, 2, 20),
      );

      final collection = model.toCollection();
      collection.tagIds.add('added');

      final roundTrip = collection.toModel();

      expect(roundTrip.tagIds, equals(<String>['family', 'added']));
      expect(() => roundTrip.tagIds.add('oops'), throwsUnsupportedError);
    });
  });
}

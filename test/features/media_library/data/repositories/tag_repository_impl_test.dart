import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/media_library/data/repositories/tag_repository_impl.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';


class _MockIsarTagDataSource extends Mock implements IsarTagDataSource {}
void main() {
  late _MockIsarTagDataSource tagDataSource;
  late TagRepositoryImpl repository;

  setUp(() {
    tagDataSource = _MockIsarTagDataSource();
    repository = TagRepositoryImpl(tagDataSource);
  });

  group('getTags', () {
    test('returns mapped tag entities from the data source', () async {
      final now = DateTime.now();
      final models = [
        TagModel(id: '1', name: 'One', color: 0xFF000000, createdAt: now),
        TagModel(id: '2', name: 'Two', color: 0xFFFFFFFF, createdAt: now),
      ];
      when(tagDataSource.getTags()).thenAnswer((_) async => models);

      final result = await repository.getTags();

      expect(
        result,
        [
          TagEntity(id: '1', name: 'One', color: 0xFF000000, createdAt: now),
          TagEntity(id: '2', name: 'Two', color: 0xFFFFFFFF, createdAt: now),
        ],
      );
      verify(tagDataSource.getTags()).called(1);
      verifyNoMoreInteractions(tagDataSource);
    });
  });

  group('getTagById', () {
    test('returns the matching tag when found', () async {
      final now = DateTime.now();
      when(tagDataSource.getTags()).thenAnswer(
        (_) async => [
          TagModel(id: '1', name: 'One', color: 0xFF000000, createdAt: now),
        ],
      );

      final tag = await repository.getTagById('1');

      expect(tag, TagEntity(id: '1', name: 'One', color: 0xFF000000, createdAt: now));
    });

    test('returns null when no matching tag exists', () async {
      when(tagDataSource.getTags()).thenAnswer((_) async => const []);

      final tag = await repository.getTagById('missing');

      expect(tag, isNull);
    });
  });

  group('write operations', () {
    test('createTag delegates to addTag', () async {
      final now = DateTime.now();
      final entity = TagEntity(id: '1', name: 'One', color: 0xFF000000, createdAt: now);
      final expectedModel = TagModel(
        id: '1',
        name: 'One',
        color: 0xFF000000,
        createdAt: now,
      );

      when(tagDataSource.addTag(any)).thenAnswer((_) async {});

      await repository.createTag(entity);

      verify(tagDataSource.addTag(expectedModel)).called(1);
    });

    test('updateTag delegates to updateTag on data source', () async {
      final now = DateTime.now();
      final entity = TagEntity(id: '1', name: 'One', color: 0xFF000000, createdAt: now);
      final expectedModel = TagModel(
        id: '1',
        name: 'One',
        color: 0xFF000000,
        createdAt: now,
      );

      when(tagDataSource.updateTag(any)).thenAnswer((_) async {});

      await repository.updateTag(entity);

      verify(tagDataSource.updateTag(expectedModel)).called(1);
    });

    test('deleteTag delegates to removeTag', () async {
      when(tagDataSource.removeTag(any)).thenAnswer((_) async {});

      await repository.deleteTag('1');

      verify(tagDataSource.removeTag('1')).called(1);
    });
  });
}

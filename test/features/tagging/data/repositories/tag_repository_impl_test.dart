import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:media_fast_view/features/tagging/data/repositories/tag_repository_impl.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../../mocks.mocks.dart';

class _MockIsarTagDataSource extends Mock implements IsarTagDataSource {}

void main() {
  group('TagRepositoryImpl', () {
    late TagRepositoryImpl repository;
    late _MockIsarTagDataSource isarTagDataSource;
    late MockSharedPreferencesTagDataSource legacyTagDataSource;

    setUp(() {
      isarTagDataSource = _MockIsarTagDataSource();
      legacyTagDataSource = MockSharedPreferencesTagDataSource();

      repository = TagRepositoryImpl(isarTagDataSource, legacyTagDataSource);
    });

    test('getTags falls back to legacy storage and seeds Isar', () async {
      final tagModel = TagModel(
        id: 'tag-1',
        name: 'Test',
        color: 0xFF0000FF,
        createdAt: DateTime(2024, 1, 1),
      );

      when(isarTagDataSource.getTags()).thenAnswer((_) async => <TagModel>[]);
      when(legacyTagDataSource.getTags()).thenAnswer((_) async => <TagModel>[tagModel]);
      when(isarTagDataSource.saveTags(any)).thenAnswer((_) async {});

      final tags = await repository.getTags();

      expect(tags, equals(<TagEntity>[
        TagEntity(
          id: tagModel.id,
          name: tagModel.name,
          color: tagModel.color,
          createdAt: tagModel.createdAt,
        ),
      ]));
      verify(isarTagDataSource.saveTags(<TagModel>[tagModel])).called(1);
    });
  });
}

import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/tagging/data/isar/isar_tag_data_source.dart';
import 'package:media_fast_view/features/tagging/data/repositories/tag_repository_impl.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class _MockIsarTagDataSource extends Mock implements IsarTagDataSource {}

void main() {
  group('TagRepositoryImpl', () {
    late TagRepositoryImpl repository;
    late _MockIsarTagDataSource isarTagDataSource;

    setUp(() {
      isarTagDataSource = _MockIsarTagDataSource();
      repository = TagRepositoryImpl(isarTagDataSource);
    });

    test('getTags returns mapped entities from isar', () async {
      final tagModel = TagModel(
        id: 'tag-1',
        name: 'Test',
        color: 0xFF0000FF,
        createdAt: DateTime(2024, 1, 1),
      );

      when(isarTagDataSource.getTags())
          .thenAnswer((_) async => <TagModel>[tagModel]);

      final tags = await repository.getTags();

      expect(tags, equals(<TagEntity>[
        TagEntity(
          id: tagModel.id,
          name: tagModel.name,
          color: tagModel.color,
          createdAt: tagModel.createdAt,
        ),
      ]));
      verify(isarTagDataSource.getTags()).called(1);
    });
  });
}

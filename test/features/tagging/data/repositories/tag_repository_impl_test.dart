import 'package:media_fast_view/features/media_library/data/models/tag_model.dart';
import 'package:media_fast_view/features/tagging/data/repositories/tag_repository_impl.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../../mocks.mocks.dart';

void main() {
  group('TagRepositoryImpl', () {
    late TagRepositoryImpl repository;
    late MockIsarTagDataSource isarTagDataSource;

    setUp(() {
      isarTagDataSource = MockIsarTagDataSource();
      repository = TagRepositoryImpl(isarTagDataSource);
    });

    test('getTags returns tags from Isar', () async {
      final tagModel = TagModel(
        id: 'tag-1',
        name: 'Test',
        color: 0xFF0000FF,
        createdAt: DateTime(2024, 1, 1),
      );

      when(isarTagDataSource.getTags()).thenAnswer((_) async => <TagModel>[tagModel]);

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

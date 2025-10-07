import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class _MockDirectoryRepository extends Mock implements DirectoryRepository {}

class _MockMediaRepository extends Mock implements MediaRepository {}

void main() {
  late _MockDirectoryRepository directoryRepository;
  late _MockMediaRepository mediaRepository;
  late AssignTagUseCase useCase;

  setUp(() {
    directoryRepository = _MockDirectoryRepository();
    mediaRepository = _MockMediaRepository();
    useCase = AssignTagUseCase(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
    );
  });

  group('setTagsForDirectory', () {
    test('deduplicates tag ids while preserving order', () async {
      const directoryId = 'dir-1';
      final directory = DirectoryEntity(
        id: directoryId,
        path: '/test/path',
        name: 'Test Directory',
        thumbnailPath: null,
        tagIds: const ['existing'],
        lastModified: DateTime(2024, 1, 1),
      );

      when(directoryRepository.getDirectoryById(directoryId))
          .thenAnswer((_) async => directory);
      when(directoryRepository.updateDirectoryTags(any, any))
          .thenAnswer((_) async {});

      await useCase.setTagsForDirectory(
        directoryId,
        ['tag-a', 'tag-a', 'tag-b'],
      );

      verify(directoryRepository.getDirectoryById(directoryId)).called(1);
      final captured = verify(
        directoryRepository.updateDirectoryTags(directoryId, captureAny),
      ).captured.single as List<String>;

      expect(captured, equals(['tag-a', 'tag-b']));
    });

    test('does nothing when directory is missing', () async {
      when(directoryRepository.getDirectoryById(any))
          .thenAnswer((_) async => null);

      await useCase.setTagsForDirectory('unknown', ['tag-a']);

      verify(directoryRepository.getDirectoryById('unknown')).called(1);
      verifyNever(directoryRepository.updateDirectoryTags(any, any));
    });
  });
}

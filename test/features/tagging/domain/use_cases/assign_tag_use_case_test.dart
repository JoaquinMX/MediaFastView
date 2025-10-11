import 'package:media_fast_view/core/utils/batch_update_result.dart';
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

  group('setTagsForDirectories', () {
    test('deduplicates ids and tags before forwarding to repository', () async {
      when(directoryRepository.updateDirectoryTagsBatch(any))
          .thenAnswer((_) async => BatchUpdateResult.empty);

      await useCase.setTagsForDirectories(
        ['dir-1', '', 'dir-1', 'dir-2'],
        ['tag-a', 'tag-a', 'tag-b'],
      );

      final captured = verify(
        directoryRepository.updateDirectoryTagsBatch(captureAny),
      ).captured.single as Map<String, List<String>>;

      expect(
        captured,
        equals({
          'dir-1': ['tag-a', 'tag-b'],
          'dir-2': ['tag-a', 'tag-b'],
        }),
      );
    });

    test('returns repository result allowing partial failures', () async {
      const batchResult = BatchUpdateResult(
        successfulIds: ['dir-1'],
        failureReasons: {'dir-missing': 'Directory not found'},
      );

      when(directoryRepository.updateDirectoryTagsBatch(any))
          .thenAnswer((_) async => batchResult);

      final result = await useCase.setTagsForDirectories(
        ['dir-1', 'dir-missing'],
        ['tag-a'],
      );

      expect(result, equals(batchResult));
    });

    test('returns empty result when all ids are filtered out', () async {
      final result = await useCase.setTagsForDirectories(
        const [''],
        const ['tag-a'],
      );

      expect(result, equals(BatchUpdateResult.empty));
      verifyNever(directoryRepository.updateDirectoryTagsBatch(any));
    });
  });

  group('setTagsForMedia', () {
    test('deduplicates ids and tags before forwarding to repository', () async {
      when(mediaRepository.updateMediaTagsBatch(any))
          .thenAnswer((_) async => BatchUpdateResult.empty);

      await useCase.setTagsForMedia(
        ['media-1', '', 'media-2', 'media-2'],
        ['tag-a', 'tag-b', 'tag-a'],
      );

      final captured = verify(
        mediaRepository.updateMediaTagsBatch(captureAny),
      ).captured.single as Map<String, List<String>>;

      expect(
        captured,
        equals({
          'media-1': ['tag-a', 'tag-b'],
          'media-2': ['tag-a', 'tag-b'],
        }),
      );
    });

    test('returns repository result allowing partial failures', () async {
      const batchResult = BatchUpdateResult(
        successfulIds: ['media-1'],
        failureReasons: {'media-missing': 'Media not found'},
      );

      when(mediaRepository.updateMediaTagsBatch(any))
          .thenAnswer((_) async => batchResult);

      final result = await useCase.setTagsForMedia(
        ['media-1', 'media-missing'],
        ['tag-a'],
      );

      expect(result, equals(batchResult));
    });

    test('returns empty result when ids are empty', () async {
      final result = await useCase.setTagsForMedia(
        const <String>[],
        const ['tag-a'],
      );

      expect(result, equals(BatchUpdateResult.empty));
      verifyNever(mediaRepository.updateMediaTagsBatch(any));
    });
  });
}

import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/repositories/directory_repository_impl.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../../mocks.mocks.dart';

class _MockLocalDirectoryDataSource extends Mock implements LocalDirectoryDataSource {}

void main() {
  group('DirectoryRepositoryImpl', () {
    late DirectoryRepositoryImpl repository;
    late _MockLocalDirectoryDataSource localDirectoryDataSource;
    late MockBookmarkService bookmarkService;
    late MockPermissionService permissionService;
    late MockIsarDirectoryDataSource isarDirectoryDataSource;
    late MockIsarMediaDataSource isarMediaDataSource;

    setUp(() {
      localDirectoryDataSource = _MockLocalDirectoryDataSource();
      bookmarkService = MockBookmarkService();
      permissionService = MockPermissionService();
      isarDirectoryDataSource = MockIsarDirectoryDataSource();
      isarMediaDataSource = MockIsarMediaDataSource();

      repository = DirectoryRepositoryImpl(
        isarDirectoryDataSource,
        localDirectoryDataSource,
        bookmarkService,
        permissionService,
        isarMediaDataSource,
      );
    });

    group('addDirectory', () {
      test('preserves existing tag assignments when updating a known directory', () async {
        const directoryId = 'dir-1';
        const directoryPath = '/test/path';
        final existingModel = DirectoryModel(
          id: directoryId,
          path: directoryPath,
          name: 'Test',
          thumbnailPath: null,
          tagIds: const ['tag-a'],
          lastModified: DateTime(2024, 1, 1),
          bookmarkData: 'existing-bookmark',
        );

        when(isarDirectoryDataSource.getDirectories()).thenAnswer(
          (_) async => [existingModel],
        );
        when(localDirectoryDataSource.validateDirectory(any)).thenAnswer((_) async => true);
        when(bookmarkService.createBookmark(any)).thenThrow(UnsupportedError('not supported on platform'));
        when(permissionService.validateBookmark(any)).thenAnswer(
          (_) async => const BookmarkValidationResult(isValid: true),
        );
        when(isarDirectoryDataSource.updateDirectory(any)).thenAnswer((_) async {});
        when(isarMediaDataSource.migrateDirectoryId(any, any)).thenAnswer((_) async {});

        final directory = DirectoryEntity(
          id: directoryId,
          path: directoryPath,
          name: 'Test',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 1),
        );

        await repository.addDirectory(directory);

        final capturedModel = verify(isarDirectoryDataSource.updateDirectory(captureAny)).captured.single
            as DirectoryModel;

        expect(capturedModel.tagIds, equals(existingModel.tagIds));
        expect(capturedModel.bookmarkData, equals(existingModel.bookmarkData));
      });
    });
  });
}

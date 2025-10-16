import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/repositories/directory_repository_impl.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../../mocks.mocks.dart';

class _MockLocalDirectoryDataSource extends Mock implements LocalDirectoryDataSource {}
class _MockIsarDirectoryDataSource extends Mock implements IsarDirectoryDataSource {}
class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

void main() {
  group('DirectoryRepositoryImpl', () {
    late DirectoryRepositoryImpl repository;
    late MockSharedPreferencesDirectoryDataSource directoryDataSource;
    late _MockLocalDirectoryDataSource localDirectoryDataSource;
    late MockBookmarkService bookmarkService;
    late MockPermissionService permissionService;
    late MockSharedPreferencesMediaDataSource mediaDataSource;
    late _MockIsarDirectoryDataSource isarDirectoryDataSource;
    late _MockIsarMediaDataSource isarMediaDataSource;

    setUp(() {
      directoryDataSource = MockSharedPreferencesDirectoryDataSource();
      localDirectoryDataSource = _MockLocalDirectoryDataSource();
      bookmarkService = MockBookmarkService();
      permissionService = MockPermissionService();
      mediaDataSource = MockSharedPreferencesMediaDataSource();
      isarDirectoryDataSource = _MockIsarDirectoryDataSource();
      isarMediaDataSource = _MockIsarMediaDataSource();

      repository = DirectoryRepositoryImpl(
        isarDirectoryDataSource,
        directoryDataSource,
        localDirectoryDataSource,
        bookmarkService,
        permissionService,
        isarMediaDataSource,
        mediaDataSource,
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

        when(directoryDataSource.getDirectories()).thenAnswer(
          (_) async => [existingModel],
        );
        when(isarDirectoryDataSource.getDirectories()).thenAnswer((_) async => <DirectoryModel>[]);
        when(isarDirectoryDataSource.saveDirectories(any)).thenAnswer((_) async {});
        when(localDirectoryDataSource.validateDirectory(any)).thenAnswer((_) async => true);
        when(bookmarkService.createBookmark(any)).thenThrow(UnsupportedError('not supported on platform'));
        when(permissionService.validateBookmark(any)).thenAnswer(
          (_) async => const BookmarkValidationResult(isValid: true),
        );
        when(directoryDataSource.updateDirectory(any)).thenAnswer((_) async {});
        when(isarDirectoryDataSource.updateDirectory(any)).thenAnswer((_) async {});
        when(isarMediaDataSource.migrateDirectoryId(any, any)).thenAnswer((_) async {});
        when(mediaDataSource.migrateDirectoryId(any, any)).thenAnswer((_) async {});

        final directory = DirectoryEntity(
          id: directoryId,
          path: directoryPath,
          name: 'Test',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 1),
        );

        await repository.addDirectory(directory);

        final capturedModel = verify(directoryDataSource.updateDirectory(captureAny)).captured.single
            as DirectoryModel;

        expect(capturedModel.tagIds, equals(existingModel.tagIds));
        expect(capturedModel.bookmarkData, equals(existingModel.bookmarkData));
      });
    });
  });
}

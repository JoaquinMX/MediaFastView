import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/repositories/directory_repository_impl.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class _MockLocalDirectoryDataSource extends Mock implements LocalDirectoryDataSource {}
class _MockIsarDirectoryDataSource extends Mock implements IsarDirectoryDataSource {}
class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}
class _MockBookmarkService extends Mock implements BookmarkService {}
class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  group('DirectoryRepositoryImpl', () {
    late DirectoryRepositoryImpl repository;
    late _MockLocalDirectoryDataSource localDirectoryDataSource;
    late _MockBookmarkService bookmarkService;
    late _MockPermissionService permissionService;
    late _MockIsarDirectoryDataSource isarDirectoryDataSource;
    late _MockIsarMediaDataSource isarMediaDataSource;

    setUp(() {
      localDirectoryDataSource = _MockLocalDirectoryDataSource();
      bookmarkService = _MockBookmarkService();
      permissionService = _MockPermissionService();
      isarDirectoryDataSource = _MockIsarDirectoryDataSource();
      isarMediaDataSource = _MockIsarMediaDataSource();

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

        final capturedModel =
            verify(isarDirectoryDataSource.updateDirectory(captureAny)).captured.single
            as DirectoryModel;

        expect(capturedModel.tagIds, equals(existingModel.tagIds));
        expect(capturedModel.bookmarkData, equals(existingModel.bookmarkData));
      });
    });

    group('getDirectoryById', () {
      test('returns entity when data source finds a matching directory', () async {
        const path = '/test/path';
        final stableId = generateDirectoryId(path);
        final model = DirectoryModel(
          id: stableId,
          path: path,
          name: 'Test',
          thumbnailPath: null,
          tagIds: const ['tag-1'],
          lastModified: DateTime(2024, 1, 1),
          bookmarkData: null,
        );

        when(isarDirectoryDataSource.getDirectoryById(stableId)).thenAnswer(
          (_) async => model,
        );

        final entity = await repository.getDirectoryById(stableId);

        expect(entity, isNotNull);
        expect(entity!.id, stableId);
        expect(entity.tagIds, ['tag-1']);
      });

      test('migrates legacy identifiers when direct lookup misses', () async {
        final legacyModel = DirectoryModel(
          id: 'legacy-id',
          path: '/legacy/path',
          name: 'Legacy',
          thumbnailPath: null,
          tagIds: const ['tag-legacy'],
          lastModified: DateTime(2024, 1, 1),
          bookmarkData: null,
        );
        final stableId = generateDirectoryId(legacyModel.path);

        when(isarDirectoryDataSource.getDirectoryById(stableId)).thenAnswer(
          (_) async => null,
        );
        when(isarDirectoryDataSource.getDirectories()).thenAnswer(
          (_) async => [legacyModel],
        );
        when(isarMediaDataSource.migrateDirectoryId(any, any)).thenAnswer((_) async {});
        when(isarDirectoryDataSource.removeDirectory(any)).thenAnswer((_) async {});
        when(isarDirectoryDataSource.addDirectory(any)).thenAnswer((_) async {});

        final entity = await repository.getDirectoryById(stableId);

        expect(entity, isNotNull);
        expect(entity!.id, stableId);
        expect(entity.tagIds, ['tag-legacy']);
        verify(isarDirectoryDataSource.getDirectories()).called(1);
        verify(isarMediaDataSource.migrateDirectoryId('legacy-id', stableId)).called(1);
        verify(isarDirectoryDataSource.removeDirectory('legacy-id')).called(1);
        verify(isarDirectoryDataSource.addDirectory(any)).called(1);
      });
    });

    group('updateDirectoryMetadata', () {
      test('preserves existing bookmark when new value is not provided', () async {
        const directoryId = 'dir-1';
        final existingModel = DirectoryModel(
          id: directoryId,
          path: '/test/path',
          name: 'Original',
          thumbnailPath: null,
          tagIds: const ['tag-1'],
          lastModified: DateTime(2024, 1, 1),
          bookmarkData: 'existing-bookmark',
        );

        when(isarDirectoryDataSource.getDirectoryById(directoryId)).thenAnswer(
          (_) async => existingModel,
        );
        when(isarDirectoryDataSource.updateDirectory(any)).thenAnswer((_) async {});

        await repository.updateDirectoryMetadata(
          directoryId,
          name: 'Renamed directory',
        );

        final captured =
            verify(isarDirectoryDataSource.updateDirectory(captureAny)).captured.single
                as DirectoryModel;

        expect(captured.bookmarkData, equals(existingModel.bookmarkData));
      });
    });
  });
}

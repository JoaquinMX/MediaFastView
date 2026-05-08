import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/core/error/app_error.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/filesystem_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/directory_model.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/data/repositories/directory_repository_impl.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';

import 'directory_repository_impl_test.mocks.dart';

@GenerateMocks([
  LocalDirectoryDataSource,
  FilesystemMediaDataSource,
  IsarDirectoryDataSource,
  IsarMediaDataSource,
  BookmarkService,
  PermissionService,
])
void main() {
  group('DirectoryRepositoryImpl', () {
    late DirectoryRepositoryImpl repository;
    late MockLocalDirectoryDataSource localDirectoryDataSource;
    late MockFilesystemMediaDataSource filesystemMediaDataSource;
    late MockBookmarkService bookmarkService;
    late MockPermissionService permissionService;
    late MockIsarDirectoryDataSource isarDirectoryDataSource;
    late MockIsarMediaDataSource isarMediaDataSource;

    setUp(() {
      localDirectoryDataSource = MockLocalDirectoryDataSource();
      filesystemMediaDataSource = MockFilesystemMediaDataSource();
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
        filesystemMediaDataSource,
      );
    });

    group('addDirectory', () {
      test('preserves existing tag assignments when updating a known directory',
          () async {
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
        when(localDirectoryDataSource.validateDirectory(any))
            .thenAnswer((_) async => true);
        when(bookmarkService.createBookmark(any))
            .thenThrow(UnsupportedError('not supported on platform'));
        when(permissionService.validateBookmark(any)).thenAnswer(
          (_) async => const BookmarkValidationResult(isValid: true),
        );
        when(isarDirectoryDataSource.updateDirectory(any))
            .thenAnswer((_) async {});
        when(isarMediaDataSource.migrateDirectoryId(any, any))
            .thenAnswer((_) async {});

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
            verify(isarDirectoryDataSource.updateDirectory(captureAny))
                .captured
                .single as DirectoryModel;

        expect(capturedModel.tagIds, equals(existingModel.tagIds));
        expect(capturedModel.bookmarkData, equals(existingModel.bookmarkData));
      });
    });

    group('getDirectoryById', () {
      test('returns entity when data source finds a matching directory',
          () async {
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
        when(isarMediaDataSource.migrateDirectoryId(any, any))
            .thenAnswer((_) async {});
        when(isarDirectoryDataSource.removeDirectory(any))
            .thenAnswer((_) async {});
        when(isarDirectoryDataSource.addDirectory(any))
            .thenAnswer((_) async {});

        final entity = await repository.getDirectoryById(stableId);

        expect(entity, isNotNull);
        expect(entity!.id, stableId);
        expect(entity.tagIds, ['tag-legacy']);
        verify(isarDirectoryDataSource.getDirectories()).called(1);
        verify(isarMediaDataSource.migrateDirectoryId('legacy-id', stableId))
            .called(1);
        verify(isarDirectoryDataSource.removeDirectory('legacy-id')).called(1);
        verify(isarDirectoryDataSource.addDirectory(any)).called(1);
      });
    });

    group('updateDirectoryMetadata', () {
      test('preserves existing bookmark when new value is not provided',
          () async {
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
        when(isarDirectoryDataSource.updateDirectory(any))
            .thenAnswer((_) async {});

        await repository.updateDirectoryMetadata(
          directoryId,
          name: 'Renamed directory',
        );

        final captured = verify(isarDirectoryDataSource.updateDirectory(
          captureAny,
        )).captured.single as DirectoryModel;

        expect(captured.bookmarkData, equals(existingModel.bookmarkData));
      });
    });

    group('refreshChangedLibraryRoots', () {
      test('skips full media rescans for unchanged roots', () async {
        final model = _directoryModel(
          path: '/library/unchanged',
          lastKnownTreeModified: DateTime(2024, 1, 2),
          lastKnownChildDirectoryCount: 3,
          lastKnownMediaFileCount: 8,
        );

        when(isarDirectoryDataSource.getDirectories())
            .thenAnswer((_) async => [model]);
        when(localDirectoryDataSource.fingerprintDirectoryTree(any)).thenAnswer(
          (_) async => DirectoryTreeFingerprint(
            lastKnownTreeModified: DateTime(2024, 1, 2),
            lastKnownChildDirectoryCount: 3,
            lastKnownMediaFileCount: 8,
          ),
        );

        await repository.refreshChangedLibraryRoots();

        verify(localDirectoryDataSource.fingerprintDirectoryTree(any)).called(1);
        verifyNever(
          filesystemMediaDataSource.scanMediaForDirectory(
            any,
            any,
            bookmarkData: anyNamed('bookmarkData'),
          ),
        );
        verifyNever(isarMediaDataSource.removeMediaForDirectory(any));
        verifyNever(isarDirectoryDataSource.updateDirectory(any));
      });

      test('rescans changed roots and persists refreshed metadata', () async {
        final model = _directoryModel(
          path: '/library/changed',
          lastKnownTreeModified: DateTime(2024, 1, 2),
          lastKnownChildDirectoryCount: 1,
          lastKnownMediaFileCount: 1,
        );
        final rescannedMedia = [
          _mediaModel(path: '/library/changed/nested/new.jpg', directoryId: model.id),
        ];

        when(isarDirectoryDataSource.getDirectories())
            .thenAnswer((_) async => [model]);
        when(localDirectoryDataSource.fingerprintDirectoryTree(any)).thenAnswer(
          (_) async => DirectoryTreeFingerprint(
            lastKnownTreeModified: DateTime(2024, 1, 3),
            lastKnownChildDirectoryCount: 2,
            lastKnownMediaFileCount: 2,
          ),
        );
        when(
          filesystemMediaDataSource.scanMediaForDirectory(
            any,
            any,
            bookmarkData: anyNamed('bookmarkData'),
          ),
        ).thenAnswer((_) async => rescannedMedia);
        when(isarMediaDataSource.getMediaForDirectory(model.id))
            .thenAnswer((_) async => <MediaModel>[]);
        when(isarMediaDataSource.removeMediaForDirectory(model.id))
            .thenAnswer((_) async {});
        when(isarMediaDataSource.addMedia(any)).thenAnswer((_) async {});
        when(isarDirectoryDataSource.updateDirectory(any))
            .thenAnswer((_) async {});

        await repository.refreshChangedLibraryRoots();

        verify(
          filesystemMediaDataSource.scanMediaForDirectory(
            model.path,
            model.id,
            bookmarkData: model.bookmarkData,
          ),
        ).called(1);
        verify(isarMediaDataSource.removeMediaForDirectory(model.id)).called(1);
        verify(isarMediaDataSource.addMedia(rescannedMedia)).called(1);

        final updatedModel =
            verify(isarDirectoryDataSource.updateDirectory(captureAny))
                .captured
                .single as DirectoryModel;
        expect(updatedModel.lastKnownTreeModified, DateTime(2024, 1, 3));
        expect(updatedModel.lastKnownChildDirectoryCount, 2);
        expect(updatedModel.lastKnownMediaFileCount, 2);
        expect(updatedModel.lastScanAt, isNotNull);
      });

      test('removes stale cached media rows for deleted files', () async {
        final model = _directoryModel(
          path: '/library/deleted',
          lastKnownTreeModified: DateTime(2024, 1, 2),
          lastKnownChildDirectoryCount: 0,
          lastKnownMediaFileCount: 2,
        );
        final persistedMedia = [
          _mediaModel(path: '/library/deleted/keep.jpg', directoryId: model.id),
          _mediaModel(path: '/library/deleted/remove.jpg', directoryId: model.id),
        ];
        final rescannedMedia = [
          _mediaModel(path: '/library/deleted/keep.jpg', directoryId: model.id),
        ];

        when(isarDirectoryDataSource.getDirectories())
            .thenAnswer((_) async => [model]);
        when(localDirectoryDataSource.fingerprintDirectoryTree(any)).thenAnswer(
          (_) async => DirectoryTreeFingerprint(
            lastKnownTreeModified: DateTime(2024, 1, 4),
            lastKnownChildDirectoryCount: 0,
            lastKnownMediaFileCount: 1,
          ),
        );
        when(
          filesystemMediaDataSource.scanMediaForDirectory(
            any,
            any,
            bookmarkData: anyNamed('bookmarkData'),
          ),
        ).thenAnswer((_) async => rescannedMedia);
        when(isarMediaDataSource.getMediaForDirectory(model.id))
            .thenAnswer((_) async => persistedMedia);
        when(isarMediaDataSource.removeMediaForDirectory(model.id))
            .thenAnswer((_) async {});
        when(isarMediaDataSource.addMedia(any)).thenAnswer((_) async {});
        when(isarDirectoryDataSource.updateDirectory(any))
            .thenAnswer((_) async {});

        await repository.refreshChangedLibraryRoots();

        verify(isarMediaDataSource.removeMediaForDirectory(model.id)).called(1);
        final addedMedia = verify(isarMediaDataSource.addMedia(captureAny))
            .captured
            .single as List<MediaModel>;
        expect(addedMedia, hasLength(1));
        expect(addedMedia.single.path, '/library/deleted/keep.jpg');
      });

      test('continues refreshing other roots after one access failure',
          () async {
        final failedModel = _directoryModel(path: '/library/failing');
        final refreshedModel = _directoryModel(
          path: '/library/ok',
          lastKnownTreeModified: DateTime(2024, 1, 1),
          lastKnownChildDirectoryCount: 0,
          lastKnownMediaFileCount: 0,
        );

        when(isarDirectoryDataSource.getDirectories()).thenAnswer(
          (_) async => [failedModel, refreshedModel],
        );
        when(localDirectoryDataSource.fingerprintDirectoryTree(any)).thenAnswer(
          (invocation) async {
            final directory = invocation.positionalArguments.single as DirectoryEntity;
            if (directory.id == failedModel.id) {
              throw const DirectoryAccessDeniedError('no access');
            }
            return DirectoryTreeFingerprint(
              lastKnownTreeModified: DateTime(2024, 1, 5),
              lastKnownChildDirectoryCount: 1,
              lastKnownMediaFileCount: 1,
            );
          },
        );
        when(
          filesystemMediaDataSource.scanMediaForDirectory(
            refreshedModel.path,
            refreshedModel.id,
            bookmarkData: refreshedModel.bookmarkData,
          ),
        ).thenAnswer(
          (_) async => [_mediaModel(path: '/library/ok/file.jpg', directoryId: refreshedModel.id)],
        );
        when(isarMediaDataSource.getMediaForDirectory(refreshedModel.id))
            .thenAnswer((_) async => <MediaModel>[]);
        when(isarMediaDataSource.removeMediaForDirectory(refreshedModel.id))
            .thenAnswer((_) async {});
        when(isarMediaDataSource.addMedia(any)).thenAnswer((_) async {});
        when(isarDirectoryDataSource.updateDirectory(any))
            .thenAnswer((_) async {});

        await repository.refreshChangedLibraryRoots();

        verify(
          filesystemMediaDataSource.scanMediaForDirectory(
            refreshedModel.path,
            refreshedModel.id,
            bookmarkData: refreshedModel.bookmarkData,
          ),
        ).called(1);
        verifyNever(
          filesystemMediaDataSource.scanMediaForDirectory(
            failedModel.path,
            failedModel.id,
            bookmarkData: failedModel.bookmarkData,
          ),
        );
      });
    });
  });
}

DirectoryModel _directoryModel({
  required String path,
  DateTime? lastKnownTreeModified,
  int? lastKnownChildDirectoryCount,
  int? lastKnownMediaFileCount,
}) {
  return DirectoryModel(
    id: generateDirectoryId(path),
    path: path,
    name: path.split('/').last,
    thumbnailPath: null,
    tagIds: const [],
    lastModified: DateTime(2024, 1, 1),
    bookmarkData: null,
    lastKnownTreeModified: lastKnownTreeModified,
    lastKnownChildDirectoryCount: lastKnownChildDirectoryCount,
    lastKnownMediaFileCount: lastKnownMediaFileCount,
  );
}

MediaModel _mediaModel({required String path, required String directoryId}) {
  return MediaModel(
    id: generateDirectoryId(path),
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 128,
    lastModified: DateTime(2024, 1, 1),
    tagIds: const [],
    directoryId: directoryId,
  );
}

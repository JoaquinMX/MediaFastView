import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/services/permission_service.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/filesystem_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/repositories/filesystem_media_repository_impl.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart' show MediaType;
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';

class _MockDirectoryRepository extends Mock implements DirectoryRepository {}

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

class _MockBookmarkService extends Mock implements BookmarkService {}

class _MockFilesystemMediaDataSource extends Mock
    implements FilesystemMediaDataSource {}

class _MockPermissionService extends Mock implements PermissionService {}

void main() {
  late FilesystemMediaRepositoryImpl repository;
  late _MockBookmarkService bookmarkService;
  late _MockDirectoryRepository directoryRepository;
  late _MockFilesystemMediaDataSource filesystemDataSource;
  late _MockPermissionService permissionService;
  late _MockIsarMediaDataSource isarMediaDataSource;

  setUp(() {
    bookmarkService = _MockBookmarkService();
    directoryRepository = _MockDirectoryRepository();
    filesystemDataSource = _MockFilesystemMediaDataSource();
    permissionService = _MockPermissionService();
    isarMediaDataSource = _MockIsarMediaDataSource();

    when(isarMediaDataSource.getMedia()).thenAnswer((_) async => <MediaModel>[]);
    when(isarMediaDataSource.getMediaForDirectory(any)).thenAnswer((_) async => <MediaModel>[]);
    when(isarMediaDataSource.saveMedia(any)).thenAnswer((_) async {});
    when(isarMediaDataSource.upsertMedia(any)).thenAnswer((_) async {});
    when(isarMediaDataSource.updateMediaTags(any, any)).thenAnswer((_) async {});
    when(isarMediaDataSource.removeMediaForDirectory(any)).thenAnswer((_) async {});
    when(isarMediaDataSource.migrateDirectoryId(any, any)).thenAnswer((_) async {});

    repository = FilesystemMediaRepositoryImpl(
      bookmarkService,
      directoryRepository,
      isarMediaDataSource,
      permissionService: permissionService,
      filesystemDataSource: filesystemDataSource,
    );
  });

  group('getMediaById', () {
    test('merges persisted tag IDs with refreshed media', () async {
      final directoryPath = '/test/directory';
      final directoryId = generateDirectoryId(directoryPath);
      final persistedModel = MediaModel(
        id: 'media-1',
        path: '$directoryPath/file.jpg',
        name: 'file.jpg',
        type: MediaType.image,
        size: 512,
        lastModified: DateTime(2024),
        tagIds: const ['tag-a'],
        directoryId: directoryId,
      );
      final refreshedModel = persistedModel.copyWith(
        size: 1024,
        tagIds: const [],
      );
      final directory = DirectoryEntity(
        id: directoryId,
        path: directoryPath,
        name: 'directory',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: DateTime(2024),
      );

      when(isarMediaDataSource.getMedia()).thenAnswer((_) async => [persistedModel]);
      when(directoryRepository.getDirectoryById(directoryId)).thenAnswer((_) async => directory);
      when(filesystemDataSource.getMediaById(
        any,
        any,
        any,
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((_) async => refreshedModel);

      final result = await repository.getMediaById('media-1');

      expect(result, isNotNull);
      expect(result!.tagIds, equals(const ['tag-a']));
      expect(result.size, equals(1024));
    });

    test('falls back to persisted data when rescan fails', () async {
      final directoryPath = '/test/directory';
      final directoryId = generateDirectoryId(directoryPath);
      final persistedModel = MediaModel(
        id: 'media-2',
        path: '$directoryPath/file2.jpg',
        name: 'file2.jpg',
        type: MediaType.image,
        size: 256,
        lastModified: DateTime(2024),
        tagIds: const ['tag-b'],
        directoryId: directoryId,
      );
      final directory = DirectoryEntity(
        id: directoryId,
        path: directoryPath,
        name: 'directory',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: DateTime(2024),
      );

      when(isarMediaDataSource.getMedia()).thenAnswer((_) async => [persistedModel]);
      when(directoryRepository.getDirectoryById(directoryId)).thenAnswer((_) async => directory);
      when(filesystemDataSource.getMediaById(
        any,
        any,
        any,
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((_) async => null);

      final result = await repository.getMediaById('media-2');

      expect(result, isNotNull);
      expect(result!.tagIds, equals(const ['tag-b']));
      expect(result.size, equals(256));
    });

    test('scans directories when media is not persisted locally', () async {
      final directoryPath = '/fallback/directory';
      final directoryId = generateDirectoryId(directoryPath);
      final directory = DirectoryEntity(
        id: directoryId,
        path: directoryPath,
        name: 'fallback',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: DateTime(2024),
      );
      final scannedModel = MediaModel(
        id: 'media-3',
        path: '$directoryPath/file3.jpg',
        name: 'file3.jpg',
        type: MediaType.image,
        size: 2048,
        lastModified: DateTime(2024),
        tagIds: const ['tag-c'],
        directoryId: directoryId,
      );

      when(isarMediaDataSource.getMedia()).thenAnswer((_) async => []);
      when(directoryRepository.getDirectories()).thenAnswer((_) async => [directory]);
      when(filesystemDataSource.getMediaById(
        any,
        any,
        any,
        bookmarkData: anyNamed('bookmarkData'),
      )).thenAnswer((invocation) async {
        final requestedDirectoryId = invocation.positionalArguments[2] as String;
        if (requestedDirectoryId == directoryId) {
          return scannedModel;
        }
        return null;
      });

      final result = await repository.getMediaById('media-3');

      expect(result, isNotNull);
      expect(result!.tagIds, equals(const ['tag-c']));
      expect(result.size, equals(2048));
      verify(directoryRepository.getDirectories()).called(1);
    });
  });
}

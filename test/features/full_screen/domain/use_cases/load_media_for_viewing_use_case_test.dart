import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/full_screen/domain/use_cases/load_media_for_viewing_use_case.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/filesystem_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

class _StubFilesystemMediaDataSource extends FilesystemMediaDataSource {
  _StubFilesystemMediaDataSource(
    super.bookmarkService,
    super.permissionService, {
    required this.mediaToReturn,
    PermissionValidationResult? validationResult,
  })  : _validationResult =
            validationResult ?? const PermissionValidationResult(canAccess: true, requiresRecovery: false);

  final List<MediaModel> mediaToReturn;
  final PermissionValidationResult _validationResult;

  @override
  Future<PermissionValidationResult> validateDirectoryAccess(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    return _validationResult;
  }

  @override
  Future<List<MediaModel>> scanMediaForDirectory(
    String directoryPath,
    String directoryId, {
    String? bookmarkData,
  }) async {
    return mediaToReturn;
  }
}

void main() {
  group('LoadMediaForViewingUseCase', () {
    late _MockIsarMediaDataSource mediaDataSource;

    setUp(() {
      mediaDataSource = _MockIsarMediaDataSource();
    });

    test('preserves persisted tag assignments when scanning media', () async {
      const directoryId = 'directory-1';
      final scannedModel = MediaModel(
        id: 'media-1',
        path: '/tmp/media-1.jpg',
        name: 'media-1.jpg',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime(2024, 1, 1),
        directoryId: directoryId,
      );
      final persistedModel = scannedModel.copyWith(tagIds: const ['tag-a']);

      when(mediaDataSource.getMediaForDirectory(directoryId))
          .thenAnswer((_) async => [persistedModel]);
      when(mediaDataSource.upsertMedia(any)).thenAnswer((_) async {});

      final useCase = LoadMediaForViewingUseCase(
        mediaDataSource,
        filesystemDataSourceFactory: (bookmarkService, permissionService) =>
            _StubFilesystemMediaDataSource(
          bookmarkService,
          permissionService,
          mediaToReturn: [scannedModel],
        ),
      );

      final result = await useCase('/tmp', directoryId);

      verify(mediaDataSource.getMediaForDirectory(directoryId)).called(1);
      final capturedModels = verify(mediaDataSource.upsertMedia(captureAny))
          .captured
          .single as List<MediaModel>;

      expect(result, hasLength(1));
      expect(result.first.tagIds, ['tag-a']);
      expect(capturedModels, hasLength(1));
      expect(capturedModels.first.tagIds, ['tag-a']);
    });

    test('merges new scan tags with persisted tags', () async {
      const directoryId = 'directory-1';
      final scannedModel = MediaModel(
        id: 'media-1',
        path: '/tmp/media-1.jpg',
        name: 'media-1.jpg',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime(2024, 1, 1),
        directoryId: directoryId,
        tagIds: const ['fresh-tag'],
      );
      final persistedModel = scannedModel.copyWith(tagIds: const ['saved-tag']);

      when(mediaDataSource.getMediaForDirectory(directoryId))
          .thenAnswer((_) async => [persistedModel]);
      when(mediaDataSource.upsertMedia(any)).thenAnswer((_) async {});

      final useCase = LoadMediaForViewingUseCase(
        mediaDataSource,
        filesystemDataSourceFactory: (bookmarkService, permissionService) =>
            _StubFilesystemMediaDataSource(
          bookmarkService,
          permissionService,
          mediaToReturn: [scannedModel],
        ),
      );

      final result = await useCase('/tmp', directoryId);

      final capturedModels = verify(mediaDataSource.upsertMedia(captureAny))
          .captured
          .single as List<MediaModel>;

      expect(result, hasLength(1));
      expect(result.first.tagIds, ['fresh-tag', 'saved-tag']);
      expect(capturedModels, hasLength(1));
      expect(capturedModels.first.tagIds, ['fresh-tag', 'saved-tag']);
    });
  });
}

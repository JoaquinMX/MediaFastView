import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/set_directory_cover_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/set_directory_no_cover_use_case.dart';

class _RecordingCoverRepository implements DirectoryCoverRepository {
  DirectoryCoverEntity? saved;

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async => saved = cover;

  @override
  Future<void> clearCovers() async {}

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async => saved;

  @override
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) async {}

  @override
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) async {}

  @override
  Future<void> removeCover(String directoryPath) async => saved = null;

  @override
  Future<void> removeCoverForSource(String sourcePath) async {}

  @override
  Future<void> removeCoversUnder(String directoryPath) async {}
}

MediaEntity _media(String path, MediaType type) {
  return MediaEntity(
    id: path,
    path: path,
    name: path.split('/').last,
    type: type,
    size: 1,
    lastModified: DateTime(2025),
    tagIds: const <String>[],
    directoryId: 'directory',
  );
}

void main() {
  test(
    'persists one through four direct-child images in selection order',
    () async {
      final repository = _RecordingCoverRepository();
      final useCase = SetDirectoryCoverUseCase(repository);

      for (var count = 1; count <= 4; count += 1) {
        final images = <MediaEntity>[
          for (var index = 0; index < count; index += 1)
            _media('/library/folder/cover-$index.jpg', MediaType.image),
        ];

        await useCase(directoryPath: '/library/folder', images: images);

        expect(repository.saved?.directoryPath, '/library/folder');
        expect(
          repository.saved?.sourceFileNames,
          images.map((image) => image.name).toList(),
        );
        expect(
          repository.saved?.selections.map((selection) => selection.mediaType),
          everyElement(MediaType.image),
        );
      }
    },
  );

  test(
    'rejects empty, excessive, unsupported, nested, and excluded images',
    () {
      final useCase = SetDirectoryCoverUseCase(_RecordingCoverRepository());

      expect(
        () => useCase(
          directoryPath: '/library/folder',
          images: const <MediaEntity>[],
        ),
        throwsArgumentError,
      );
      expect(
        () => useCase(
          directoryPath: '/library/folder',
          images: <MediaEntity>[
            for (var index = 0; index < 5; index += 1)
              _media('/library/folder/$index.jpg', MediaType.image),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => useCase(
          directoryPath: '/library/folder',
          images: <MediaEntity>[
            _media('/library/folder/video.mp4', MediaType.video),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => useCase(
          directoryPath: '/library/folder',
          images: <MediaEntity>[
            _media('/library/folder/nested/cover.jpg', MediaType.image),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => useCase(
          directoryPath: '/library/folder',
          images: <MediaEntity>[
            _media('/library/folder/._cover.jpg', MediaType.image),
          ],
        ),
        throwsArgumentError,
      );
    },
  );

  test('persists no cover as a distinct override', () async {
    final repository = _RecordingCoverRepository();

    await SetDirectoryNoCoverUseCase(repository)('/library/folder');

    expect(repository.saved?.directoryPath, '/library/folder');
    expect(repository.saved?.mode, DirectoryCoverMode.none);
    expect(repository.saved?.sourceFileName, isNull);
  });
}

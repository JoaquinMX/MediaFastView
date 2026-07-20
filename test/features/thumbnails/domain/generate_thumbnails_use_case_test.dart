import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/thumbnails/data/native_thumbnail_generator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/generate_thumbnails_use_case.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_batch_progress.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';

class _MediaRepositoryFake extends Fake implements MediaRepository {
  _MediaRepositoryFake(this.media);

  final List<MediaEntity> media;

  @override
  Future<List<MediaEntity>> getAllMedia() async => media;
}

class _DirectoryRepositoryFake extends Fake implements DirectoryRepository {
  _DirectoryRepositoryFake(this.directories);

  final List<DirectoryEntity> directories;

  @override
  Future<List<DirectoryEntity>> getDirectories() async => directories;
}

class _GeneratorFake implements ThumbnailGenerator {
  final List<ThumbnailRequest> requests = <ThumbnailRequest>[];

  @override
  Future<NativeThumbnail> generate(
    ThumbnailRequest request, {
    required String requestId,
  }) async {
    requests.add(request);
    return NativeThumbnail(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      fileExtension: 'jpg',
    );
  }

  @override
  Future<void> cancel(String requestId) async {}
}

class _FailingWriteCache extends ThumbnailDiskCache {
  _FailingWriteCache({required super.directoryResolver});

  @override
  Future<File> write(ThumbnailRequest request, List<int> bytes) {
    throw const FileSystemException('Disk unavailable');
  }
}

MediaEntity _media(String path, MediaType type) {
  return MediaEntity(
    id: path,
    path: path,
    name: path.split('/').last,
    type: type,
    size: 10,
    lastModified: DateTime.utc(2025),
    tagIds: const <String>[],
    directoryId: 'library',
  );
}

void main() {
  late Directory temporaryDirectory;
  late ThumbnailDiskCache cache;
  late _GeneratorFake generator;
  late ThumbnailCoordinator coordinator;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-thumbnail-batch-',
    );
    cache = ThumbnailDiskCache(
      directoryResolver: () async => temporaryDirectory,
    );
    generator = _GeneratorFake();
    coordinator = ThumbnailCoordinator(generator: generator, cache: cache);
  });

  tearDown(() async {
    await coordinator.dispose();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'generates only images and videos with the enclosing bookmark',
    () async {
      final mediaRepository = _MediaRepositoryFake(<MediaEntity>[
        _media('/Photos/2025/image.jpg', MediaType.image),
        _media('/Photos/2025/video.mov', MediaType.video),
        _media('/Photos/notes.txt', MediaType.text),
      ]);
      final directoryRepository = _DirectoryRepositoryFake(<DirectoryEntity>[
        DirectoryEntity(
          id: 'photos',
          path: '/Photos',
          name: 'Photos',
          thumbnailPath: null,
          tagIds: const <String>[],
          lastModified: DateTime.utc(2025),
          bookmarkData: 'photos-bookmark',
        ),
      ]);
      final progressEvents = <ThumbnailBatchProgress>[];
      final useCase = GenerateThumbnailsUseCase(
        mediaRepository: mediaRepository,
        directoryRepository: directoryRepository,
        coordinator: coordinator,
        cache: cache,
      );

      final result = await useCase(
        cancellationToken: ThumbnailCancellationToken(),
        onProgress: progressEvents.add,
      );

      expect(result.status, ThumbnailBatchStatus.completed);
      expect(result.total, 2);
      expect(result.completed, 2);
      expect(result.generated, 2);
      expect(result.failed, 0);
      expect(generator.requests, hasLength(2));
      expect(
        generator.requests.map((request) => request.bookmarkData).toSet(),
        <String?>{'photos-bookmark'},
      );
      expect(
        generator.requests.map((request) => request.thumbnailSize).toSet(),
        <ThumbnailSize>{ThumbnailSize.medium},
      );
      expect(progressEvents.last.status, ThumbnailBatchStatus.completed);
    },
  );

  test('reports existing entries as cache hits on a second run', () async {
    final useCase = GenerateThumbnailsUseCase(
      mediaRepository: _MediaRepositoryFake(<MediaEntity>[
        _media('/Photos/image.jpg', MediaType.image),
      ]),
      directoryRepository: _DirectoryRepositoryFake(const <DirectoryEntity>[]),
      coordinator: coordinator,
      cache: cache,
    );

    await useCase(cancellationToken: ThumbnailCancellationToken());
    final result = await useCase(
      cancellationToken: ThumbnailCancellationToken(),
    );

    expect(result.cacheHits, 1);
    expect(result.generated, 0);
    expect(generator.requests, hasLength(1));
  });

  test(
    'reports a failed disk write instead of a generated cache entry',
    () async {
      final failingCache = _FailingWriteCache(
        directoryResolver: () async => temporaryDirectory,
      );
      final failingCoordinator = ThumbnailCoordinator(
        generator: generator,
        cache: failingCache,
      );
      addTearDown(failingCoordinator.dispose);
      final useCase = GenerateThumbnailsUseCase(
        mediaRepository: _MediaRepositoryFake(<MediaEntity>[
          _media('/Photos/image.jpg', MediaType.image),
        ]),
        directoryRepository: _DirectoryRepositoryFake(
          const <DirectoryEntity>[],
        ),
        coordinator: failingCoordinator,
        cache: failingCache,
      );

      final result = await useCase(
        cancellationToken: ThumbnailCancellationToken(),
      );

      expect(result.completed, 1);
      expect(result.generated, 0);
      expect(result.failed, 1);
    },
  );
}

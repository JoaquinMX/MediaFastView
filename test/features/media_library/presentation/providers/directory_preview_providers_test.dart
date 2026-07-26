import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/providers/settings_providers.dart';
import 'package:media_fast_view/shared/providers/active_profile_provider.dart';

class _FakeFileService extends FileService {
  _FakeFileService(this._contentsByPath);

  final Map<String, List<FileSystemEntity>> _contentsByPath;
  final Map<String, int> _readCounts = <String, int>{};

  int readCountForPath(String path) {
    return _readCounts[path] ?? 0;
  }

  @override
  Future<List<FileSystemEntity>> getDirectoryContents(
    String directoryPath,
  ) async {
    _readCounts[directoryPath] = (_readCounts[directoryPath] ?? 0) + 1;
    return _contentsByPath[directoryPath] ?? <FileSystemEntity>[];
  }
}

class _FakeThumbnailDiskCache extends ThumbnailDiskCache {
  _FakeThumbnailDiskCache(this._thumbnailPaths);

  final Map<String, String> _thumbnailPaths;
  final List<ThumbnailRequest> requests = <ThumbnailRequest>[];

  @override
  Future<File?> read(ThumbnailRequest request) async {
    requests.add(request);
    final thumbnailPath = _thumbnailPaths[request.path];
    return thumbnailPath == null ? null : File(thumbnailPath);
  }
}

class _FakeDirectoryCoverRepository implements DirectoryCoverRepository {
  _FakeDirectoryCoverRepository([this.cover]);

  DirectoryCoverEntity? cover;

  @override
  Future<void> clearCovers() async => cover = null;

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async {
    return cover?.directoryPath == directoryPath ? cover : null;
  }

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
  Future<void> removeCover(String directoryPath) async => cover = null;

  @override
  Future<void> removeCoverForSource(String sourcePath) async => cover = null;

  @override
  Future<void> removeCoversUnder(String directoryPath) async => cover = null;

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {
    this.cover = cover;
  }
}

ProviderContainer _createContainer({
  required FileService fileService,
  required ThumbnailDiskCache thumbnailDiskCache,
  bool diskCacheEnabled = true,
  DirectoryCoverRepository? directoryCoverRepository,
}) {
  return ProviderContainer(
    overrides: <Override>[
      fileServiceProvider.overrideWithValue(fileService),
      thumbnailDiskCacheProvider.overrideWithValue(thumbnailDiskCache),
      thumbnailDiskCacheEnabledProvider.overrideWithValue(diskCacheEnabled),
      directoryCoverRepositoryProvider.overrideWithValue(
        directoryCoverRepository ?? _FakeDirectoryCoverRepository(),
      ),
      activeProfileIdProvider.overrideWith(
        () => ActiveProfileIdNotifier('test-profile'),
      ),
    ],
  );
}

void main() {
  test('prefers a custom video even when disk caching is disabled', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-custom-cover-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final video = File('${temporaryDirectory.path}/chosen.mp4');
    await video.writeAsBytes(<int>[1, 2, 3]);
    final cover = DirectoryCoverEntity.media(
      directoryPath: temporaryDirectory.path,
      sourceFileName: 'chosen.mp4',
      mediaType: MediaType.video,
      updatedAt: DateTime(2025),
    );
    final container = _createContainer(
      fileService: _FakeFileService(<String, List<FileSystemEntity>>{
        temporaryDirectory.path: <FileSystemEntity>[
          File('${temporaryDirectory.path}/automatic.jpg'),
          video,
        ],
      }),
      thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
      diskCacheEnabled: false,
      directoryCoverRepository: _FakeDirectoryCoverRepository(cover),
    );
    addTearDown(container.dispose);

    final preview = await container.read(
      directoryPreviewProvider(temporaryDirectory.path).future,
    );

    expect(preview, isA<DirectoryCustomPreview>());
    expect((preview as DirectoryCustomPreview).media.path, video.path);
    expect(preview.media.type, MediaType.video);
  });

  test('suppresses automatic previews when no cover is selected', () async {
    const directoryPath = '/tmp/no-cover-directory';
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      directoryPath: <FileSystemEntity>[File('$directoryPath/automatic.jpg')],
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
      directoryCoverRepository: _FakeDirectoryCoverRepository(
        DirectoryCoverEntity.none(
          directoryPath: directoryPath,
          updatedAt: DateTime(2025),
        ),
      ),
    );
    addTearDown(container.dispose);

    final preview = await container.read(
      directoryPreviewProvider(directoryPath).future,
    );
    final strip = await container.read(
      directoryPreviewStripProvider(directoryPath).future,
    );

    expect(preview, isNull);
    expect(strip.previews, isEmpty);
    expect(fileService.readCountForPath(directoryPath), 0);
  });

  test(
    'marks a missing custom cover stale and uses automatic fallback',
    () async {
      const directoryPath = '/tmp/missing-custom-cover';
      final cover = DirectoryCoverEntity.media(
        directoryPath: directoryPath,
        sourceFileName: 'missing.jpg',
        mediaType: MediaType.image,
        updatedAt: DateTime(2025),
      );
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directoryPath: <FileSystemEntity>[
            File('$directoryPath/automatic.jpg'),
          ],
        }),
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(cover),
      );
      addTearDown(container.dispose);

      final preview = await container.read(
        directoryPreviewProvider(directoryPath).future,
      );

      expect(preview, isA<DirectoryImagePreview>());
      expect(preview!.sourcePath, '$directoryPath/automatic.jpg');
      expect(preview.hasStaleCustomCover, isTrue);
    },
  );

  test('prefers the first image without reading video thumbnails', () async {
    const directoryPath = '/tmp/image-first-directory';
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      directoryPath: <FileSystemEntity>[
        File('$directoryPath/video.mp4'),
        File('$directoryPath/cover.jpg'),
      ],
    });
    final thumbnailDiskCache = _FakeThumbnailDiskCache(<String, String>{
      '$directoryPath/video.mp4': '/cache/video.jpg',
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: thumbnailDiskCache,
    );
    addTearDown(container.dispose);

    final preview = await container.read(
      directoryPreviewProvider(directoryPath).future,
    );

    expect(preview, isA<DirectoryImagePreview>());
    expect(preview?.sourcePath, '$directoryPath/cover.jpg');
    expect(thumbnailDiskCache.requests, isEmpty);
  });

  test('uses an existing medium video thumbnail', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-directory-preview-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final video = File('${temporaryDirectory.path}/clip.mp4');
    await video.writeAsBytes(<int>[1, 2, 3]);
    final thumbnailDiskCache = _FakeThumbnailDiskCache(<String, String>{
      video.path: '${temporaryDirectory.path}/cached.jpg',
    });
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      temporaryDirectory.path: <FileSystemEntity>[video],
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: thumbnailDiskCache,
    );
    addTearDown(container.dispose);

    final preview = await container.read(
      directoryPreviewProvider(temporaryDirectory.path).future,
    );

    expect(preview, isA<DirectoryVideoPreview>());
    expect(preview?.sourcePath, video.path);
    expect(
      (preview as DirectoryVideoPreview).thumbnailPath,
      '${temporaryDirectory.path}/cached.jpg',
    );
    expect(
      thumbnailDiskCache.requests.single.thumbnailSize,
      ThumbnailSize.medium,
    );
  });

  test('skips uncached videos and uses a later cache hit', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-directory-preview-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final firstVideo = File('${temporaryDirectory.path}/first.mp4');
    final secondVideo = File('${temporaryDirectory.path}/second.mov');
    await firstVideo.writeAsBytes(<int>[1]);
    await secondVideo.writeAsBytes(<int>[2]);
    final thumbnailDiskCache = _FakeThumbnailDiskCache(<String, String>{
      secondVideo.path: '${temporaryDirectory.path}/second.jpg',
    });
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      temporaryDirectory.path: <FileSystemEntity>[firstVideo, secondVideo],
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: thumbnailDiskCache,
    );
    addTearDown(container.dispose);

    final preview = await container.read(
      directoryPreviewProvider(temporaryDirectory.path).future,
    );

    expect(preview?.sourcePath, secondVideo.path);
    expect(thumbnailDiskCache.requests.map((request) => request.path), <String>[
      firstVideo.path,
      secondVideo.path,
    ]);
  });

  test('returns no preview for uncached videos', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-directory-preview-',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));
    final video = File('${temporaryDirectory.path}/clip.mp4');
    await video.writeAsBytes(<int>[1]);
    final thumbnailDiskCache = _FakeThumbnailDiskCache(<String, String>{});
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      temporaryDirectory.path: <FileSystemEntity>[video],
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: thumbnailDiskCache,
    );
    addTearDown(container.dispose);

    expect(
      await container.read(
        directoryPreviewProvider(temporaryDirectory.path).future,
      ),
      isNull,
    );
    expect(thumbnailDiskCache.requests, hasLength(1));
  });

  test(
    'does not consult video thumbnails when disk caching is disabled',
    () async {
      const directoryPath = '/tmp/cache-disabled-directory';
      final thumbnailDiskCache = _FakeThumbnailDiskCache(<String, String>{
        '$directoryPath/video.mp4': '/cache/video.jpg',
      });
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directoryPath: <FileSystemEntity>[File('$directoryPath/video.mp4')],
        }),
        thumbnailDiskCache: thumbnailDiskCache,
        diskCacheEnabled: false,
      );
      addTearDown(container.dispose);

      expect(
        await container.read(directoryPreviewProvider(directoryPath).future),
        isNull,
      );
      expect(thumbnailDiskCache.requests, isEmpty);
    },
  );

  test('reuses a preview during its TTL then refetches', () async {
    const directoryPath = '/tmp/preview-directory';
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      directoryPath: <FileSystemEntity>[File('$directoryPath/cover.jpg')],
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
    );
    addTearDown(container.dispose);

    final firstSubscription = container.listen<AsyncValue<DirectoryPreview?>>(
      directoryPreviewProvider(directoryPath),
      (_, __) {},
      fireImmediately: true,
    );
    expect(
      await container.read(directoryPreviewProvider(directoryPath).future),
      isA<DirectoryImagePreview>(),
    );
    expect(fileService.readCountForPath(directoryPath), 1);
    firstSubscription.close();

    await Future<void>.delayed(const Duration(milliseconds: 100));
    await container.pump();

    final secondSubscription = container.listen<AsyncValue<DirectoryPreview?>>(
      directoryPreviewProvider(directoryPath),
      (_, __) {},
      fireImmediately: true,
    );
    expect(
      await container.read(directoryPreviewProvider(directoryPath).future),
      isA<DirectoryImagePreview>(),
    );
    expect(fileService.readCountForPath(directoryPath), 1);
    secondSubscription.close();

    await Future<void>.delayed(const Duration(milliseconds: 650));
    await container.pump();

    final thirdSubscription = container.listen<AsyncValue<DirectoryPreview?>>(
      directoryPreviewProvider(directoryPath),
      (_, __) {},
      fireImmediately: true,
    );
    expect(
      await container.read(directoryPreviewProvider(directoryPath).future),
      isA<DirectoryImagePreview>(),
    );
    expect(fileService.readCountForPath(directoryPath), 2);
    thirdSubscription.close();
  });
}

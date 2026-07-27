import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_cover_controller.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/active_profile_provider.dart';
import 'package:media_fast_view/shared/providers/media_mutation_bus.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/providers/settings_providers.dart';

class _FakeFileService extends FileService {
  _FakeFileService(
    this.contentsByPath, {
    this.failPaths = const <String>{},
    this.onFileStat,
  });

  final Map<String, List<FileSystemEntity>> contentsByPath;
  final Set<String> failPaths;
  final void Function(String filePath)? onFileStat;
  final Map<String, int> _readCounts = <String, int>{};

  int readCountForPath(String path) => _readCounts[path] ?? 0;

  @override
  Future<List<FileSystemEntity>> getDirectoryContents(
    String directoryPath,
  ) async {
    _readCounts[directoryPath] = (_readCounts[directoryPath] ?? 0) + 1;
    if (failPaths.contains(directoryPath)) {
      throw const FileSystemException('Cannot scan directory');
    }
    return contentsByPath[directoryPath] ?? <FileSystemEntity>[];
  }

  @override
  Future<FileStat> getFileStat(String filePath) async {
    onFileStat?.call(filePath);
    return File(filePath).stat();
  }
}

class _FakeThumbnailDiskCache extends ThumbnailDiskCache {
  _FakeThumbnailDiskCache(
    this.thumbnailPaths, {
    this.throwPaths = const <String>{},
  });

  final Map<String, String> thumbnailPaths;
  final Set<String> throwPaths;
  final List<ThumbnailRequest> requests = <ThumbnailRequest>[];

  @override
  Future<File?> read(ThumbnailRequest request) async {
    requests.add(request);
    if (throwPaths.contains(request.path)) {
      throw const FileSystemException('Cache entry unavailable');
    }
    final thumbnailPath = thumbnailPaths[request.path];
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

class _RecordingBookmarkAccess implements DirectoryPreviewBookmarkAccess {
  _RecordingBookmarkAccess(this.scopePath);

  final String scopePath;
  final List<String> startedBookmarks = <String>[];
  final List<String> stoppedBookmarks = <String>[];
  bool isAccessing = false;

  @override
  Future<String> startAccessingBookmark(String bookmarkData) async {
    startedBookmarks.add(bookmarkData);
    isAccessing = true;
    return scopePath;
  }

  @override
  Future<void> stopAccessingBookmark(String bookmarkData) async {
    stoppedBookmarks.add(bookmarkData);
    isAccessing = false;
  }
}

ProviderContainer _createContainer({
  required FileService fileService,
  required ThumbnailDiskCache thumbnailDiskCache,
  bool diskCacheEnabled = true,
  DirectoryCoverRepository? directoryCoverRepository,
  DirectoryPreviewBookmarkAccess? bookmarkAccess,
  String? inheritedBookmark,
}) {
  return ProviderContainer(
    overrides: <Override>[
      fileServiceProvider.overrideWithValue(fileService),
      thumbnailDiskCacheProvider.overrideWithValue(thumbnailDiskCache),
      thumbnailDiskCacheEnabledProvider.overrideWithValue(diskCacheEnabled),
      directoryCoverRepositoryProvider.overrideWithValue(
        directoryCoverRepository ?? _FakeDirectoryCoverRepository(),
      ),
      directoryPreviewInheritedBookmarkProvider.overrideWith(
        (ref, directoryPath) => inheritedBookmark,
      ),
      if (bookmarkAccess != null)
        directoryPreviewBookmarkAccessProvider.overrideWithValue(
          bookmarkAccess,
        ),
      activeProfileIdProvider.overrideWith(
        () => ActiveProfileIdNotifier('test-profile'),
      ),
    ],
  );
}

Future<File> _writeFile(Directory directory, String name) async {
  final file = File('${directory.path}/$name');
  await file.writeAsBytes(<int>[1, 2, 3]);
  return file;
}

DirectoryPreviewCatalogQuery _query(String directoryPath, {String? bookmark}) {
  return DirectoryPreviewCatalogQuery(
    directoryPath: directoryPath,
    bookmarkData: bookmark,
  );
}

MediaEntity _media(String path) {
  return MediaEntity(
    id: path,
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2025),
    tagIds: const <String>[],
    directoryId: 'directory',
  );
}

void main() {
  test('catalog queries have value equality for path and bookmark', () {
    expect(
      _query('/library/a', bookmark: 'scope'),
      _query('/library/a', bookmark: 'scope'),
    );
    expect(
      _query('/library/a', bookmark: 'scope').hashCode,
      _query('/library/a', bookmark: 'scope').hashCode,
    );
    expect(
      _query('/library/a'),
      isNot(_query('/library/a', bookmark: 'scope')),
    );
  });

  test(
    'orders custom, images, and cached videos and caps the catalog at five',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-order-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final custom = await _writeFile(directory, 'cover.mp4');
      final imageZ = await _writeFile(directory, 'z.jpg');
      final imageB = await _writeFile(directory, 'b.jpg');
      final imageA = await _writeFile(directory, 'a.png');
      final videoC = await _writeFile(directory, 'c.mp4');
      final videoD = await _writeFile(directory, 'd.mov');
      final cache = _FakeThumbnailDiskCache(<String, String>{
        videoC.path: '${directory.path}/c-cache.jpg',
        videoD.path: '${directory.path}/d-cache.jpg',
      });
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[
            imageZ,
            videoD,
            custom,
            imageB,
            videoC,
            imageA,
          ],
        }),
        thumbnailDiskCache: cache,
        directoryCoverRepository: _FakeDirectoryCoverRepository(
          DirectoryCoverEntity.media(
            directoryPath: directory.path,
            sourceFileName: 'cover.mp4',
            mediaType: MediaType.video,
            updatedAt: DateTime(2025),
          ),
        ),
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.previews, hasLength(5));
      expect(catalog.hasCustomCover, isTrue);
      expect(catalog.previews.first, isA<DirectoryCustomPreview>());
      expect(catalog.previews.map((preview) => preview.sourcePath), <String>[
        custom.path,
        imageA.path,
        imageB.path,
        imageZ.path,
        videoC.path,
      ]);
      expect(cache.requests.map((request) => request.path), <String>[
        videoC.path,
      ]);
      expect(cache.requests.single.thumbnailSize, ThumbnailSize.medium);
    },
  );

  test(
    'orders custom selections before automatic previews without duplicates',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-multi-custom-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final firstCustom = await _writeFile(directory, 'z-selected.jpg');
      final secondCustom = await _writeFile(directory, 'b-selected.jpg');
      final automaticA = await _writeFile(directory, 'a-automatic.jpg');
      final automaticC = await _writeFile(directory, 'c-automatic.jpg');
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[
            firstCustom,
            automaticC,
            secondCustom,
            automaticA,
          ],
        }),
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(
          DirectoryCoverEntity.images(
            directoryPath: directory.path,
            sourceFileNames: <String>['z-selected.jpg', 'b-selected.jpg'],
            updatedAt: DateTime(2025),
          ),
        ),
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.customPreviews, hasLength(2));
      expect(catalog.previews.map((preview) => preview.sourcePath), <String>[
        firstCustom.path,
        secondCustom.path,
        automaticA.path,
        automaticC.path,
      ]);
      expect(
        catalog.previews
            .map((preview) => preview.sourcePath.toLowerCase())
            .toSet(),
        hasLength(catalog.previews.length),
      );
    },
  );

  test(
    'retains valid custom selections and reports only proven missing entries',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-partial-custom-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final firstCustom = await _writeFile(directory, 'one.jpg');
      final secondCustom = await _writeFile(directory, 'three.jpg');
      final automatic = await _writeFile(directory, 'automatic.jpg');
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[
            automatic,
            secondCustom,
            firstCustom,
          ],
        }),
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(
          DirectoryCoverEntity.images(
            directoryPath: directory.path,
            sourceFileNames: <String>['one.jpg', 'missing.jpg', 'three.jpg'],
            updatedAt: DateTime(2025),
          ),
        ),
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.missingCustomCoverFileNames, <String>['missing.jpg']);
      expect(catalog.customPreviews, hasLength(2));
      expect(catalog.previews.map((preview) => preview.sourcePath), <String>[
        firstCustom.path,
        secondCustom.path,
        automatic.path,
      ]);
    },
  );

  test(
    'filters media-scan exclusions before ordering and video probing',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-exclusions-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final custom = await _writeFile(directory, 'cover.jpg');
      final customCompanion = await _writeFile(directory, '._cover.jpg');
      final image = await _writeFile(directory, 'image.jpg');
      final imageCompanion = await _writeFile(directory, '._image.jpg');
      final video = await _writeFile(directory, 'video.mp4');
      final videoCompanion = await _writeFile(directory, '._video.mp4');
      final statPaths = <String>[];
      final cache = _FakeThumbnailDiskCache(<String, String>{
        video.path: '${directory.path}/video-cache.jpg',
        videoCompanion.path: '${directory.path}/video-companion-cache.jpg',
      });
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[
            videoCompanion,
            imageCompanion,
            customCompanion,
            video,
            image,
            custom,
          ],
        }, onFileStat: statPaths.add),
        thumbnailDiskCache: cache,
        directoryCoverRepository: _FakeDirectoryCoverRepository(
          DirectoryCoverEntity.media(
            directoryPath: directory.path,
            sourceFileName: 'cover.jpg',
            mediaType: MediaType.image,
            updatedAt: DateTime(2025),
          ),
        ),
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.hasCustomCover, isTrue);
      expect(catalog.hasStaleCustomCover, isFalse);
      expect(catalog.previews.map((preview) => preview.sourcePath), <String>[
        custom.path,
        image.path,
        video.path,
      ]);
      expect(statPaths, <String>[custom.path, video.path]);
      expect(cache.requests.map((request) => request.path), <String>[
        video.path,
      ]);
    },
  );

  test(
    'treats a persisted excluded custom cover as stale after a scan',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-excluded-cover-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final excludedCover = await _writeFile(directory, '._cover.jpg');
      final automatic = await _writeFile(directory, 'photo.jpg');
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[excludedCover, automatic],
        }),
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(
          DirectoryCoverEntity.media(
            directoryPath: directory.path,
            sourceFileName: '._cover.jpg',
            mediaType: MediaType.image,
            updatedAt: DateTime(2025),
          ),
        ),
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.hasCustomCover, isFalse);
      expect(catalog.hasStaleCustomCover, isTrue);
      expect(catalog.previews.map((preview) => preview.sourcePath), <String>[
        automatic.path,
      ]);
    },
  );

  test('no cover returns an empty catalog without scanning', () async {
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

    final catalog = await container.read(
      directoryPreviewCatalogProvider(_query(directoryPath)).future,
    );

    expect(catalog.isEmpty, isTrue);
    expect(fileService.readCountForPath(directoryPath), 0);
  });

  test(
    'only marks a missing custom cover stale after a successful scan',
    () async {
      const directoryPath = '/tmp/missing-custom-cover';
      final cover = DirectoryCoverEntity.media(
        directoryPath: directoryPath,
        sourceFileName: 'missing.jpg',
        mediaType: MediaType.image,
        updatedAt: DateTime(2025),
      );
      final successful = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directoryPath: <FileSystemEntity>[
            File('$directoryPath/automatic.jpg'),
          ],
        }),
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(cover),
      );
      addTearDown(successful.dispose);
      final failed = _createContainer(
        fileService: _FakeFileService(
          <String, List<FileSystemEntity>>{},
          failPaths: const <String>{directoryPath},
        ),
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(cover),
      );
      addTearDown(failed.dispose);

      final availableCatalog = await successful.read(
        directoryPreviewCatalogProvider(_query(directoryPath)).future,
      );
      final unavailableCatalog = await failed.read(
        directoryPreviewCatalogProvider(_query(directoryPath)).future,
      );

      expect(availableCatalog.hasStaleCustomCover, isTrue);
      expect(availableCatalog.missingCustomCoverFileNames, <String>[
        'missing.jpg',
      ]);
      expect(availableCatalog.primaryPreview, isA<DirectoryImagePreview>());
      expect(unavailableCatalog.hasStaleCustomCover, isFalse);
      expect(unavailableCatalog.missingCustomCoverFileNames, isEmpty);
      expect(unavailableCatalog.isEmpty, isTrue);
    },
  );

  test('uses later cached videos after an isolated cache failure', () async {
    final directory = await Directory.systemTemp.createTemp(
      'media-fast-view-preview-video-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final first = await _writeFile(directory, 'a.mp4');
    final second = await _writeFile(directory, 'b.mov');
    final cache = _FakeThumbnailDiskCache(
      <String, String>{second.path: '${directory.path}/b-cache.jpg'},
      throwPaths: <String>{first.path},
    );
    final container = _createContainer(
      fileService: _FakeFileService(<String, List<FileSystemEntity>>{
        directory.path: <FileSystemEntity>[second, first],
      }),
      thumbnailDiskCache: cache,
    );
    addTearDown(container.dispose);

    final catalog = await container.read(
      directoryPreviewCatalogProvider(_query(directory.path)).future,
    );

    expect(catalog.previews, hasLength(1));
    expect(catalog.previews.single.sourcePath, second.path);
    expect(cache.requests.map((request) => request.path), <String>[
      first.path,
      second.path,
    ]);
  });

  test(
    'does not read automatic video cache entries when caching is disabled',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-cache-disabled-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final video = await _writeFile(directory, 'clip.mp4');
      final cache = _FakeThumbnailDiskCache(<String, String>{
        video.path: '${directory.path}/clip-cache.jpg',
      });
      final container = _createContainer(
        fileService: _FakeFileService(<String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[video],
        }),
        thumbnailDiskCache: cache,
        diskCacheEnabled: false,
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.isEmpty, isTrue);
      expect(cache.requests, isEmpty);
    },
  );

  test('keeps a custom video when caching is disabled', () async {
    final directory = await Directory.systemTemp.createTemp(
      'media-fast-view-preview-custom-video-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final video = await _writeFile(directory, 'chosen.mp4');
    final cache = _FakeThumbnailDiskCache(<String, String>{});
    final container = _createContainer(
      fileService: _FakeFileService(<String, List<FileSystemEntity>>{
        directory.path: <FileSystemEntity>[video],
      }),
      thumbnailDiskCache: cache,
      diskCacheEnabled: false,
      directoryCoverRepository: _FakeDirectoryCoverRepository(
        DirectoryCoverEntity.media(
          directoryPath: directory.path,
          sourceFileName: 'chosen.mp4',
          mediaType: MediaType.video,
          updatedAt: DateTime(2025),
        ),
      ),
    );
    addTearDown(container.dispose);

    final catalog = await container.read(
      directoryPreviewCatalogProvider(_query(directory.path)).future,
    );

    expect(catalog.primaryPreview, isA<DirectoryCustomPreview>());
    expect(
      (catalog.primaryPreview as DirectoryCustomPreview).media.type,
      MediaType.video,
    );
    expect(cache.requests, isEmpty);
  });

  test('refreshes a live catalog when the cache setting changes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'media-fast-view-preview-setting-change-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final video = await _writeFile(directory, 'clip.mp4');
    final cache = _FakeThumbnailDiskCache(<String, String>{
      video.path: '${directory.path}/clip-cache.jpg',
    });
    final cacheEnabledProvider = StateProvider<bool>((ref) => true);
    final container = ProviderContainer(
      overrides: <Override>[
        fileServiceProvider.overrideWithValue(
          _FakeFileService(<String, List<FileSystemEntity>>{
            directory.path: <FileSystemEntity>[video],
          }),
        ),
        thumbnailDiskCacheProvider.overrideWithValue(cache),
        thumbnailDiskCacheEnabledProvider.overrideWith(
          (ref) => ref.watch(cacheEnabledProvider),
        ),
        directoryCoverRepositoryProvider.overrideWithValue(
          _FakeDirectoryCoverRepository(),
        ),
        directoryPreviewInheritedBookmarkProvider.overrideWith(
          (ref, path) => null,
        ),
        activeProfileIdProvider.overrideWith(
          () => ActiveProfileIdNotifier('test-profile'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = directoryPreviewCatalogProvider(_query(directory.path));
    final subscription = container.listen<AsyncValue<DirectoryPreviewCatalog>>(
      provider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect((await container.read(provider.future)).isEmpty, isFalse);
    container.read(cacheEnabledProvider.notifier).state = false;
    await container.pump();

    expect((await container.read(provider.future)).isEmpty, isTrue);
  });

  test('probes no more than fifty automatic videos', () async {
    final directory = await Directory.systemTemp.createTemp(
      'media-fast-view-preview-video-limit-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final videos = <File>[];
    for (var index = 0; index < 51; index += 1) {
      videos.add(
        await _writeFile(
          directory,
          'video-${index.toString().padLeft(2, '0')}.mp4',
        ),
      );
    }
    final cache = _FakeThumbnailDiskCache(<String, String>{
      videos.last.path: '${directory.path}/last-cache.jpg',
    });
    final container = _createContainer(
      fileService: _FakeFileService(<String, List<FileSystemEntity>>{
        directory.path: videos,
      }),
      thumbnailDiskCache: cache,
    );
    addTearDown(container.dispose);

    final catalog = await container.read(
      directoryPreviewCatalogProvider(_query(directory.path)).future,
    );

    expect(catalog.isEmpty, isTrue);
    expect(cache.requests, hasLength(50));
    expect(cache.requests.last.path, videos[49].path);
  });

  test(
    'keeps an inherited bookmark active through custom metadata resolution',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'media-fast-view-preview-bookmark-',
      );
      addTearDown(() => root.delete(recursive: true));
      final directory = await Directory('${root.path}/child').create();
      final custom = await _writeFile(directory, 'chosen.mp4');
      final bookmarkAccess = _RecordingBookmarkAccess(root.path);
      final statPaths = <String>[];
      final fileService = _FakeFileService(
        <String, List<FileSystemEntity>>{
          directory.path: <FileSystemEntity>[custom],
        },
        onFileStat: (filePath) {
          statPaths.add(filePath);
          expect(filePath, custom.path);
          expect(bookmarkAccess.isAccessing, isTrue);
        },
      );
      final container = _createContainer(
        fileService: fileService,
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
        directoryCoverRepository: _FakeDirectoryCoverRepository(
          DirectoryCoverEntity.media(
            directoryPath: directory.path,
            sourceFileName: 'chosen.mp4',
            mediaType: MediaType.video,
            updatedAt: DateTime(2025),
          ),
        ),
        bookmarkAccess: bookmarkAccess,
        inheritedBookmark: 'inherited-bookmark',
      );
      addTearDown(container.dispose);

      final catalog = await container.read(
        directoryPreviewCatalogProvider(_query(directory.path)).future,
      );

      expect(catalog.primaryPreview?.bookmarkData, 'inherited-bookmark');
      expect(statPaths, <String>[custom.path]);
      expect(bookmarkAccess.startedBookmarks, <String>['inherited-bookmark']);
      expect(bookmarkAccess.stoppedBookmarks, <String>['inherited-bookmark']);
      expect(bookmarkAccess.isAccessing, isFalse);
    },
  );

  test(
    'refreshes a live catalog after a direct-child media mutation',
    () async {
      const directoryPath = '/tmp/catalog-mutation';
      final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
        directoryPath: <FileSystemEntity>[File('$directoryPath/one.jpg')],
      });
      final container = _createContainer(
        fileService: fileService,
        thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
      );
      addTearDown(container.dispose);
      final provider = directoryPreviewCatalogProvider(_query(directoryPath));
      final subscription = container
          .listen<AsyncValue<DirectoryPreviewCatalog>>(
            provider,
            (_, __) {},
            fireImmediately: true,
          );
      addTearDown(subscription.close);

      expect(
        (await container.read(provider.future)).primaryPreview?.sourcePath,
        '$directoryPath/one.jpg',
      );
      fileService.contentsByPath[directoryPath] = <FileSystemEntity>[
        File('$directoryPath/two.jpg'),
      ];
      container.read(mediaMutationBusProvider.notifier).publishDeleted(
        <MediaEntity>[_media('$directoryPath/one.jpg')],
      );
      await container.pump();

      expect(
        (await container.read(provider.future)).primaryPreview?.sourcePath,
        '$directoryPath/two.jpg',
      );
      expect(fileService.readCountForPath(directoryPath), 2);
    },
  );

  test('refreshes a live catalog after changing its cover', () async {
    const directoryPath = '/tmp/catalog-cover-change';
    final repository = _FakeDirectoryCoverRepository();
    final fileService = _FakeFileService(<String, List<FileSystemEntity>>{
      directoryPath: <FileSystemEntity>[File('$directoryPath/one.jpg')],
    });
    final container = _createContainer(
      fileService: fileService,
      thumbnailDiskCache: _FakeThumbnailDiskCache(<String, String>{}),
      directoryCoverRepository: repository,
    );
    addTearDown(container.dispose);
    final provider = directoryPreviewCatalogProvider(_query(directoryPath));
    final subscription = container.listen<AsyncValue<DirectoryPreviewCatalog>>(
      provider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect((await container.read(provider.future)).isEmpty, isFalse);
    await container
        .read(directoryCoverControllerProvider(directoryPath).notifier)
        .setNoCover();
    await container.pump();

    expect((await container.read(provider.future)).isEmpty, isTrue);
    expect(fileService.readCountForPath(directoryPath), 1);
  });
}

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
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

class _NoCoverRepository implements DirectoryCoverRepository {
  @override
  Future<void> clearCovers() async {}

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async => null;

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
  Future<void> removeCover(String directoryPath) async {}

  @override
  Future<void> removeCoverForSource(String sourcePath) async {}

  @override
  Future<void> removeCoversUnder(String directoryPath) async {}

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {}
}

void main() {
  group('Preview providers auto-dispose behavior', () {
    test(
      'directoryPreviewStripProvider reuses value during TTL then refetches',
      () async {
        const directoryPath = '/tmp/preview-strip-directory';
        final fakeFileService = _FakeFileService(
          <String, List<FileSystemEntity>>{
            directoryPath: <FileSystemEntity>[
              File('$directoryPath/one.jpg'),
              File('$directoryPath/two.jpg'),
              File('$directoryPath/three.png'),
            ],
          },
        );

        final container = ProviderContainer(
          overrides: <Override>[
            fileServiceProvider.overrideWithValue(fakeFileService),
            directoryCoverRepositoryProvider.overrideWithValue(
              _NoCoverRepository(),
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

        final firstSubscription = container
            .listen<AsyncValue<DirectoryPreviewResolutionList>>(
              directoryPreviewStripProvider(directoryPath),
              (_, __) {},
              fireImmediately: true,
            );
        expect(
          await container.read(
            directoryPreviewStripProvider(directoryPath).future,
          ),
          predicate<DirectoryPreviewResolutionList>(
            (value) =>
                value.previews
                    .map((preview) => preview.sourcePath)
                    .toList()[0] ==
                '$directoryPath/one.jpg',
          ),
        );
        expect(fakeFileService.readCountForPath(directoryPath), equals(1));
        firstSubscription.close();

        await Future<void>.delayed(const Duration(milliseconds: 100));
        await container.pump();

        final secondSubscription = container
            .listen<AsyncValue<DirectoryPreviewResolutionList>>(
              directoryPreviewStripProvider(directoryPath),
              (_, __) {},
              fireImmediately: true,
            );
        expect(
          await container.read(
            directoryPreviewStripProvider(directoryPath).future,
          ),
          isA<DirectoryPreviewResolutionList>(),
        );
        expect(fakeFileService.readCountForPath(directoryPath), equals(1));
        secondSubscription.close();

        await Future<void>.delayed(const Duration(milliseconds: 650));
        await container.pump();

        final thirdSubscription = container
            .listen<AsyncValue<DirectoryPreviewResolutionList>>(
              directoryPreviewStripProvider(directoryPath),
              (_, __) {},
              fireImmediately: true,
            );
        expect(
          await container.read(
            directoryPreviewStripProvider(directoryPath).future,
          ),
          isA<DirectoryPreviewResolutionList>(),
        );
        expect(fakeFileService.readCountForPath(directoryPath), equals(2));
        thirdSubscription.close();
      },
    );
  });
}

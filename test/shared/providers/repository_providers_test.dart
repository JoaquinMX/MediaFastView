import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

class _FakeFileService extends FileService {
  _FakeFileService(this._contentsByPath);

  final Map<String, List<FileSystemEntity>> _contentsByPath;
  final Map<String, int> _readCounts = <String, int>{};

  int readCountForPath(String path) {
    return _readCounts[path] ?? 0;
  }

  @override
  Future<List<FileSystemEntity>> getDirectoryContents(String directoryPath) async {
    _readCounts[directoryPath] = (_readCounts[directoryPath] ?? 0) + 1;
    return _contentsByPath[directoryPath] ?? <FileSystemEntity>[];
  }
}

void main() {
  group('Preview providers auto-dispose behavior', () {
    test('directoryPreviewProvider reuses value during TTL then refetches', () async {
      const directoryPath = '/tmp/preview-directory';
      final fakeFileService = _FakeFileService(<String, List<FileSystemEntity>>{
        directoryPath: <FileSystemEntity>[
          File('$directoryPath/cover.jpg'),
          File('$directoryPath/video.mp4'),
        ],
      });

      final container = ProviderContainer(
        overrides: <Override>[
          fileServiceProvider.overrideWithValue(fakeFileService),
        ],
      );
      addTearDown(container.dispose);

      final firstSubscription = container.listen<AsyncValue<String?>>(
        directoryPreviewProvider(directoryPath),
        (_, __) {},
        fireImmediately: true,
      );
      expect(
        await container.read(directoryPreviewProvider(directoryPath).future),
        equals('$directoryPath/cover.jpg'),
      );
      expect(fakeFileService.readCountForPath(directoryPath), equals(1));
      firstSubscription.close();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await container.pump();

      final secondSubscription = container.listen<AsyncValue<String?>>(
        directoryPreviewProvider(directoryPath),
        (_, __) {},
        fireImmediately: true,
      );
      expect(
        await container.read(directoryPreviewProvider(directoryPath).future),
        equals('$directoryPath/cover.jpg'),
      );
      expect(fakeFileService.readCountForPath(directoryPath), equals(1));
      secondSubscription.close();

      await Future<void>.delayed(const Duration(milliseconds: 650));
      await container.pump();

      final thirdSubscription = container.listen<AsyncValue<String?>>(
        directoryPreviewProvider(directoryPath),
        (_, __) {},
        fireImmediately: true,
      );
      expect(
        await container.read(directoryPreviewProvider(directoryPath).future),
        equals('$directoryPath/cover.jpg'),
      );
      expect(fakeFileService.readCountForPath(directoryPath), equals(2));
      thirdSubscription.close();
    });

    test('directoryPreviewStripProvider reuses value during TTL then refetches', () async {
      const directoryPath = '/tmp/preview-strip-directory';
      final fakeFileService = _FakeFileService(<String, List<FileSystemEntity>>{
        directoryPath: <FileSystemEntity>[
          File('$directoryPath/one.jpg'),
          File('$directoryPath/two.jpg'),
          File('$directoryPath/three.png'),
        ],
      });

      final container = ProviderContainer(
        overrides: <Override>[
          fileServiceProvider.overrideWithValue(fakeFileService),
        ],
      );
      addTearDown(container.dispose);

      final firstSubscription = container.listen<AsyncValue<List<String>>>(
        directoryPreviewStripProvider(directoryPath),
        (_, __) {},
        fireImmediately: true,
      );
      expect(
        await container.read(directoryPreviewStripProvider(directoryPath).future),
        equals(<String>[
          '$directoryPath/one.jpg',
          '$directoryPath/two.jpg',
          '$directoryPath/three.png',
        ]),
      );
      expect(fakeFileService.readCountForPath(directoryPath), equals(1));
      firstSubscription.close();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      await container.pump();

      final secondSubscription = container.listen<AsyncValue<List<String>>>(
        directoryPreviewStripProvider(directoryPath),
        (_, __) {},
        fireImmediately: true,
      );
      expect(
        await container.read(directoryPreviewStripProvider(directoryPath).future),
        equals(<String>[
          '$directoryPath/one.jpg',
          '$directoryPath/two.jpg',
          '$directoryPath/three.png',
        ]),
      );
      expect(fakeFileService.readCountForPath(directoryPath), equals(1));
      secondSubscription.close();

      await Future<void>.delayed(const Duration(milliseconds: 650));
      await container.pump();

      final thirdSubscription = container.listen<AsyncValue<List<String>>>(
        directoryPreviewStripProvider(directoryPath),
        (_, __) {},
        fireImmediately: true,
      );
      expect(
        await container.read(directoryPreviewStripProvider(directoryPath).future),
        equals(<String>[
          '$directoryPath/one.jpg',
          '$directoryPath/two.jpg',
          '$directoryPath/three.png',
        ]),
      );
      expect(fakeFileService.readCountForPath(directoryPath), equals(2));
      thirdSubscription.close();
    });
  });
}

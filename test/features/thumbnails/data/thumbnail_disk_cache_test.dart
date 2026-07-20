import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';

ThumbnailRequest _request({
  String path = '/library/a.jpg',
  int size = 10,
  DateTime? modified,
  ThumbnailSize thumbnailSize = ThumbnailSize.medium,
}) {
  return ThumbnailRequest(
    path: path,
    mediaType: MediaType.image,
    sourceSize: size,
    sourceLastModified: modified ?? DateTime.utc(2025),
    thumbnailSize: thumbnailSize,
    diskCacheEnabled: true,
  );
}

void main() {
  late Directory temporaryDirectory;
  late ThumbnailDiskCache cache;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-thumbnail-cache-',
    );
    cache = ThumbnailDiskCache(
      directoryResolver: () async => temporaryDirectory,
      maximumBytes: 100,
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('cache key changes with every source invalidation field', () {
    final original = _request();

    expect(cache.keyFor(_request()), cache.keyFor(original));
    expect(
      cache.keyFor(_request(path: '/library/b.jpg')),
      isNot(cache.keyFor(original)),
    );
    expect(cache.keyFor(_request(size: 11)), isNot(cache.keyFor(original)));
    expect(
      cache.keyFor(_request(modified: DateTime.utc(2025, 2))),
      isNot(cache.keyFor(original)),
    );
    expect(
      cache.keyFor(_request(thumbnailSize: ThumbnailSize.large)),
      isNot(cache.keyFor(original)),
    );
  });

  test('writes, reads, reports, invalidates, and clears entries', () async {
    final request = _request();

    expect(await cache.read(request), isNull);
    final written = await cache.write(request, List<int>.filled(40, 1));

    expect(await written.exists(), isTrue);
    expect((await cache.read(request))?.path, written.path);
    expect(await cache.sizeInBytes(), 40);

    await cache.invalidate(request);
    expect(await cache.read(request), isNull);

    await cache.write(request, List<int>.filled(40, 1));
    await cache.clear();
    expect(await cache.sizeInBytes(), 0);
  });

  test(
    'trim removes oldest entries until the cache is below its target',
    () async {
      final firstRequest = _request(path: '/library/first.jpg');
      final secondRequest = _request(path: '/library/second.jpg');
      final first = await cache.write(firstRequest, List<int>.filled(80, 1));
      final second = await cache.write(secondRequest, List<int>.filled(80, 2));
      await first.setLastModified(DateTime.utc(2024));
      await second.setLastModified(DateTime.utc(2025));

      await cache.trim();

      expect(await cache.read(firstRequest), isNull);
      expect(await cache.read(secondRequest), isNotNull);
      expect(await cache.sizeInBytes(), lessThanOrEqualTo(100));
    },
  );
}

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/thumbnails/data/native_thumbnail_generator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';

class _PendingGeneration {
  _PendingGeneration(this.requestId, this.request);

  final String requestId;
  final ThumbnailRequest request;
  final Completer<NativeThumbnail> completer = Completer<NativeThumbnail>();
}

class _ControlledGenerator implements ThumbnailGenerator {
  final List<_PendingGeneration> generations = <_PendingGeneration>[];
  final List<String> cancelledRequestIds = <String>[];
  int activeCount = 0;
  int maximumActiveCount = 0;
  bool completeOnCancel = true;

  @override
  Future<NativeThumbnail> generate(
    ThumbnailRequest request, {
    required String requestId,
  }) {
    final pending = _PendingGeneration(requestId, request);
    generations.add(pending);
    activeCount += 1;
    maximumActiveCount = activeCount > maximumActiveCount
        ? activeCount
        : maximumActiveCount;
    return pending.completer.future.whenComplete(() => activeCount -= 1);
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelledRequestIds.add(requestId);
    final pending = generations
        .where((item) => item.requestId == requestId)
        .first;
    if (completeOnCancel && !pending.completer.isCompleted) {
      pending.completer.completeError(const ThumbnailCancelledException());
    }
  }

  void complete(int index) {
    generations[index].completer.complete(
      NativeThumbnail(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        fileExtension: 'jpg',
      ),
    );
  }
}

ThumbnailRequest _request(String path) {
  return ThumbnailRequest(
    path: path,
    mediaType: MediaType.image,
    sourceSize: 10,
    sourceLastModified: DateTime.utc(2025),
    thumbnailSize: ThumbnailSize.medium,
    diskCacheEnabled: false,
  );
}

void main() {
  late Directory temporaryDirectory;
  late _ControlledGenerator generator;
  late ThumbnailCoordinator coordinator;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-thumbnail-coordinator-',
    );
    generator = _ControlledGenerator();
    coordinator = ThumbnailCoordinator(
      generator: generator,
      cache: ThumbnailDiskCache(
        directoryResolver: () async => temporaryDirectory,
      ),
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('coalesces equivalent in-flight requests', () async {
    final request = _request('/library/a.jpg');
    final first = coordinator.load(request);
    final second = coordinator.load(request);
    await Future<void>.delayed(Duration.zero);

    expect(generator.generations, hasLength(1));
    generator.complete(0);

    expect((await first).isCacheHit, isFalse);
    expect((await second).isCacheHit, isFalse);
  });

  test('reserves capacity for visible work while a batch is running', () async {
    final firstBackground = coordinator.load(
      _request('/library/background-1.jpg'),
      priority: ThumbnailPriority.background,
    );
    final secondBackground = coordinator.load(
      _request('/library/background-2.jpg'),
      priority: ThumbnailPriority.background,
    );
    final visible = coordinator.load(_request('/library/visible.jpg'));
    await Future<void>.delayed(Duration.zero);

    expect(generator.generations.map((item) => item.request.path), <String>[
      '/library/background-1.jpg',
      '/library/visible.jpg',
    ]);
    expect(generator.maximumActiveCount, 2);

    generator.complete(1);
    await visible;
    expect(generator.generations, hasLength(2));

    generator.complete(0);
    await firstBackground;
    await Future<void>.delayed(Duration.zero);
    expect(generator.generations[2].request.path, '/library/background-2.jpg');
    generator.complete(2);
    await secondBackground;
  });

  test('cancels native work when its final subscriber leaves', () async {
    final cancellationToken = ThumbnailCancellationToken();
    final future = coordinator.load(
      _request('/library/cancel.jpg'),
      cancellationToken: cancellationToken,
    );
    final expectation = expectLater(
      future,
      throwsA(isA<ThumbnailCancelledException>()),
    );
    await Future<void>.delayed(Duration.zero);

    cancellationToken.cancel();

    await expectation;
    expect(generator.cancelledRequestIds, <String>[
      generator.generations.single.requestId,
    ]);
  });

  test(
    'does not attach new work to a native request being cancelled',
    () async {
      generator.completeOnCancel = false;
      final request = _request('/library/fast-scroll.jpg');
      final cancellationToken = ThumbnailCancellationToken();
      final first = coordinator.load(
        request,
        cancellationToken: cancellationToken,
      );
      final firstExpectation = expectLater(
        first,
        throwsA(isA<ThumbnailCancelledException>()),
      );
      await Future<void>.delayed(Duration.zero);

      cancellationToken.cancel();
      await firstExpectation;
      final second = coordinator.load(request);
      await Future<void>.delayed(Duration.zero);

      expect(generator.generations, hasLength(2));
      expect(
        generator.generations[1].requestId,
        isNot(generator.generations[0].requestId),
      );

      generator.complete(1);
      await second;
      generator.generations[0].completer.completeError(
        const ThumbnailCancelledException(),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );
}

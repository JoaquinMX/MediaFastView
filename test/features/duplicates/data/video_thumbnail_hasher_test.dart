import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/services/perceptual_hasher.dart';
import 'package:media_fast_view/features/duplicates/data/services/video_thumbnail_hasher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/thumbnails/data/native_thumbnail_generator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_coordinator.dart';
import 'package:media_fast_view/features/thumbnails/data/thumbnail_disk_cache.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';

class _ControllableThumbnailGenerator implements ThumbnailGenerator {
  bool waitForCancellation = false;
  ThumbnailRequest? request;
  String? requestId;
  Completer<NativeThumbnail>? pending;
  final List<String> cancelledRequestIds = <String>[];

  @override
  Future<NativeThumbnail> generate(
    ThumbnailRequest request, {
    required String requestId,
  }) {
    this.request = request;
    this.requestId = requestId;
    if (!waitForCancellation) {
      return Future<NativeThumbnail>.value(
        NativeThumbnail(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileExtension: 'jpg',
        ),
      );
    }
    pending = Completer<NativeThumbnail>();
    return pending!.future;
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelledRequestIds.add(requestId);
    if (!(pending?.isCompleted ?? true)) {
      pending!.completeError(const ThumbnailCancelledException());
    }
  }
}

class _FakePerceptualHasher extends PerceptualHasher {
  String? hashedPath;

  @override
  Future<ImageHashResult?> hashFile(String path) async {
    hashedPath = path;
    return const ImageHashResult(hash: 9, width: 512, height: 288);
  }
}

void main() {
  late Directory temporaryDirectory;
  late _ControllableThumbnailGenerator generator;
  late ThumbnailCoordinator coordinator;
  late _FakePerceptualHasher perceptualHasher;
  late CachedVideoThumbnailHasher hasher;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'media-fast-view-video-hasher-',
    );
    generator = _ControllableThumbnailGenerator();
    coordinator = ThumbnailCoordinator(
      generator: generator,
      cache: ThumbnailDiskCache(
        directoryResolver: () async => temporaryDirectory,
      ),
    );
    perceptualHasher = _FakePerceptualHasher();
    hasher = CachedVideoThumbnailHasher(
      coordinator: coordinator,
      perceptualHasher: perceptualHasher,
    );
  });

  tearDown(() async {
    await coordinator.dispose();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('hashes the shared medium video miniature from disk cache', () async {
    final result = await hasher.hashVideo(
      path: '/query.mov',
      size: 5000,
      lastModified: DateTime.utc(2025),
      bookmarkData: 'bookmark',
    );

    expect(result?.hash, 9);
    expect(generator.request?.mediaType, MediaType.video);
    expect(generator.request?.thumbnailSize, ThumbnailSize.medium);
    expect(generator.request?.diskCacheEnabled, isTrue);
    expect(generator.request?.bookmarkData, 'bookmark');
    expect(perceptualHasher.hashedPath, isNotNull);
  });

  test('propagates lookup cancellation into native generation', () async {
    generator.waitForCancellation = true;
    final cancellation = DuplicateScanCancellation();
    final result = hasher.hashVideo(
      path: '/query.mov',
      size: 5000,
      lastModified: DateTime.utc(2025),
      cancellation: cancellation,
    );
    for (
      var attempt = 0;
      attempt < 20 && generator.requestId == null;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(generator.requestId, isNotNull);

    cancellation.cancel();

    expect(await result, isNull);
    expect(generator.cancelledRequestIds, <String>[generator.requestId!]);
  });
}

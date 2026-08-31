import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_video_frame_generator.dart';
import 'package:media_fast_view/features/duplicates/data/services/perceptual_hasher.dart';
import 'package:media_fast_view/features/duplicates/data/services/video_frame_hasher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_hash.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';

class _FakeVideoFrameGenerator implements VideoFrameGenerator {
  bool waitForCancellation = false;
  String? requestId;
  String? path;
  List<int>? positionPercents;
  int? maximumPixelSize;
  String? bookmarkData;
  Completer<List<NativeVideoFrame>>? pending;
  final List<String> cancelledRequestIds = <String>[];

  @override
  Future<List<NativeVideoFrame>> generate({
    required String requestId,
    required String path,
    required List<int> positionPercents,
    required int maximumPixelSize,
    String? bookmarkData,
  }) {
    this.requestId = requestId;
    this.path = path;
    this.positionPercents = positionPercents;
    this.maximumPixelSize = maximumPixelSize;
    this.bookmarkData = bookmarkData;
    if (waitForCancellation) {
      pending = Completer<List<NativeVideoFrame>>();
      return pending!.future;
    }
    return Future<List<NativeVideoFrame>>.value(<NativeVideoFrame>[
      for (final positionPercent in positionPercents.reversed)
        NativeVideoFrame(
          positionPercent: positionPercent,
          timestamp: Duration(seconds: positionPercent * 2),
          bytes: Uint8List.fromList(<int>[positionPercent]),
        ),
    ]);
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
  @override
  Future<ImageHashResult?> hashBytes(Uint8List bytes) async {
    return ImageHashResult(hash: bytes.single, width: 512, height: 288);
  }
}

void main() {
  test('extracts, hashes, validates, and sorts all five samples', () async {
    final generator = _FakeVideoFrameGenerator();
    final hasher = NativeVideoFrameHasher(
      generator: generator,
      perceptualHasher: _FakePerceptualHasher(),
    );
    final modified = DateTime.utc(2025);

    final hashes = await hasher.hashVideo(
      mediaId: 'video',
      path: '/video.mov',
      size: 5000,
      lastModified: modified,
      bookmarkData: 'bookmark',
    );

    expect(generator.path, '/video.mov');
    expect(generator.positionPercents, videoFrameSamplePercents);
    expect(generator.maximumPixelSize, 512);
    expect(generator.bookmarkData, 'bookmark');
    expect(hashes, hasLength(5));
    expect(
      hashes!.map((hash) => hash.positionPercent),
      videoFrameSamplePercents,
    );
    expect(hashes.map((hash) => hash.hash), videoFrameSamplePercents);
    expect(hashes.first.timestamp, const Duration(seconds: 20));
    expect(hashes.first.fingerprint, startsWith('video_frame_lookup_v1_'));
  });

  test('propagates cancellation to native frame generation', () async {
    final generator = _FakeVideoFrameGenerator()..waitForCancellation = true;
    final hasher = NativeVideoFrameHasher(
      generator: generator,
      perceptualHasher: _FakePerceptualHasher(),
    );
    final cancellation = DuplicateScanCancellation();
    final result = hasher.hashVideo(
      mediaId: 'video',
      path: '/video.mov',
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

    cancellation.cancel();

    expect(await result, isNull);
    expect(generator.cancelledRequestIds, <String>[generator.requestId!]);
  });
}

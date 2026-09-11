import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_maximum_video_frame_indexer.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_presentation_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes exact native presentation timestamps', () async {
    const channel = MethodChannel('com.joaquinmx.media_fast_view/thumbnails');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'readMaximumVideoFrameIndexChunk') {
            return <String, dynamic>{
              'frames': <Map<String, dynamic>>[
                <String, dynamic>{
                  'frameIndex': 4,
                  'timestampMilliseconds': 33,
                  'presentationTimeValue': 1001,
                  'presentationTimeScale': 30000,
                  'fullFrameHash': 1,
                  'centerCropHash': 2,
                  'width': 1920,
                  'height': 1080,
                },
              ],
              'isComplete': true,
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final indexer = NativeMaximumVideoFrameIndexer(channel: channel);
    final chunks = await indexer
        .index(requestId: 'maximum-request', path: '/library/video.mp4')
        .toList();

    expect(
      chunks.single.frames.single.presentationTime,
      const VideoFramePresentationTime(value: 1001, timescale: 30000),
    );
    expect(
      chunks.single.frames.single.timestamp,
      const Duration(milliseconds: 33),
    );
    expect(calls.map((call) => call.method), <String>[
      'startMaximumVideoFrameIndex',
      'readMaximumVideoFrameIndexChunk',
    ]);
  });

  test('does not start native indexing after cancellation', () async {
    const channel = MethodChannel('com.joaquinmx.media_fast_view/thumbnails');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final cancellation = DuplicateScanCancellation()..cancel();
    final indexer = NativeMaximumVideoFrameIndexer(channel: channel);
    await expectLater(
      indexer
          .index(
            requestId: 'maximum-cancelled',
            path: '/library/video.mp4',
            cancellation: cancellation,
          )
          .drain<void>(),
      throwsA(isA<MaximumVideoFrameIndexCancelledException>()),
    );
    expect(calls, isEmpty);
  });
}

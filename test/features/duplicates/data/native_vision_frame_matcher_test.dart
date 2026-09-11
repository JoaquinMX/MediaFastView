import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_vision_frame_matcher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_presentation_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sends exact neighbor timestamps and exposes native cancellation',
    () async {
      const channel = MethodChannel('com.joaquinmx.media_fast_view/thumbnails');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'matchVideoFrameVision') {
              return <String, dynamic>{
                'matches': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'mediaId': 'video',
                    'visionDistance': 0.12,
                    'timestampMilliseconds': 1000,
                    'presentationTimeValue': 30030,
                    'presentationTimeScale': 30000,
                    'positionPercent': 25,
                  },
                ],
              };
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final matcher = NativeVisionFrameMatcher(channel: channel);
      final matches = await matcher.matchCancellable(
        requestId: 'vision-request',
        queryPath: '/query.jpg',
        candidates: <VisionFrameCandidateRequest>[
          VisionFrameCandidateRequest(
            mediaId: 'video',
            path: '/library/video.mp4',
            timestamp: Duration(seconds: 1),
            verificationTimestamps: <Duration>[
              Duration.zero,
              Duration(seconds: 1),
              Duration(seconds: 2),
            ],
            presentationTime: const VideoFramePresentationTime(
              value: 30030,
              timescale: 30000,
            ),
            verificationPresentationTimes: const <VideoFramePresentationTime>[
              VideoFramePresentationTime(value: 0, timescale: 30000),
              VideoFramePresentationTime(value: 30030, timescale: 30000),
              VideoFramePresentationTime(value: 60060, timescale: 30000),
            ],
            bookmarkData: 'directory-bookmark',
          ),
        ],
      );

      expect(matches.single.distance, 0.12);
      expect(
        matches.single.presentationTime,
        const VideoFramePresentationTime(value: 30030, timescale: 30000),
      );
      final matchArguments =
          calls
                  .singleWhere((call) => call.method == 'matchVideoFrameVision')
                  .arguments
              as Map<Object?, Object?>;
      expect(matchArguments['requestId'], 'vision-request');
      final candidate =
          (matchArguments['candidates'] as List).single
              as Map<Object?, Object?>;
      expect(candidate['verificationTimestampMilliseconds'], <int>[
        0,
        1000,
        2000,
      ]);
      expect(candidate['presentationTimeValue'], 30030);
      expect(candidate['presentationTimeScale'], 30000);
      expect(candidate['verificationPresentationTimes'], <Map<String, int>>[
        <String, int>{'value': 0, 'timescale': 30000},
        <String, int>{'value': 30030, 'timescale': 30000},
        <String, int>{'value': 60060, 'timescale': 30000},
      ]);
      expect(candidate['bookmarkData'], 'directory-bookmark');

      await matcher.cancel('vision-request');
      expect(calls.any((call) => call.method == 'cancelThumbnail'), isTrue);
    },
  );

  test('serializes and parses a shared multi-query Vision session', () async {
    const channel = MethodChannel('com.joaquinmx.media_fast_view/thumbnails');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'startVisionSession':
              return <String, dynamic>{'started': true};
            case 'verifyVisionSessionBatch':
              return <String, dynamic>{
                'verifiedVideoCount': 1,
                'failures': <Map<String, dynamic>>[],
                'matches': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'queryId': 'query-a',
                    'mediaId': 'video-a',
                    'visionDistance': 4.5,
                    'timestampMilliseconds': 1200,
                    'presentationTimeValue': 36,
                    'presentationTimeScale': 30,
                  },
                ],
              };
            default:
              return null;
          }
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final matcher = NativeVisionFrameMatcher(channel: channel);
    await matcher.startSession(
      sessionId: 'session-a',
      queries: const <VisionSessionQuery>[
        VisionSessionQuery(
          queryId: 'query-a',
          path: '/query-a.jpg',
          sourceFingerprint: 'query-fingerprint',
        ),
      ],
    );
    final batch = await matcher.verifyBatch(
      sessionId: 'session-a',
      requestId: 'batch-a',
      candidates: <VisionFrameCandidateRequest>[
        VisionFrameCandidateRequest(
          queryId: 'query-a',
          sourceFingerprint: 'video-fingerprint',
          mediaId: 'video-a',
          path: '/video-a.mp4',
          timestamp: const Duration(milliseconds: 1200),
        ),
      ],
    );
    await matcher.endSession('session-a');

    expect(batch.verifiedVideoCount, 1);
    expect(batch.matches.single.queryId, 'query-a');
    final startArguments =
        calls
                .singleWhere((call) => call.method == 'startVisionSession')
                .arguments
            as Map<Object?, Object?>;
    expect(startArguments['sessionId'], 'session-a');
    final query =
        (startArguments['queries'] as List).single as Map<Object?, Object?>;
    expect(query['queryId'], 'query-a');
    final verifyArguments =
        calls
                .singleWhere(
                  (call) => call.method == 'verifyVisionSessionBatch',
                )
                .arguments
            as Map<Object?, Object?>;
    final candidate =
        (verifyArguments['candidates'] as List).single as Map<Object?, Object?>;
    expect(candidate['queryId'], 'query-a');
    expect(candidate['sourceFingerprint'], 'video-fingerprint');
  });

  test('routes progress only to the active session request', () async {
    const channel = MethodChannel('com.joaquinmx.media_fast_view/thumbnails');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final verifyStarted = Completer<void>();
    final verifyResponse = Completer<Map<String, dynamic>>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'startVisionSession':
          return <String, dynamic>{'started': true};
        case 'verifyVisionSessionBatch':
          if (!verifyStarted.isCompleted) {
            verifyStarted.complete();
          }
          return verifyResponse.future;
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final matcher = NativeVisionFrameMatcher(channel: channel);
    await matcher.startSession(
      sessionId: 'session-progress',
      queries: const <VisionSessionQuery>[
        VisionSessionQuery(queryId: 'query-a', path: '/query-a.jpg'),
      ],
    );
    final updates = <VisionSessionBatchUpdate>[];
    final batchFuture = matcher.verifyBatch(
      sessionId: 'session-progress',
      requestId: 'batch-current',
      candidates: <VisionFrameCandidateRequest>[
        VisionFrameCandidateRequest(
          queryId: 'query-a',
          mediaId: 'video-a',
          path: '/video-a.mp4',
          timestamp: Duration.zero,
        ),
      ],
      onUpdate: updates.add,
    );
    await verifyStarted.future;

    Future<void> deliverUpdate({
      required String sessionId,
      required String requestId,
    }) async {
      final message = const StandardMethodCodec().encodeMethodCall(
        MethodCall('visionSessionUpdate', <String, dynamic>{
          'sessionId': sessionId,
          'requestId': requestId,
          'mediaId': 'video-a',
          'verifiedVideoCount': 1,
          'completedVideoCount': 1,
          'matches': <Map<String, dynamic>>[
            <String, dynamic>{
              'queryId': 'query-a',
              'mediaId': 'video-a',
              'visionDistance': 2.0,
              'timestampMilliseconds': 0,
            },
          ],
        }),
      );
      await messenger.handlePlatformMessage(channel.name, message, (_) {});
    }

    await deliverUpdate(
      sessionId: 'session-progress',
      requestId: 'batch-current',
    );
    await deliverUpdate(
      sessionId: 'session-progress',
      requestId: 'batch-previous',
    );
    await deliverUpdate(
      sessionId: 'session-previous',
      requestId: 'batch-current',
    );
    expect(updates, hasLength(1));
    expect(updates.single.requestId, 'batch-current');

    verifyResponse.complete(<String, dynamic>{
      'matches': <Map<String, dynamic>>[],
      'failures': <Map<String, dynamic>>[],
      'verifiedVideoCount': 1,
      'completedVideoCount': 1,
    });
    await batchFuture;

    // The registration is removed when the batch completes, so a delayed
    // native event cannot update a newer or already-finished request.
    await deliverUpdate(
      sessionId: 'session-progress',
      requestId: 'batch-current',
    );
    expect(updates, hasLength(1));
    await matcher.endSession('session-progress');
  });
}

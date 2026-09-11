import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/models/media_lookup_mode.dart';
import 'package:media_fast_view/core/models/video_frame_lookup_precision.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/video_maximum_frame_index_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/isar/maximum_video_frame_descriptor_codec.dart';
import 'package:media_fast_view/features/duplicates/data/repositories/duplicate_repository_impl.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_compact_descriptor_generator.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_maximum_video_frame_indexer.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_vision_frame_matcher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_update.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/maximum_video_frame_descriptor.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/perceptual_hash.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_maximum_frame_index_chunk.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_maximum_frame_index_status.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_presentation_time.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';

class _FakeMediaRepository implements MediaRepository {
  _FakeMediaRepository(this.media);

  final List<MediaEntity> media;

  @override
  Future<List<MediaEntity>> getAllMedia() async => media;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeDirectoryRepository implements DirectoryRepository {
  _FakeDirectoryRepository(this.directories);

  final List<DirectoryEntity> directories;

  @override
  Future<List<DirectoryEntity>> getDirectories() async => directories;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHashDataSource implements PerceptualHashDataSource {
  @override
  Future<Map<String, PerceptualHash>> getByMediaIds(
    Iterable<String> mediaIds,
  ) async => <String, PerceptualHash>{};

  @override
  Future<void> putAll(List<PerceptualHash> hashes) async {}
}

class _FakeDismissedDataSource implements DismissedGroupDataSource {
  @override
  Future<Set<String>> getSignatures() async => <String>{};

  @override
  Future<void> add(String signature) async {}
}

class _FakeMaximumIndexDataSource implements VideoMaximumFrameIndexDataSource {
  _FakeMaximumIndexDataSource(this.statuses, this.chunksByMediaId);

  final Map<String, VideoMaximumFrameIndexStatus> statuses;
  final Map<String, List<VideoMaximumFrameIndexChunk>> chunksByMediaId;
  var streamCalls = 0;

  @override
  Future<Map<String, VideoMaximumFrameIndexStatus>> getStatuses(
    Iterable<String> mediaIds,
  ) async => <String, VideoMaximumFrameIndexStatus>{
    for (final mediaId in mediaIds)
      if (statuses[mediaId] case final status?) mediaId: status,
  };

  @override
  Stream<VideoMaximumFrameIndexChunk> streamChunks(String mediaId) async* {
    streamCalls++;
    for (final chunk
        in chunksByMediaId[mediaId] ?? const <VideoMaximumFrameIndexChunk>[]) {
      yield chunk;
    }
  }

  @override
  Future<void> begin(VideoMaximumFrameIndexStatus status) async {
    statuses[status.mediaId] = status;
  }

  @override
  Future<void> putChunk(VideoMaximumFrameIndexChunk chunk) async {
    chunksByMediaId
        .putIfAbsent(chunk.mediaId, () => <VideoMaximumFrameIndexChunk>[])
        .add(chunk);
  }

  @override
  Future<void> complete(VideoMaximumFrameIndexStatus status) async {
    statuses[status.mediaId] = status;
  }

  @override
  Future<void> delete(String mediaId) async {
    statuses.remove(mediaId);
    chunksByMediaId.remove(mediaId);
  }

  @override
  Future<void> clear() async {
    statuses.clear();
    chunksByMediaId.clear();
  }

  @override
  Future<int> getCacheSize() async => 0;
}

class _FakeCompactDescriptorGenerator
    implements CompactImageDescriptorGenerator {
  @override
  Future<NativeCompactImageDescriptor?> generate({
    required String path,
    String? bookmarkData,
  }) async => const NativeCompactImageDescriptor(
    fullFrameHash: 0,
    centerCropHash: 0,
    width: 800,
    height: 600,
  );
}

class _FixedCompactDescriptorGenerator
    implements CompactImageDescriptorGenerator {
  const _FixedCompactDescriptorGenerator({
    required this.fullFrameHash,
    required this.centerCropHash,
  });

  final int fullFrameHash;
  final int centerCropHash;

  @override
  Future<NativeCompactImageDescriptor?> generate({
    required String path,
    String? bookmarkData,
  }) async => NativeCompactImageDescriptor(
    fullFrameHash: fullFrameHash,
    centerCropHash: centerCropHash,
    width: 800,
    height: 600,
  );
}

class _FakeMaximumIndexer implements MaximumVideoFrameIndexer {
  _FakeMaximumIndexer(this.chunks, {this.waitForCancellation = false});

  final List<NativeMaximumVideoFrameChunk> chunks;
  final bool waitForCancellation;
  final Completer<void> cancellationGate = Completer<void>();
  var cancelCalls = 0;

  @override
  Stream<NativeMaximumVideoFrameChunk> index({
    required String requestId,
    required String path,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  }) async* {
    final removeCancellationListener = cancellation?.addListener(
      () => unawaited(cancel(requestId)),
    );
    try {
      for (var index = 0; index < chunks.length; index++) {
        yield chunks[index];
        if (waitForCancellation && index == 0) {
          await cancellationGate.future;
        }
      }
    } finally {
      removeCancellationListener?.call();
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    if (cancelCalls > 0) {
      return;
    }
    cancelCalls++;
    if (!cancellationGate.isCompleted) {
      cancellationGate.complete();
    }
  }
}

class _RecordingVisionMatcher implements CancellableVisionFrameMatcher {
  _RecordingVisionMatcher({this.distance = 0.1});

  final double distance;
  final List<List<VisionFrameCandidateRequest>> calls =
      <List<VisionFrameCandidateRequest>>[];
  final List<String> cancelledRequestIds = <String>[];

  @override
  Future<List<VisionFrameMatch>> match({
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) {
    return matchCancellable(
      requestId: 'legacy',
      queryPath: queryPath,
      queryBookmarkData: queryBookmarkData,
      candidates: candidates,
      cancellation: cancellation,
    );
  }

  @override
  Future<List<VisionFrameMatch>> matchCancellable({
    required String requestId,
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) async {
    calls.add(List<VisionFrameCandidateRequest>.from(candidates));
    return <VisionFrameMatch>[
      for (final candidate in candidates)
        VisionFrameMatch(
          mediaId: candidate.mediaId,
          distance: distance,
          timestamp: candidate.timestamp,
          positionPercent: 50,
        ),
    ];
  }

  @override
  Future<void> cancel(String requestId) async {
    cancelledRequestIds.add(requestId);
  }
}

class _RecordingSessionVisionMatcher
    implements CancellableVisionFrameMatcher, SessionVisionFrameMatcher {
  _RecordingSessionVisionMatcher({
    double Function(VisionFrameCandidateRequest candidate)?
    distanceForCandidate,
  }) : distanceForCandidate = distanceForCandidate ?? ((_) => 0.1);

  final double Function(VisionFrameCandidateRequest candidate)
  distanceForCandidate;
  final List<List<VisionFrameCandidateRequest>> calls =
      <List<VisionFrameCandidateRequest>>[];
  var startCalls = 0;
  var verifyBatchCalls = 0;
  var endCalls = 0;
  var cancelSessionCalls = 0;
  var updatesIssued = 0;
  final Set<String> failedMediaIds = <String>{};
  final Set<String> failFirstMediaIds = <String>{};
  final Set<String> _failedFirstMediaIds = <String>{};
  final Set<String> failAfterFirstBatchMediaIds = <String>{};
  bool suppressUpdates = false;

  @override
  Future<List<VisionFrameMatch>> match({
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) async => [
    for (final candidate in candidates)
      VisionFrameMatch(
        mediaId: candidate.mediaId,
        queryId: candidate.queryId,
        distance: distanceForCandidate(candidate),
        timestamp: candidate.timestamp,
        positionPercent: 50,
        presentationTime: candidate.presentationTime,
      ),
  ];

  @override
  Future<List<VisionFrameMatch>> matchCancellable({
    required String requestId,
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) async {
    calls.add(List<VisionFrameCandidateRequest>.from(candidates));
    return match(
      queryPath: queryPath,
      queryBookmarkData: queryBookmarkData,
      candidates: candidates,
      cancellation: cancellation,
    );
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<void> startSession({
    required String sessionId,
    required List<VisionSessionQuery> queries,
    DuplicateScanCancellation? cancellation,
  }) async {
    startCalls++;
  }

  @override
  Future<VisionSessionBatchResult> verifyBatch({
    required String sessionId,
    required String requestId,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
    void Function(VisionSessionBatchUpdate update)? onUpdate,
  }) async {
    verifyBatchCalls++;
    calls.add(List<VisionFrameCandidateRequest>.from(candidates));
    final byMediaId = <String, List<VisionFrameCandidateRequest>>{};
    for (final candidate in candidates) {
      byMediaId.putIfAbsent(candidate.mediaId, () => []).add(candidate);
    }
    final allMatches = <VisionFrameMatch>[];
    final failures = <VisionSessionVideoFailure>[];
    var completed = 0;
    var verified = 0;
    for (final entry in byMediaId.entries) {
      completed++;
      final failed =
          failedMediaIds.contains(entry.key) ||
          (failFirstMediaIds.contains(entry.key) &&
              _failedFirstMediaIds.add(entry.key)) ||
          (failAfterFirstBatchMediaIds.contains(entry.key) &&
              verifyBatchCalls > 1);
      final matches = failed
          ? const <VisionFrameMatch>[]
          : <VisionFrameMatch>[
              for (final candidate in entry.value)
                VisionFrameMatch(
                  mediaId: candidate.mediaId,
                  queryId: candidate.queryId,
                  distance: distanceForCandidate(candidate),
                  timestamp: candidate.timestamp,
                  positionPercent: 50,
                  presentationTime: candidate.presentationTime,
                ),
            ];
      if (failed) {
        failures.add(
          VisionSessionVideoFailure(mediaId: entry.key, message: 'failed'),
        );
      } else {
        verified++;
        allMatches.addAll(matches);
      }
      updatesIssued++;
      if (!suppressUpdates) {
        onUpdate?.call(
          VisionSessionBatchUpdate(
            sessionId: sessionId,
            requestId: requestId,
            mediaId: entry.key,
            matches: matches,
            completedVideoCount: completed,
            verifiedVideoCount: verified,
            failureMessage: failed ? 'failed' : null,
          ),
        );
      }
    }
    return VisionSessionBatchResult(
      matches: allMatches,
      failures: failures,
      completedVideoCount: completed,
      verifiedVideoCount: verified,
    );
  }

  @override
  Future<void> endSession(String sessionId) async {
    endCalls++;
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    cancelSessionCalls++;
  }
}

class _PackedFakeMaximumIndexDataSource extends _FakeMaximumIndexDataSource
    implements PackedVideoMaximumFrameIndexDataSource {
  _PackedFakeMaximumIndexDataSource(super.statuses, super.chunksByMediaId);

  @override
  Stream<VideoMaximumFrameIndexEncodedChunk> streamEncodedChunks(
    String mediaId,
  ) async* {
    for (final chunk
        in chunksByMediaId[mediaId] ?? const <VideoMaximumFrameIndexChunk>[]) {
      yield VideoMaximumFrameIndexEncodedChunk(
        mediaId: chunk.mediaId,
        chunkIndex: chunk.chunkIndex,
        fingerprint: chunk.fingerprint,
        descriptorBytes: const MaximumVideoFrameDescriptorCodec().encode(
          chunk.descriptors,
        ),
        computedAt: chunk.computedAt,
      );
    }
  }
}

class _GenerationAwareFakeMaximumIndexDataSource
    extends _FakeMaximumIndexDataSource
    implements GenerationAwareVideoMaximumFrameIndexDataSource {
  _GenerationAwareFakeMaximumIndexDataSource(
    super.statuses,
    super.chunksByMediaId,
  );

  @override
  int generation = 0;

  @override
  Future<bool> beginIfCurrent(
    VideoMaximumFrameIndexStatus status,
    int expectedGeneration,
  ) async {
    if (expectedGeneration != generation) {
      return false;
    }
    await begin(status);
    return true;
  }

  @override
  Future<bool> putChunkIfCurrent(
    VideoMaximumFrameIndexChunk chunk,
    int expectedGeneration,
  ) async {
    if (expectedGeneration != generation) {
      return false;
    }
    await putChunk(chunk);
    return true;
  }

  @override
  Future<bool> completeIfCurrent(
    VideoMaximumFrameIndexStatus status,
    int expectedGeneration,
  ) async {
    if (expectedGeneration != generation) {
      return false;
    }
    await complete(status);
    return true;
  }
}

MediaEntity _video({String id = 'video'}) => MediaEntity(
  id: id,
  path: '/library/$id.mp4',
  name: '$id.mp4',
  type: MediaType.video,
  size: 1000,
  lastModified: DateTime(2024),
  tagIds: const <String>[],
  directoryId: 'directory',
);

MaximumVideoFrameDescriptor _descriptor(
  int frameIndex,
  int hash, {
  String mediaId = 'video',
}) {
  return MaximumVideoFrameDescriptor(
    mediaId: mediaId,
    frameIndex: frameIndex,
    timestamp: Duration(seconds: frameIndex),
    fullFrameHash: hash,
    centerCropHash: hash,
    width: 1920,
    height: 1080,
    presentationTime: VideoFramePresentationTime(
      value: frameIndex * 30000,
      timescale: 30000,
    ),
  );
}

MaximumVideoFrameDescriptor _descriptorWithHashes(
  int frameIndex,
  int fullFrameHash,
  int centerCropHash, {
  String mediaId = 'video',
}) {
  return MaximumVideoFrameDescriptor(
    mediaId: mediaId,
    frameIndex: frameIndex,
    timestamp: Duration(seconds: frameIndex),
    fullFrameHash: fullFrameHash,
    centerCropHash: centerCropHash,
    width: 1920,
    height: 1080,
  );
}

VideoMaximumFrameIndexStatus _completeStatus(
  MediaEntity video, {
  int frameCount = 3,
  int chunkCount = 1,
}) {
  return VideoMaximumFrameIndexStatus(
    mediaId: video.id,
    fingerprint: maximumVideoFrameLookupFingerprint(
      size: video.size,
      lastModified: video.lastModified,
    ),
    sourceSize: video.size,
    sourceLastModified: video.lastModified,
    descriptorVersion: maximumVideoFrameDescriptorVersion,
    visionRevision: maximumVideoFrameVisionRevision,
    frameCount: frameCount,
    chunkCount: chunkCount,
    state: MaximumVideoFrameIndexState.complete,
    computedAt: DateTime(2024),
  );
}

ImageLookupQuery _query(String name) {
  final source = ImageLookupSource(
    path: '/queries/$name.jpg',
    name: '$name.jpg',
    size: 10,
    lastModified: DateTime(2024),
  );
  return ImageLookupQuery(source: source, hash: 0, width: 800, height: 600);
}

void main() {
  test(
    'persists chunks only after a terminal native completion marker',
    () async {
      final video = _video();
      final dataSource = _FakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{},
        <String, List<VideoMaximumFrameIndexChunk>>{},
      );
      final indexer = _FakeMaximumIndexer(<NativeMaximumVideoFrameChunk>[
        NativeMaximumVideoFrameChunk(
          frames: <NativeMaximumVideoFrame>[
            NativeMaximumVideoFrame(
              frameIndex: 0,
              timestamp: Duration.zero,
              presentationTime: const VideoFramePresentationTime(
                value: 0,
                timescale: 600,
              ),
              fullFrameHash: 0,
              centerCropHash: 0,
              width: 1920,
              height: 1080,
            ),
          ],
          isComplete: true,
        ),
      ]);
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        maximumVideoFrameIndexer: indexer,
      );

      final events = await repository
          .hashVideoFrames(lookupPrecision: VideoFrameLookupPrecision.maximum)
          .toList();

      expect(events.last.failed, 0);
      expect(dataSource.statuses[video.id]!.isComplete, isTrue);
      expect(dataSource.statuses[video.id]!.frameCount, 1);
      expect(dataSource.chunksByMediaId[video.id], hasLength(1));
    },
  );

  test('cancels the native indexer and removes its partial cache', () async {
    final video = _video();
    final dataSource = _FakeMaximumIndexDataSource(
      <String, VideoMaximumFrameIndexStatus>{},
      <String, List<VideoMaximumFrameIndexChunk>>{},
    );
    final indexer = _FakeMaximumIndexer(<NativeMaximumVideoFrameChunk>[
      NativeMaximumVideoFrameChunk(
        frames: <NativeMaximumVideoFrame>[
          NativeMaximumVideoFrame(
            frameIndex: 0,
            timestamp: Duration.zero,
            presentationTime: const VideoFramePresentationTime(
              value: 0,
              timescale: 600,
            ),
            fullFrameHash: 0,
            centerCropHash: 0,
            width: 1920,
            height: 1080,
          ),
        ],
        isComplete: false,
      ),
      const NativeMaximumVideoFrameChunk(
        frames: <NativeMaximumVideoFrame>[],
        isComplete: true,
      ),
    ], waitForCancellation: true);
    final repository = DuplicateRepositoryImpl(
      mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
      hashDataSource: _FakeHashDataSource(),
      dismissedDataSource: _FakeDismissedDataSource(),
      videoMaximumFrameIndexDataSource: dataSource,
      maximumVideoFrameIndexer: indexer,
    );
    final cancellation = DuplicateScanCancellation();
    final events = <DuplicateScanProgress>[];
    final subscription = repository
        .hashVideoFrames(
          lookupPrecision: VideoFrameLookupPrecision.maximum,
          cancellation: cancellation,
        )
        .listen((event) {
          events.add(event);
          if (event.currentItemProcessed > 0) {
            cancellation.cancel();
          }
        });
    await subscription.asFuture<void>();

    expect(indexer.cancelCalls, 1);
    expect(events.last.isCancelled, isTrue);
    expect(dataSource.statuses, isEmpty);
    expect(dataSource.chunksByMediaId, isEmpty);
  });

  test(
    'scans maximum chunks once for all queries and retains coarse-hash fallbacks',
    () async {
      final video = _video();
      final status = _completeStatus(video);
      final chunk = VideoMaximumFrameIndexChunk(
        mediaId: video.id,
        chunkIndex: 0,
        fingerprint: status.fingerprint,
        descriptors: <MaximumVideoFrameDescriptor>[
          _descriptor(0, 0x3FFF),
          _descriptor(1, 0x1FFF),
          _descriptor(2, 0x3FFF),
        ],
        computedAt: DateTime(2024),
      );
      final dataSource = _FakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        <String, List<VideoMaximumFrameIndexChunk>>{
          video.id: <VideoMaximumFrameIndexChunk>[chunk],
        },
      );
      final matcher = _RecordingVisionMatcher();
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        directoryRepository: _FakeDirectoryRepository(<DirectoryEntity>[
          DirectoryEntity(
            id: 'directory',
            path: '/library',
            name: 'Library',
            thumbnailPath: null,
            tagIds: const <String>[],
            lastModified: DateTime(2024),
            bookmarkData: 'library-bookmark',
          ),
        ]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );
      final progress = <ImageLookupProgress>[];

      final batch = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('one'), _query('two')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        onProgress: progress.add,
      );

      expect(dataSource.streamCalls, 1);
      expect(batch.results, hasLength(2));
      expect(batch.results[0].matches, hasLength(1));
      expect(batch.results[1].matches, hasLength(1));
      expect(batch.results[0].matches.single.visionDistance, 0.1);
      expect(
        progress.map((event) => event.stage),
        containsAllInOrder(<ImageLookupProgressStage>[
          ImageLookupProgressStage.preparingDescriptors,
          ImageLookupProgressStage.scanningVideoFrames,
          ImageLookupProgressStage.verifyingVideoFrames,
        ]),
      );
      final completedScan = progress.lastWhere(
        (event) =>
            event.stage == ImageLookupProgressStage.scanningVideoFrames &&
            event.currentItemProcessed > 0,
      );
      expect(completedScan.currentItemProcessed, 3);
      expect(completedScan.currentItemTotal, 3);
      expect(
        matcher.calls
            .expand((call) => call)
            .every((candidate) => candidate.bookmarkData == 'library-bookmark'),
        isTrue,
      );
      final middleCandidate = matcher.calls
          .expand((call) => call)
          .firstWhere(
            (candidate) => candidate.timestamp == const Duration(seconds: 1),
          );
      expect(
        middleCandidate.verificationTimestamps,
        containsAll(<Duration>[
          Duration.zero,
          const Duration(seconds: 1),
          const Duration(seconds: 2),
        ]),
      );
      expect(
        middleCandidate.verificationPresentationTimes,
        containsAll(<VideoFramePresentationTime>[
          const VideoFramePresentationTime(value: 0, timescale: 30000),
          const VideoFramePresentationTime(value: 30000, timescale: 30000),
          const VideoFramePresentationTime(value: 60000, timescale: 30000),
        ]),
      );
    },
  );

  test('stale chunks cannot produce maximum-precision matches', () async {
    final video = _video();
    final status = _completeStatus(video);
    final dataSource = _FakeMaximumIndexDataSource(
      <String, VideoMaximumFrameIndexStatus>{video.id: status},
      <String, List<VideoMaximumFrameIndexChunk>>{
        video.id: <VideoMaximumFrameIndexChunk>[
          VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: 0,
            fingerprint: 'stale',
            descriptors: <MaximumVideoFrameDescriptor>[_descriptor(0, 0)],
            computedAt: DateTime(2024),
          ),
        ],
      },
    );
    final repository = DuplicateRepositoryImpl(
      mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
      hashDataSource: _FakeHashDataSource(),
      dismissedDataSource: _FakeDismissedDataSource(),
      videoMaximumFrameIndexDataSource: dataSource,
      compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
      visionFrameMatcher: _RecordingVisionMatcher(),
    );

    final batch = await repository.rematchImageQueries(
      queries: <ImageLookupQuery>[_query('stale')],
      sensitivity: DuplicateSensitivity.strict,
      lookupMode: MediaLookupMode.videoFromFrame,
      lookupPrecision: VideoFrameLookupPrecision.maximum,
    );

    expect(batch.results.single.matches, isEmpty);
  });

  test('packed scans retain the predecessor across chunk boundaries', () async {
    final video = _video();
    final status = _completeStatus(video, frameCount: 2, chunkCount: 2);
    final chunks = <String, List<VideoMaximumFrameIndexChunk>>{
      video.id: <VideoMaximumFrameIndexChunk>[
        VideoMaximumFrameIndexChunk(
          mediaId: video.id,
          chunkIndex: 0,
          fingerprint: status.fingerprint,
          descriptors: <MaximumVideoFrameDescriptor>[_descriptor(0, -1)],
          computedAt: DateTime(2024),
        ),
        VideoMaximumFrameIndexChunk(
          mediaId: video.id,
          chunkIndex: 1,
          fingerprint: status.fingerprint,
          descriptors: <MaximumVideoFrameDescriptor>[_descriptor(1, 0)],
          computedAt: DateTime(2024),
        ),
      ],
    };
    final matcher = _RecordingVisionMatcher();
    final repository = DuplicateRepositoryImpl(
      mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
      hashDataSource: _FakeHashDataSource(),
      dismissedDataSource: _FakeDismissedDataSource(),
      videoMaximumFrameIndexDataSource: _PackedFakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        chunks,
      ),
      compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
      visionFrameMatcher: matcher,
    );

    await repository.rematchImageQueries(
      queries: <ImageLookupQuery>[_query('packed-boundary')],
      sensitivity: DuplicateSensitivity.strict,
      lookupMode: MediaLookupMode.videoFromFrame,
      lookupPrecision: VideoFrameLookupPrecision.maximum,
    );

    final boundaryCandidate = matcher.calls
        .expand((call) => call)
        .firstWhere(
          (candidate) => candidate.timestamp == const Duration(seconds: 1),
        );
    expect(
      boundaryCandidate.verificationTimestamps,
      containsAll(<Duration>[Duration.zero, const Duration(seconds: 1)]),
    );
  });

  test('packed selection preserves a better legacy variant', () async {
    final video = _video();
    final status = _completeStatus(video, frameCount: 6);
    final legacyTenBits = (1 << 10) - 1;
    final legacyFiveBits = (1 << 5) - 1;
    final descriptors = <MaximumVideoFrameDescriptor>[
      _descriptorWithHashes(0, legacyTenBits, -1 ^ legacyTenBits),
      for (var frameIndex = 1; frameIndex < 5; frameIndex++)
        _descriptorWithHashes(frameIndex, -1, 0),
      _descriptorWithHashes(5, legacyFiveBits, -1 ^ legacyFiveBits),
    ];
    final chunk = VideoMaximumFrameIndexChunk(
      mediaId: video.id,
      chunkIndex: 0,
      fingerprint: status.fingerprint,
      descriptors: descriptors,
      computedAt: DateTime(2024),
    );

    Future<Duration> firstCandidate(
      VideoMaximumFrameIndexDataSource dataSource,
      String queryName,
    ) async {
      final matcher = _RecordingVisionMatcher();
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: const _FixedCompactDescriptorGenerator(
          fullFrameHash: 0,
          centerCropHash: -1,
        ),
        visionFrameMatcher: matcher,
      );
      await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query(queryName)],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );
      return matcher.calls.first.first.timestamp;
    }

    final packedDataSource = _PackedFakeMaximumIndexDataSource(
      <String, VideoMaximumFrameIndexStatus>{video.id: status},
      <String, List<VideoMaximumFrameIndexChunk>>{
        video.id: <VideoMaximumFrameIndexChunk>[chunk],
      },
    );
    final decodedDataSource = _FakeMaximumIndexDataSource(
      <String, VideoMaximumFrameIndexStatus>{video.id: status},
      <String, List<VideoMaximumFrameIndexChunk>>{
        video.id: <VideoMaximumFrameIndexChunk>[chunk],
      },
    );
    expect(
      await firstCandidate(packedDataSource, 'packed-legacy'),
      const Duration(seconds: 5),
    );
    expect(
      await firstCandidate(decodedDataSource, 'decoded-legacy'),
      const Duration(seconds: 5),
    );
  });

  test(
    'legacy selection does not evict a better overlapping cross window',
    () async {
      final video = _video();
      final status = _completeStatus(video, frameCount: 3);
      final legacyTenBits = (1 << 10) - 1;
      final frames = <MaximumVideoFrameDescriptor>[
        MaximumVideoFrameDescriptor(
          mediaId: video.id,
          frameIndex: 0,
          timestamp: Duration.zero,
          fullFrameHash: 0,
          centerCropHash: -1,
          width: 1920,
          height: 1080,
        ),
        MaximumVideoFrameDescriptor(
          mediaId: video.id,
          frameIndex: 1,
          timestamp: const Duration(milliseconds: 500),
          fullFrameHash: -1,
          centerCropHash: 0,
          width: 1920,
          height: 1080,
        ),
        MaximumVideoFrameDescriptor(
          mediaId: video.id,
          frameIndex: 2,
          timestamp: const Duration(milliseconds: 600),
          fullFrameHash: legacyTenBits,
          centerCropHash: -1 ^ legacyTenBits,
          width: 1920,
          height: 1080,
        ),
      ];
      final matcher = _RecordingVisionMatcher();
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: _PackedFakeMaximumIndexDataSource(
          <String, VideoMaximumFrameIndexStatus>{video.id: status},
          <String, List<VideoMaximumFrameIndexChunk>>{
            video.id: <VideoMaximumFrameIndexChunk>[
              VideoMaximumFrameIndexChunk(
                mediaId: video.id,
                chunkIndex: 0,
                fingerprint: status.fingerprint,
                descriptors: frames,
                computedAt: DateTime(2024),
              ),
            ],
          },
        ),
        compactDescriptorGenerator: const _FixedCompactDescriptorGenerator(
          fullFrameHash: 0,
          centerCropHash: -1,
        ),
        visionFrameMatcher: matcher,
      );

      await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('cross-window')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      final timestamps = matcher.calls
          .expand((call) => call)
          .map((candidate) => candidate.timestamp)
          .toSet();
      expect(timestamps, contains(const Duration(milliseconds: 500)));
      expect(timestamps, isNot(contains(const Duration(milliseconds: 600))));
    },
  );

  test(
    'session verification publishes per-video deltas and counts failures',
    () async {
      const videoCount = 20;
      final videos = <MediaEntity>[];
      final statuses = <String, VideoMaximumFrameIndexStatus>{};
      final chunks = <String, List<VideoMaximumFrameIndexChunk>>{};
      for (var videoIndex = 0; videoIndex < videoCount; videoIndex++) {
        final video = _video(id: 'session-video-$videoIndex');
        final status = _completeStatus(video, frameCount: 3);
        videos.add(video);
        statuses[video.id] = status;
        chunks[video.id] = <VideoMaximumFrameIndexChunk>[
          VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: 0,
            fingerprint: status.fingerprint,
            descriptors: <MaximumVideoFrameDescriptor>[
              _descriptor(0, videoIndex, mediaId: video.id),
              _descriptor(1, videoIndex + 1, mediaId: video.id),
              _descriptor(2, videoIndex + 2, mediaId: video.id),
            ],
            computedAt: DateTime(2024),
          ),
        ];
      }
      final matcher = _RecordingSessionVisionMatcher()
        ..failedMediaIds.add('session-video-19');
      final updates = <ImageLookupUpdate>[];
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(videos),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: _FakeMaximumIndexDataSource(
          statuses,
          chunks,
        ),
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );

      final batch = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('session')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        onUpdate: updates.add,
      );

      expect(matcher.startCalls, 1);
      expect(matcher.endCalls, 1);
      expect(matcher.verifyBatchCalls, greaterThan(1));
      expect(matcher.updatesIssued, greaterThan(matcher.verifyBatchCalls));
      expect(
        matcher.calls.every(
          (call) =>
              call.map((candidate) => candidate.mediaId).toSet().length <= 8,
        ),
        isTrue,
      );
      expect(
        updates.any(
          (update) =>
              update.progress.verificationPhase ==
              ImageLookupVerificationPhase.initial,
        ),
        isTrue,
      );
      expect(
        updates.any(
          (update) =>
              update.progress.verificationPhase ==
              ImageLookupVerificationPhase.remaining,
        ),
        isTrue,
      );
      expect(batch.verificationSummary?.eligibleVideoCount, videoCount);
      expect(batch.verificationSummary?.verifiedVideoCount, videoCount - 1);
      expect(batch.verificationSummary?.failedVideoCount, 1);
      expect(batch.results.single.matches, hasLength(videoCount - 1));
    },
  );

  test(
    'session candidate fingerprints are stable per video across queries',
    () async {
      final videos = <MediaEntity>[
        _video(id: 'fingerprint-a'),
        _video(id: 'fingerprint-b'),
      ];
      final statuses = <String, VideoMaximumFrameIndexStatus>{};
      final chunks = <String, List<VideoMaximumFrameIndexChunk>>{};
      for (final video in videos) {
        final status = _completeStatus(video);
        statuses[video.id] = status;
        chunks[video.id] = <VideoMaximumFrameIndexChunk>[
          VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: 0,
            fingerprint: status.fingerprint,
            descriptors: <MaximumVideoFrameDescriptor>[
              _descriptor(0, 0, mediaId: video.id),
              _descriptor(1, 0, mediaId: video.id),
              _descriptor(2, 0, mediaId: video.id),
            ],
            computedAt: DateTime(2024),
          ),
        ];
      }
      final matcher = _RecordingSessionVisionMatcher();
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(videos),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: _FakeMaximumIndexDataSource(
          statuses,
          chunks,
        ),
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );

      await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[
          _query('fingerprint-one'),
          _query('fingerprint-two'),
        ],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      final fingerprintsByVideo = <String, Set<String>>{};
      for (final call in matcher.calls) {
        for (final candidate in call) {
          fingerprintsByVideo
              .putIfAbsent(candidate.mediaId, () => <String>{})
              .add(candidate.sourceFingerprint!);
        }
      }
      expect(fingerprintsByVideo, hasLength(2));
      expect(
        fingerprintsByVideo.values.every(
          (fingerprints) => fingerprints.length == 1,
        ),
        isTrue,
      );
      expect(
        fingerprintsByVideo.values
            .map((fingerprints) => fingerprints.single)
            .toSet(),
        hasLength(2),
      );
    },
  );

  test(
    'a failure remains sticky when a later window succeeds and prevents caching',
    () async {
      final directory = await Directory.systemTemp.createTemp('mfv-sticky-');
      final queryFile = File('${directory.path}/query.jpg');
      final videoFile = File('${directory.path}/video.mp4');
      await queryFile.writeAsBytes(List<int>.filled(10, 1));
      await videoFile.writeAsBytes(List<int>.filled(1000, 2));
      try {
        final queryStat = await queryFile.stat();
        final videoStat = await videoFile.stat();
        final query = ImageLookupQuery(
          source: ImageLookupSource(
            path: queryFile.path,
            name: 'query.jpg',
            size: queryStat.size,
            lastModified: queryStat.modified,
          ),
          hash: 0,
          width: 800,
          height: 600,
        );
        final video = _video().copyWith(
          path: videoFile.path,
          size: videoStat.size,
          lastModified: videoStat.modified,
        );
        final status = _completeStatus(video);
        final dataSource = _FakeMaximumIndexDataSource(
          <String, VideoMaximumFrameIndexStatus>{video.id: status},
          <String, List<VideoMaximumFrameIndexChunk>>{
            video.id: <VideoMaximumFrameIndexChunk>[
              VideoMaximumFrameIndexChunk(
                mediaId: video.id,
                chunkIndex: 0,
                fingerprint: status.fingerprint,
                descriptors: <MaximumVideoFrameDescriptor>[
                  _descriptor(0, 0),
                  _descriptor(1, 0),
                  _descriptor(2, 0),
                ],
                computedAt: DateTime(2024),
              ),
            ],
          },
        );
        final matcher = _RecordingSessionVisionMatcher()
          ..failFirstMediaIds.add(video.id);
        final repository = DuplicateRepositoryImpl(
          mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
          hashDataSource: _FakeHashDataSource(),
          dismissedDataSource: _FakeDismissedDataSource(),
          videoMaximumFrameIndexDataSource: dataSource,
          compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
          visionFrameMatcher: matcher,
        );

        final first = await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.strict,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        final callsAfterFirst = matcher.verifyBatchCalls;

        expect(first.verificationSummary?.failedVideoCount, 1);
        expect(first.verificationSummary?.verifiedVideoCount, 0);
        expect(first.results.single.matches, hasLength(1));

        final second = await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        expect(matcher.verifyBatchCalls, greaterThan(callsAfterFirst));
        expect(second.results.single.matches, hasLength(1));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'a final batch failure removes prior verification status but keeps matches',
    () async {
      final video = _video();
      final status = _completeStatus(video);
      final dataSource = _FakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        <String, List<VideoMaximumFrameIndexChunk>>{
          video.id: <VideoMaximumFrameIndexChunk>[
            VideoMaximumFrameIndexChunk(
              mediaId: video.id,
              chunkIndex: 0,
              fingerprint: status.fingerprint,
              descriptors: <MaximumVideoFrameDescriptor>[
                _descriptor(0, 0),
                _descriptor(1, 0),
                _descriptor(2, 0),
              ],
              computedAt: DateTime(2024),
            ),
          ],
        },
      );
      final matcher = _RecordingSessionVisionMatcher()
        ..failAfterFirstBatchMediaIds.add(video.id)
        ..suppressUpdates = true;
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );

      final batch = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('final-failure')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      expect(batch.verificationSummary?.failedVideoCount, 1);
      expect(batch.verificationSummary?.verifiedVideoCount, 0);
      expect(batch.results.single.matches, hasLength(1));
    },
  );

  test(
    'equal Vision scores use the exact presentation time as a tie-breaker',
    () async {
      final video = _video();
      final status = _completeStatus(video);
      final frames = <MaximumVideoFrameDescriptor>[
        MaximumVideoFrameDescriptor(
          mediaId: video.id,
          frameIndex: 0,
          timestamp: const Duration(seconds: 10),
          fullFrameHash: 0,
          centerCropHash: 0,
          width: 1920,
          height: 1080,
          presentationTime: const VideoFramePresentationTime(
            value: 300000,
            timescale: 30000,
          ),
        ),
        MaximumVideoFrameDescriptor(
          mediaId: video.id,
          frameIndex: 1,
          timestamp: const Duration(seconds: 1),
          fullFrameHash: 0,
          centerCropHash: 0,
          width: 1920,
          height: 1080,
          presentationTime: const VideoFramePresentationTime(
            value: 30000,
            timescale: 30000,
          ),
        ),
        _descriptor(2, 0),
      ];
      final dataSource = _FakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        <String, List<VideoMaximumFrameIndexChunk>>{
          video.id: <VideoMaximumFrameIndexChunk>[
            VideoMaximumFrameIndexChunk(
              mediaId: video.id,
              chunkIndex: 0,
              fingerprint: status.fingerprint,
              descriptors: frames,
              computedAt: DateTime(2024),
            ),
          ],
        },
      );
      final matcher = _RecordingSessionVisionMatcher(
        distanceForCandidate: (_) => 5,
      );
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );

      final batch = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('pts-tie')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      expect(batch.results.single.matches.single.visionDistance, 5);
      expect(
        batch.results.single.matches.single.matchedVideoFrame?.presentationTime,
        const VideoFramePresentationTime(value: 30000, timescale: 30000),
      );
      expect(
        batch.results.single.matches.single.matchedVideoFrame?.timestamp,
        const Duration(seconds: 1),
      );
    },
  );

  test(
    'sensitivity rematch is monotonic and does not rescan native Vision',
    () async {
      final video = _video();
      final status = _completeStatus(video);
      final chunks = <String, List<VideoMaximumFrameIndexChunk>>{
        video.id: <VideoMaximumFrameIndexChunk>[
          VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: 0,
            fingerprint: status.fingerprint,
            descriptors: <MaximumVideoFrameDescriptor>[
              _descriptor(0, 0),
              _descriptor(1, 0),
              _descriptor(2, 0),
            ],
            computedAt: DateTime(2024),
          ),
        ],
      };
      final matcher = _RecordingVisionMatcher(distance: 30);
      final dataSource = _GenerationAwareFakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        chunks,
      );
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
        videoSourceSnapshotValidator: (_) async => true,
      );
      final queryDirectory = await Directory.systemTemp.createTemp(
        'mfv-sensitivity-query-',
      );
      final queryFile = File('${queryDirectory.path}/query.jpg');
      await queryFile.writeAsBytes(List<int>.filled(10, 1));
      final queryStat = await queryFile.stat();
      final query = ImageLookupQuery(
        source: ImageLookupSource(
          path: queryFile.path,
          name: 'query.jpg',
          size: queryStat.size,
          lastModified: queryStat.modified,
        ),
        hash: 0,
        width: 800,
        height: 600,
      );

      try {
        final strict = await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.strict,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        final nativeCallsAfterStrict = matcher.calls.length;
        final loose = await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );

        expect(strict.results.single.matches, isEmpty);
        expect(loose.results.single.matches, hasLength(1));
        expect(matcher.calls.length, nativeCallsAfterStrict);

        dataSource.statuses[video.id] = status.copyWith(
          state: MaximumVideoFrameIndexState.building,
        );
        final incomplete = await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        expect(incomplete.verificationSummary?.eligibleVideoCount, 0);
        expect(incomplete.results.single.matches, isEmpty);

        dataSource.generation++;
        final rebuiltStatus = VideoMaximumFrameIndexStatus(
          mediaId: status.mediaId,
          fingerprint: status.fingerprint,
          sourceSize: status.sourceSize,
          sourceLastModified: status.sourceLastModified,
          descriptorVersion: status.descriptorVersion,
          visionRevision: status.visionRevision,
          frameCount: status.frameCount,
          chunkCount: status.chunkCount,
          state: status.state,
          computedAt: DateTime(2025),
        );
        dataSource.statuses[video.id] = rebuiltStatus;
        dataSource.chunksByMediaId[video.id] = <VideoMaximumFrameIndexChunk>[
          VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: 0,
            fingerprint: rebuiltStatus.fingerprint,
            descriptors: chunks[video.id]!.single.descriptors,
            computedAt: DateTime(2024),
          ),
        ];
        await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        expect(matcher.calls.length, greaterThan(nativeCallsAfterStrict));
      } finally {
        await queryDirectory.delete(recursive: true);
      }
    },
  );

  test(
    'remaining windows cannot overwrite the pinned legacy best score',
    () async {
      final video = _video();
      final status = _completeStatus(video);
      final dataSource = _FakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        <String, List<VideoMaximumFrameIndexChunk>>{
          video.id: <VideoMaximumFrameIndexChunk>[
            VideoMaximumFrameIndexChunk(
              mediaId: video.id,
              chunkIndex: 0,
              fingerprint: status.fingerprint,
              descriptors: <MaximumVideoFrameDescriptor>[
                _descriptor(0, 0),
                _descriptor(1, 1),
                _descriptor(2, 2),
              ],
              computedAt: DateTime(2024),
            ),
          ],
        },
      );
      final matcher = _RecordingSessionVisionMatcher(
        distanceForCandidate: (candidate) =>
            candidate.timestamp == Duration.zero ? 0 : 30,
      );
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );

      final batch = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('pinned')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      expect(batch.results.single.matches, hasLength(1));
      expect(batch.results.single.matches.single.visionDistance, 0);
      expect(
        batch.results.single.matches.single.matchedVideoFrame?.timestamp,
        Duration.zero,
      );
    },
  );

  test('source metadata changes invalidate the raw score cache', () async {
    final directory = await Directory.systemTemp.createTemp('mfv-query-');
    final file = File('${directory.path}/query.jpg');
    await file.writeAsBytes(List<int>.filled(10, 1));
    try {
      final stat = await file.stat();
      final source = ImageLookupSource(
        path: file.path,
        name: 'query.jpg',
        size: stat.size,
        lastModified: stat.modified,
      );
      final query = ImageLookupQuery(
        source: source,
        hash: 0,
        width: 800,
        height: 600,
      );
      final videoFile = File('${directory.path}/video.mp4');
      await videoFile.writeAsBytes(List<int>.filled(1000, 7));
      final videoStat = await videoFile.stat();
      final video = _video().copyWith(
        path: videoFile.path,
        size: videoStat.size,
        lastModified: videoStat.modified,
      );
      final status = _completeStatus(video);
      final dataSource = _FakeMaximumIndexDataSource(
        <String, VideoMaximumFrameIndexStatus>{video.id: status},
        <String, List<VideoMaximumFrameIndexChunk>>{
          video.id: <VideoMaximumFrameIndexChunk>[
            VideoMaximumFrameIndexChunk(
              mediaId: video.id,
              chunkIndex: 0,
              fingerprint: status.fingerprint,
              descriptors: <MaximumVideoFrameDescriptor>[
                _descriptor(0, 0),
                _descriptor(1, 0),
                _descriptor(2, 0),
              ],
              computedAt: DateTime(2024),
            ),
          ],
        },
      );
      final matcher = _RecordingVisionMatcher();
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );

      await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[query],
        sensitivity: DuplicateSensitivity.loose,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );
      final nativeCallsAfterFirstSearch = matcher.calls.length;
      await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[query],
        sensitivity: DuplicateSensitivity.loose,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );
      expect(matcher.calls.length, nativeCallsAfterFirstSearch);

      await file.writeAsBytes(List<int>.filled(11, 2));
      await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[query],
        sensitivity: DuplicateSensitivity.loose,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );
      expect(matcher.calls.length, greaterThan(nativeCallsAfterFirstSearch));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test(
    'live video changes invalidate cached scores without a library refresh',
    () async {
      final directory = await Directory.systemTemp.createTemp('mfv-video-');
      final queryFile = File('${directory.path}/query.jpg');
      final videoFile = File('${directory.path}/video.mp4');
      await queryFile.writeAsBytes(List<int>.filled(10, 1));
      await videoFile.writeAsBytes(List<int>.filled(1000, 2));
      try {
        final queryStat = await queryFile.stat();
        final videoStat = await videoFile.stat();
        final query = ImageLookupQuery(
          source: ImageLookupSource(
            path: queryFile.path,
            name: 'query.jpg',
            size: queryStat.size,
            lastModified: queryStat.modified,
          ),
          hash: 0,
          width: 800,
          height: 600,
        );
        final video = _video().copyWith(
          path: videoFile.path,
          size: videoStat.size,
          lastModified: videoStat.modified,
        );
        final status = _completeStatus(video);
        final dataSource = _FakeMaximumIndexDataSource(
          <String, VideoMaximumFrameIndexStatus>{video.id: status},
          <String, List<VideoMaximumFrameIndexChunk>>{
            video.id: <VideoMaximumFrameIndexChunk>[
              VideoMaximumFrameIndexChunk(
                mediaId: video.id,
                chunkIndex: 0,
                fingerprint: status.fingerprint,
                descriptors: <MaximumVideoFrameDescriptor>[
                  _descriptor(0, 0),
                  _descriptor(1, 0),
                  _descriptor(2, 0),
                ],
                computedAt: DateTime(2024),
              ),
            ],
          },
        );
        final matcher = _RecordingVisionMatcher();
        final repository = DuplicateRepositoryImpl(
          mediaRepository: _FakeMediaRepository(<MediaEntity>[video]),
          hashDataSource: _FakeHashDataSource(),
          dismissedDataSource: _FakeDismissedDataSource(),
          videoMaximumFrameIndexDataSource: dataSource,
          compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
          visionFrameMatcher: matcher,
        );

        await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        final callsAfterFirst = matcher.calls.length;
        await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        expect(matcher.calls.length, callsAfterFirst);

        await videoFile.writeAsBytes(List<int>.filled(1001, 9));
        await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        final callsAfterChange = matcher.calls.length;
        expect(callsAfterChange, greaterThan(callsAfterFirst));

        await videoFile.delete();
        await repository.rematchImageQueries(
          queries: <ImageLookupQuery>[query],
          sensitivity: DuplicateSensitivity.loose,
          lookupMode: MediaLookupMode.videoFromFrame,
          lookupPrecision: VideoFrameLookupPrecision.maximum,
        );
        expect(matcher.calls.length, greaterThan(callsAfterChange));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'large indexes verify every eligible video in bounded batches',
    () async {
      const videoCount = 2048;
      const framesPerVideo = 32;
      final videos = <MediaEntity>[];
      final statuses = <String, VideoMaximumFrameIndexStatus>{};
      final chunks = <String, List<VideoMaximumFrameIndexChunk>>{};
      for (var videoIndex = 0; videoIndex < videoCount; videoIndex++) {
        final video = _video(
          id: 'video-${videoIndex.toString().padLeft(4, '0')}',
        );
        final status = _completeStatus(video, frameCount: framesPerVideo);
        videos.add(video);
        statuses[video.id] = status;
        chunks[video.id] = <VideoMaximumFrameIndexChunk>[
          VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: 0,
            fingerprint: status.fingerprint,
            descriptors: <MaximumVideoFrameDescriptor>[
              for (
                var frameIndex = 0;
                frameIndex < framesPerVideo;
                frameIndex++
              )
                _descriptor(
                  frameIndex,
                  videoIndex + frameIndex,
                  mediaId: video.id,
                ),
            ],
            computedAt: DateTime(2024),
          ),
        ];
      }
      final dataSource = _FakeMaximumIndexDataSource(statuses, chunks);
      final matcher = _RecordingVisionMatcher();
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(videos),
        hashDataSource: _FakeHashDataSource(),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoMaximumFrameIndexDataSource: dataSource,
        compactDescriptorGenerator: _FakeCompactDescriptorGenerator(),
        visionFrameMatcher: matcher,
      );
      final stopwatch = Stopwatch()..start();

      final batch = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[_query('scale')],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
      );
      stopwatch.stop();

      expect(dataSource.streamCalls, videoCount);
      expect(matcher.calls.length, greaterThan(1));
      expect(
        matcher.calls.every(
          (call) =>
              call.map((candidate) => candidate.mediaId).toSet().length <= 8,
        ),
        isTrue,
      );
      expect(
        matcher.calls
            .expand((call) => call)
            .map((candidate) => candidate.mediaId)
            .toSet(),
        hasLength(videoCount),
      );
      expect(batch.results.single.matches, hasLength(videoCount));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/video_maximum_frame_index_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/repositories/duplicate_repository_impl.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_compact_descriptor_generator.dart';
import 'package:media_fast_view/features/duplicates/data/services/native_vision_frame_matcher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';

/// Measures real repository/storage work while explicitly excluding Vision.
DuplicateRepositoryImpl storageBenchmarkRepository({
  required List<MediaEntity> videos,
  required VideoMaximumFrameIndexDataSource dataSource,
}) => DuplicateRepositoryImpl(
  mediaRepository: _Media(videos),
  hashDataSource: _Hashes(),
  dismissedDataSource: _Dismissed(),
  videoMaximumFrameIndexDataSource: dataSource,
  compactDescriptorGenerator: _Descriptors(),
  visionFrameMatcher: _Verification(),
);

class _Media extends Fake implements MediaRepository {
  _Media(this.videos);
  final List<MediaEntity> videos;
  @override
  Future<List<MediaEntity>> getAllMedia() async => videos;
}

class _Hashes extends Fake implements PerceptualHashDataSource {}

class _Dismissed extends Fake implements DismissedGroupDataSource {}

class _Descriptors implements CompactImageDescriptorGenerator {
  @override
  Future<NativeCompactImageDescriptor?> generate({
    required String path,
    String? bookmarkData,
  }) async => const NativeCompactImageDescriptor(
    fullFrameHash: 0,
    centerCropHash: 0,
    width: 128,
    height: 96,
  );
}

class _Verification extends Fake
    implements VisionFrameMatcher, SessionVisionFrameMatcher {
  @override
  Future<void> startSession({
    required String sessionId,
    required List<VisionSessionQuery> queries,
    DuplicateScanCancellation? cancellation,
  }) async {}

  @override
  Future<void> endSession(String sessionId) async {}

  @override
  Future<void> cancelSession(String sessionId) async {}

  @override
  Future<VisionSessionBatchResult> verifyBatch({
    required String sessionId,
    required String requestId,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
    void Function(VisionSessionBatchUpdate update)? onUpdate,
  }) async {
    final grouped = <String, List<VisionFrameMatch>>{};
    for (final candidate in candidates) {
      grouped
          .putIfAbsent(candidate.mediaId, () => <VisionFrameMatch>[])
          .add(
            VisionFrameMatch(
              mediaId: candidate.mediaId,
              queryId: candidate.queryId,
              distance: 1,
              timestamp: candidate.timestamp,
              presentationTime: candidate.presentationTime,
            ),
          );
    }
    var completed = 0;
    for (final entry in grouped.entries) {
      completed++;
      onUpdate?.call(
        VisionSessionBatchUpdate(
          sessionId: sessionId,
          requestId: requestId,
          mediaId: entry.key,
          matches: entry.value,
          verifiedVideoCount: completed,
          completedVideoCount: completed,
        ),
      );
    }
    return VisionSessionBatchResult(
      matches: <VisionFrameMatch>[
        for (final matches in grouped.values) ...matches,
      ],
      failures: const <VisionSessionVideoFailure>[],
      verifiedVideoCount: grouped.length,
      completedVideoCount: grouped.length,
    );
  }
}

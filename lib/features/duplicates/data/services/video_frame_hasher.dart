import 'package:uuid/uuid.dart';

import '../../../thumbnails/domain/thumbnail_request.dart';
import '../../../thumbnails/domain/thumbnail_result.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/video_frame_hash.dart';
import 'native_video_frame_generator.dart';
import 'perceptual_hasher.dart';

abstract interface class VideoFrameHasher {
  Future<List<VideoFrameHash>?> hashVideo({
    required String mediaId,
    required String path,
    required int size,
    required DateTime lastModified,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  });
}

/// Extracts and hashes all representative frames in one native video pass.
class NativeVideoFrameHasher implements VideoFrameHasher {
  const NativeVideoFrameHasher({
    required VideoFrameGenerator generator,
    PerceptualHasher perceptualHasher = const PerceptualHasher(),
    Uuid uuid = const Uuid(),
  }) : _generator = generator,
       _perceptualHasher = perceptualHasher,
       _uuid = uuid;

  final VideoFrameGenerator _generator;
  final PerceptualHasher _perceptualHasher;
  final Uuid _uuid;

  @override
  Future<List<VideoFrameHash>?> hashVideo({
    required String mediaId,
    required String path,
    required int size,
    required DateTime lastModified,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  }) async {
    final requestId = _uuid.v4();
    final removeCancellationListener = cancellation?.addListener(
      () => _generator.cancel(requestId),
    );
    try {
      final frames = await _generator.generate(
        requestId: requestId,
        path: path,
        positionPercents: videoFrameSamplePercents,
        maximumPixelSize: ThumbnailSize.medium.maxPixelSize,
        bookmarkData: bookmarkData,
      );
      if (cancellation?.isCancelled ?? false) {
        return null;
      }
      if (frames.length != videoFrameSamplePercents.length ||
          frames.map((frame) => frame.positionPercent).toSet().length !=
              videoFrameSamplePercents.length ||
          !frames.every(
            (frame) => videoFrameSamplePercents.contains(frame.positionPercent),
          )) {
        return null;
      }
      final fingerprint = videoFrameLookupFingerprint(
        size: size,
        lastModified: lastModified,
      );
      final hashes = <VideoFrameHash>[];
      for (final frame in frames) {
        if (cancellation?.isCancelled ?? false) {
          return null;
        }
        final result = await _perceptualHasher.hashBytes(frame.bytes);
        if (result == null) {
          return null;
        }
        hashes.add(
          VideoFrameHash(
            mediaId: mediaId,
            positionPercent: frame.positionPercent,
            timestamp: frame.timestamp,
            hash: result.hash,
            width: result.width,
            height: result.height,
            fingerprint: fingerprint,
          ),
        );
      }
      hashes.sort(
        (first, second) =>
            first.positionPercent.compareTo(second.positionPercent),
      );
      return List<VideoFrameHash>.unmodifiable(hashes);
    } on ThumbnailCancelledException {
      return null;
    } catch (_) {
      return null;
    } finally {
      removeCancellationListener?.call();
    }
  }
}

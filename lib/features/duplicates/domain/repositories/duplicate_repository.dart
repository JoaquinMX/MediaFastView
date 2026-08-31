import '../../../../core/models/media_lookup_mode.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../entities/duplicate_group.dart';
import '../entities/duplicate_library_coverage.dart';
import '../entities/duplicate_scan_progress.dart';
import '../entities/video_frame_index_coverage.dart';
import '../entities/duplicate_sensitivity.dart';
import '../entities/image_lookup_batch.dart';
import '../entities/image_lookup_query.dart';
import '../entities/image_lookup_source.dart';
import '../entities/keeper_strategy.dart';

/// Finds and manages visually-similar image groups within the active profile's
/// library.
///
/// The two halves are deliberately split: [hashLibrary] is the expensive,
/// cancellable pass that decodes images and caches their perceptual hashes;
/// [loadGroups] is the cheap clustering step that runs off those cached hashes,
/// so retuning sensitivity never rescans.
abstract class DuplicateRepository {
  /// Hashes the selected visual [mediaTypes], reusing current cached hashes.
  Stream<DuplicateScanProgress> hashLibrary({
    DuplicateScanCancellation? cancellation,
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  });

  /// Reports current hash coverage for the selected visual [mediaTypes].
  Future<DuplicateLibraryCoverage> getLibraryCoverage({
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  });

  /// Reports how many active-profile videos have all five current frame hashes.
  Future<VideoFrameIndexCoverage> getVideoFrameIndexCoverage();

  /// Creates the five-frame lookup index for active-profile videos.
  Stream<DuplicateScanProgress> hashVideoFrames({
    DuplicateScanCancellation? cancellation,
  });

  /// Hashes [sources] and finds their closest matches in the active profile's
  /// currently indexed, currently hashed library visual media. Each query is
  /// compared only with candidates of the same media type.
  Future<ImageLookupBatch> findImageMatches({
    required List<ImageLookupSource> sources,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  });

  /// Re-runs matching for already-hashed [queries], such as after sensitivity
  /// changes, without decoding selected media or regenerating miniatures.
  Future<ImageLookupBatch> rematchImageQueries({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  });

  /// Clusters the cached hashes into duplicate groups at [sensitivity], choosing
  /// each group's keeper by [keeperStrategy] and dropping dismissed groups.
  /// Sorted by reclaimable bytes, largest first. Images without a cached hash
  /// (never scanned, or undecodable) are excluded.
  Future<List<DuplicateGroup>> loadGroups({
    required DuplicateSensitivity sensitivity,
    required KeeperStrategy keeperStrategy,
  });

  /// Remembers that the group with [signature] is not a real duplicate set, so
  /// it is filtered out of future [loadGroups] results until its membership
  /// changes.
  Future<void> dismissGroup(String signature);
}

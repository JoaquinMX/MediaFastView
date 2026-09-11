import '../../../../core/models/media_lookup_mode.dart';
import '../entities/duplicate_scan_progress.dart';
import '../entities/duplicate_sensitivity.dart';
import '../entities/image_lookup_batch.dart';
import '../entities/image_lookup_progress.dart';
import '../entities/image_lookup_query.dart';
import '../entities/image_lookup_source.dart';
import '../entities/image_lookup_update.dart';
import '../repositories/duplicate_repository.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';

/// Finds active-library matches for one or more external image/video queries.
class FindImageMatchesUseCase {
  const FindImageMatchesUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<ImageLookupBatch> call({
    required List<ImageLookupSource> sources,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
    DuplicateScanCancellation? cancellation,
    void Function(ImageLookupProgress progress)? onProgress,
    void Function(ImageLookupUpdate update)? onUpdate,
  }) {
    return _repository.findImageMatches(
      sources: sources,
      sensitivity: sensitivity,
      lookupMode: lookupMode,
      lookupPrecision: lookupPrecision,
      cancellation: cancellation,
      onProgress: onProgress,
      onUpdate: onUpdate,
    );
  }

  Future<ImageLookupBatch> rematch({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
    DuplicateScanCancellation? cancellation,
    void Function(ImageLookupProgress progress)? onProgress,
    void Function(ImageLookupUpdate update)? onUpdate,
  }) {
    return _repository.rematchImageQueries(
      queries: queries,
      sensitivity: sensitivity,
      lookupMode: lookupMode,
      lookupPrecision: lookupPrecision,
      cancellation: cancellation,
      onProgress: onProgress,
      onUpdate: onUpdate,
    );
  }
}

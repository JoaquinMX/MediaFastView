import '../../../../core/models/media_lookup_mode.dart';
import '../entities/duplicate_scan_progress.dart';
import '../entities/duplicate_sensitivity.dart';
import '../entities/image_lookup_batch.dart';
import '../entities/image_lookup_query.dart';
import '../entities/image_lookup_source.dart';
import '../repositories/duplicate_repository.dart';

/// Finds active-library matches for one or more external image/video queries.
class FindImageMatchesUseCase {
  const FindImageMatchesUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<ImageLookupBatch> call({
    required List<ImageLookupSource> sources,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) {
    return _repository.findImageMatches(
      sources: sources,
      sensitivity: sensitivity,
      lookupMode: lookupMode,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }

  Future<ImageLookupBatch> rematch({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) {
    return _repository.rematchImageQueries(
      queries: queries,
      sensitivity: sensitivity,
      lookupMode: lookupMode,
      cancellation: cancellation,
      onProgress: onProgress,
    );
  }
}

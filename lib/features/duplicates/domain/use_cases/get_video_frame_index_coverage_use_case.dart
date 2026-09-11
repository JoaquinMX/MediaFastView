import '../entities/video_frame_index_coverage.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';
import '../repositories/duplicate_repository.dart';

class GetVideoFrameIndexCoverageUseCase {
  const GetVideoFrameIndexCoverageUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<VideoFrameIndexCoverage> call({
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) {
    return _repository.getVideoFrameIndexCoverage(
      lookupPrecision: lookupPrecision,
    );
  }
}

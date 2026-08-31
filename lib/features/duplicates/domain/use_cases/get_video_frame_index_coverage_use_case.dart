import '../entities/video_frame_index_coverage.dart';
import '../repositories/duplicate_repository.dart';

class GetVideoFrameIndexCoverageUseCase {
  const GetVideoFrameIndexCoverageUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<VideoFrameIndexCoverage> call() {
    return _repository.getVideoFrameIndexCoverage();
  }
}

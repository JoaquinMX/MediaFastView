import '../entities/duplicate_scan_progress.dart';
import '../repositories/duplicate_repository.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';

class PrepareVideoFrameIndexUseCase {
  const PrepareVideoFrameIndexUseCase(this._repository);

  final DuplicateRepository _repository;

  Stream<DuplicateScanProgress> call({
    DuplicateScanCancellation? cancellation,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) {
    return _repository.hashVideoFrames(
      cancellation: cancellation,
      lookupPrecision: lookupPrecision,
    );
  }
}

import '../entities/duplicate_scan_progress.dart';
import '../repositories/duplicate_repository.dart';

class PrepareVideoFrameIndexUseCase {
  const PrepareVideoFrameIndexUseCase(this._repository);

  final DuplicateRepository _repository;

  Stream<DuplicateScanProgress> call({
    DuplicateScanCancellation? cancellation,
  }) {
    return _repository.hashVideoFrames(cancellation: cancellation);
  }
}

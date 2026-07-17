import '../entities/duplicate_scan_progress.dart';
import '../repositories/duplicate_repository.dart';

/// Runs the perceptual-hashing pass over the library, emitting progress.
class ScanForDuplicatesUseCase {
  const ScanForDuplicatesUseCase(this._repository);

  final DuplicateRepository _repository;

  Stream<DuplicateScanProgress> call({
    DuplicateScanCancellation? cancellation,
  }) {
    return _repository.hashLibrary(cancellation: cancellation);
  }
}

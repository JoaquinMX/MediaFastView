import '../../../media_library/domain/entities/media_entity.dart';
import '../entities/duplicate_library_coverage.dart';
import '../repositories/duplicate_repository.dart';

/// Reads perceptual-hash coverage for the active profile's indexed images.
class GetDuplicateLibraryCoverageUseCase {
  const GetDuplicateLibraryCoverageUseCase(this._repository);

  final DuplicateRepository _repository;

  Future<DuplicateLibraryCoverage> call({
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) {
    return _repository.getLibraryCoverage(mediaTypes: mediaTypes);
  }
}

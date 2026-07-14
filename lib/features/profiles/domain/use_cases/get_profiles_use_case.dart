import '../entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

class GetProfilesUseCase {
  const GetProfilesUseCase(this._repository);

  final ProfileRepository _repository;

  Future<List<ProfileEntity>> call() => _repository.getProfiles();
}

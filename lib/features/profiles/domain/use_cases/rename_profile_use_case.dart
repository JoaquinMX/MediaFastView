import 'package:collection/collection.dart';

import '../entities/profile_entity.dart';
import '../profile_validation.dart';
import '../repositories/profile_repository.dart';

class RenameProfileUseCase {
  const RenameProfileUseCase(this._repository);

  final ProfileRepository _repository;

  Future<ProfileEntity> call(String id, String name) async {
    validateProfileName(name);

    final existing = await _repository.getProfiles();
    final profile = existing.firstWhereOrNull((p) => p.id == id);
    if (profile == null) {
      throw ProfileValidationException('No profile with id $id');
    }

    // Excluding itself, so a case fix or a no-op save is not a self-collision.
    if (isProfileNameTaken(name, existing, excludingId: id)) {
      throw ProfileValidationException(
        'A profile named "${name.trim()}" already exists',
      );
    }

    final renamed = profile.copyWith(name: name.trim());
    await _repository.saveProfile(renamed);
    return renamed;
  }
}

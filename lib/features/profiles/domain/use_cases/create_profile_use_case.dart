import 'package:uuid/uuid.dart';

import '../entities/profile_entity.dart';
import '../profile_validation.dart';
import '../repositories/profile_repository.dart';

/// Creates a new, empty profile.
///
/// The profile starts with nothing: no directories, no tags, no favorites, no
/// filters. Folders are joined to it by adding them while it is active, or from
/// the directory's profile dialog.
class CreateProfileUseCase {
  const CreateProfileUseCase(this._repository, {Uuid uuid = const Uuid()})
      : _uuid = uuid;

  final ProfileRepository _repository;
  final Uuid _uuid;

  Future<ProfileEntity> call(String name) async {
    validateProfileName(name);

    final existing = await _repository.getProfiles();
    if (isProfileNameTaken(name, existing)) {
      throw ProfileValidationException(
        'A profile named "${name.trim()}" already exists',
      );
    }

    final profile = ProfileEntity(
      id: _uuid.v4(),
      name: name.trim(),
      sortOrder: existing.length,
      createdAt: DateTime.now(),
    );
    await _repository.saveProfile(profile);
    return profile;
  }
}

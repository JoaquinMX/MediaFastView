import '../entities/profile_entity.dart';

/// Access to the set of profiles.
abstract interface class ProfileRepository {
  /// Every profile, in switcher order.
  Future<List<ProfileEntity>> getProfiles();

  /// Creates or replaces [profile], keyed on its id.
  Future<void> saveProfile(ProfileEntity profile);

  /// Removes the profile row.
  ///
  /// Only the row. Unwinding what the profile owned is `DeleteProfileUseCase`'s
  /// job — it knows which directories to keep.
  Future<void> removeProfile(String id);
}

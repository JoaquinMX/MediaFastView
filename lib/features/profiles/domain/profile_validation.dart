import 'entities/profile_entity.dart';

/// Validation rules shared by profile creation and renaming.
///
/// Deliberately the same shape as the tag rules: uniqueness is enforced here
/// rather than by a unique index on the name, because a `replace: true` index
/// would make renaming a profile onto an existing name *delete* that profile
/// instead of failing.

/// Characters that would be awkward or unsafe in a profile name.
final RegExp _invalidProfileNameChars = RegExp(r'[<>"/\\|?*\x00-\x1f]');

/// Bounds on the length of a trimmed profile name.
const int minProfileNameLength = 2;
const int maxProfileNameLength = 50;

/// Throws [ProfileValidationException] unless [name] is a usable profile name.
///
/// Validates the *trimmed* name, since that is what gets persisted.
void validateProfileName(String name) {
  final trimmed = name.trim();

  if (trimmed.isEmpty) {
    throw const ProfileValidationException('Profile name cannot be empty');
  }

  if (trimmed.length < minProfileNameLength) {
    throw const ProfileValidationException(
      'Profile name must be at least $minProfileNameLength characters long',
    );
  }

  if (trimmed.length > maxProfileNameLength) {
    throw const ProfileValidationException(
      'Profile name cannot exceed $maxProfileNameLength characters',
    );
  }

  if (_invalidProfileNameChars.hasMatch(trimmed)) {
    throw const ProfileValidationException(
      'Profile name contains invalid characters',
    );
  }
}

/// Whether [name] is already taken by a profile other than [excludingId].
///
/// [excludingId] is what makes renaming work: without it, saving a profile whose
/// name has not really changed — a case fix like `work` → `Work` — collides with
/// its own row and is rejected as a duplicate.
bool isProfileNameTaken(
  String name,
  Iterable<ProfileEntity> profiles, {
  String? excludingId,
}) {
  final trimmed = name.trim().toLowerCase();
  return profiles
      .where((profile) => profile.id != excludingId)
      .any((profile) => profile.name.toLowerCase() == trimmed);
}

/// Thrown when a profile fails validation.
class ProfileValidationException implements Exception {
  const ProfileValidationException(this.message);

  final String message;

  @override
  String toString() => 'ProfileValidationException: $message';
}

import 'entities/tag_entity.dart';

/// Validation rules shared by tag creation and tag editing.
///
/// Extracted so that renaming a tag is held to exactly the same rules as
/// creating one — two copies would inevitably drift.

/// Characters that would be awkward or unsafe in a tag name.
final RegExp _invalidTagNameChars = RegExp(r'[<>"/\\|?*\x00-\x1f]');

/// Bounds on the length of a trimmed tag name.
const int minTagNameLength = 2;
const int maxTagNameLength = 50;

/// Throws [TagValidationException] unless [name] is a usable tag name.
///
/// Validates the *trimmed* name, since that is what gets persisted.
void validateTagName(String name) {
  final trimmed = name.trim();

  if (trimmed.isEmpty) {
    throw const TagValidationException('Tag name cannot be empty');
  }

  if (trimmed.length < minTagNameLength) {
    throw const TagValidationException(
      'Tag name must be at least $minTagNameLength characters long',
    );
  }

  if (trimmed.length > maxTagNameLength) {
    throw const TagValidationException(
      'Tag name cannot exceed $maxTagNameLength characters',
    );
  }

  if (_invalidTagNameChars.hasMatch(trimmed)) {
    throw const TagValidationException('Tag name contains invalid characters');
  }
}

/// Throws [TagValidationException] unless [color] is a valid packed ARGB value.
void validateTagColor(int color) {
  if (color < 0 || color > 0xFFFFFFFF) {
    throw const TagValidationException('Invalid color value');
  }
}

/// Whether [name] is already taken by a tag other than [excludingId].
///
/// [excludingId] is what makes editing work. Without it, saving a tag whose name
/// has not changed — a colour-only edit, or a case fix like `beach` → `Beach` —
/// collides with the tag's own row and is rejected as a duplicate.
bool isTagNameTaken(
  String name,
  Iterable<TagEntity> tags, {
  String? excludingId,
}) {
  final trimmed = name.trim().toLowerCase();
  return tags
      .where((tag) => tag.id != excludingId)
      .any((tag) => tag.name.toLowerCase() == trimmed);
}

/// Thrown when a tag fails validation.
class TagValidationException implements Exception {
  const TagValidationException(this.message);

  final String message;

  @override
  String toString() => 'TagValidationException: $message';
}

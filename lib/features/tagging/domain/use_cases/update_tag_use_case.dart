import '../entities/tag_entity.dart';
import '../repositories/tag_repository.dart';
import '../tag_validation.dart';

/// Use case for renaming a tag and changing its colour.
///
/// A tag's id is opaque and never derived from its name, and media and
/// directories reference tags by id — so an edit rewrites exactly one tag row
/// and leaves every assignment intact.
class UpdateTagUseCase {
  const UpdateTagUseCase(this._tagRepository);

  final TagRepository _tagRepository;

  /// Applies [name] and [color] to [tag], validating first.
  ///
  /// Returns the updated tag. Throws [TagValidationException] if the name breaks
  /// the rules or is already taken by a *different* tag.
  Future<TagEntity> call({
    required TagEntity tag,
    required String name,
    required int color,
  }) async {
    validateTagName(name);
    validateTagColor(color);

    final trimmedName = name.trim();
    final existingTags = await _tagRepository.getTags();

    // Excluding the tag itself is what lets an edit that does not change the
    // name through at all — a colour-only save, or a case fix like
    // `beach` -> `Beach`, would otherwise collide with the tag's own row.
    final isTaken = isTagNameTaken(
      trimmedName,
      existingTags,
      excludingId: tag.id,
    );
    if (isTaken) {
      throw const TagValidationException('A tag with this name already exists');
    }

    // copyWith preserves id and createdAt, so the tag keeps its identity and
    // every media item stays tagged.
    final updatedTag = tag.copyWith(name: trimmedName, color: color);
    await _tagRepository.updateTag(updatedTag);

    return updatedTag;
  }
}

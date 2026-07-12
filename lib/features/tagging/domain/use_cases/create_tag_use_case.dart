import '../entities/tag_entity.dart';
import '../repositories/tag_repository.dart';
import '../tag_validation.dart';

// TagValidationException was declared in this file before the rules were shared
// with editing. Re-exported so its existing importers keep working.
export '../tag_validation.dart' show TagValidationException;

/// Use case for creating new tags.
/// Handles validation and creation logic for tag entities.
class CreateTagUseCase {
  const CreateTagUseCase(this._tagRepository);

  final TagRepository _tagRepository;

  /// Creates a new tag with validation.
  Future<TagEntity> createTag({
    required String name,
    required int color,
  }) async {
    validateTagName(name);
    validateTagColor(color);

    final trimmedName = name.trim();
    final existingTags = await _tagRepository.getTags();
    if (isTagNameTaken(trimmedName, existingTags)) {
      throw const TagValidationException('A tag with this name already exists');
    }

    final tag = TagEntity(
      id: _generateTagId(),
      name: trimmedName,
      color: color,
      createdAt: DateTime.now(),
    );

    await _tagRepository.createTag(tag);

    return tag;
  }

  /// Generates a unique ID for the tag.
  String _generateTagId() {
    // In a real app, you might use UUID or another ID generation strategy
    return 'tag_${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}';
  }

  /// Generates a random suffix for ID uniqueness.
  String _randomSuffix() {
    return (DateTime.now().microsecondsSinceEpoch % 1000).toString();
  }
}

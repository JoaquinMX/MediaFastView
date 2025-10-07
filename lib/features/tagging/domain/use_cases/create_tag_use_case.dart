import '../entities/tag_entity.dart';
import '../repositories/tag_repository.dart';

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
    // Validate inputs
    _validateTagName(name);
    _validateTagColor(color);

    // Check if tag name already exists
    final existingTags = await _tagRepository.getTags();
    final trimmedName = name.trim();
    final nameExists = existingTags.any(
      (tag) => tag.name.toLowerCase() == trimmedName.toLowerCase(),
    );

    if (nameExists) {
      throw TagValidationException('A tag with this name already exists');
    }

    // Create the tag entity
    final tag = TagEntity(
      id: _generateTagId(),
      name: trimmedName,
      color: color,
      createdAt: DateTime.now(),
    );

    // Save to repository
    await _tagRepository.createTag(tag);

    return tag;
  }

  /// Validates tag name according to business rules.
  void _validateTagName(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      throw TagValidationException('Tag name cannot be empty');
    }

    if (trimmed.length < 2) {
      throw TagValidationException(
        'Tag name must be at least 2 characters long',
      );
    }

    if (trimmed.length > 50) {
      throw TagValidationException('Tag name cannot exceed 50 characters');
    }

    // Check for invalid characters (basic validation)
    final invalidChars = RegExp(r'[<>"/\\|?*\x00-\x1f]');
    if (invalidChars.hasMatch(trimmed)) {
      throw TagValidationException('Tag name contains invalid characters');
    }
  }

  /// Validates tag color.
  void _validateTagColor(int color) {
    // Basic validation - color should be a valid 32-bit color value
    if (color < 0 || color > 0xFFFFFFFF) {
      throw TagValidationException('Invalid color value');
    }
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

/// Exception thrown when tag validation fails.
class TagValidationException implements Exception {
  const TagValidationException(this.message);

  final String message;

  @override
  String toString() => 'TagValidationException: $message';
}

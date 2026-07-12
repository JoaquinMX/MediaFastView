import 'package:uuid/uuid.dart';

import '../entities/tag_entity.dart';
import '../repositories/tag_repository.dart';
import '../tag_validation.dart';

// TagValidationException was declared in this file before the rules were shared
// with editing. Re-exported so its existing importers keep working.
export '../tag_validation.dart' show TagValidationException;

/// Mints the id for a new tag. Injectable so tests can pin it.
typedef TagIdGenerator = String Function();

String _uuidV4() => const Uuid().v4();

/// Creates a tag, with validation.
///
/// The single creation path. `TagViewModel.createTag` used to build the entity
/// itself and skip every rule, so a duplicate or malformed name was rejected only
/// by the create dialog's form validator and by nothing else.
class CreateTagUseCase {
  const CreateTagUseCase(
    this._tagRepository, {
    TagIdGenerator generateId = _uuidV4,
  }) : _generateId = generateId;

  final TagRepository _tagRepository;
  final TagIdGenerator _generateId;

  /// Creates and persists a tag.
  ///
  /// Throws [TagValidationException] when the name breaks the rules or is
  /// already taken (case-insensitively).
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

    // A v4 uuid, matching every tag already in the database — the live creation
    // path has always used one. The timestamp-plus-`micros % 1000` scheme this
    // replaced was not random and could repeat within a millisecond.
    final tag = TagEntity(
      id: _generateId(),
      name: trimmedName,
      color: color,
      createdAt: DateTime.now(),
    );

    await _tagRepository.createTag(tag);

    return tag;
  }
}

import 'entities/saved_filter_entity.dart';
import 'tag_validation.dart';

/// Validation rules for saved filters.
///
/// Mirrors `tag_validation.dart`, and reuses [TagValidationException] so the
/// dialogs can surface every domain rejection the same way.

/// Characters that would be awkward in a filter name.
final RegExp _invalidNameChars = RegExp(r'[<>"/\\|?*\x00-\x1f]');

const int minSavedFilterNameLength = 2;
const int maxSavedFilterNameLength = 50;

/// Throws [TagValidationException] unless [name] is a usable filter name.
void validateSavedFilterName(String name) {
  final trimmed = name.trim();

  if (trimmed.isEmpty) {
    throw const TagValidationException('Filter name cannot be empty');
  }

  if (trimmed.length < minSavedFilterNameLength) {
    throw const TagValidationException(
      'Filter name must be at least $minSavedFilterNameLength characters long',
    );
  }

  if (trimmed.length > maxSavedFilterNameLength) {
    throw const TagValidationException(
      'Filter name cannot exceed $maxSavedFilterNameLength characters',
    );
  }

  if (_invalidNameChars.hasMatch(trimmed)) {
    throw const TagValidationException(
      'Filter name contains invalid characters',
    );
  }
}

/// Throws unless [definition] narrows something.
///
/// A filter with no tags and no directories selects everything — it is the
/// unfiltered view with a name on it, and saving it would only be confusing.
void validateSavedFilterDefinition(SavedFilterDefinition definition) {
  if (definition.isEmpty) {
    throw const TagValidationException(
      'Select at least one tag or directory before saving a filter',
    );
  }
}

/// Whether [name] is already taken by a filter other than [excludingId].
///
/// [excludingId] is what makes updating work. Without it, saving a filter under
/// the name it already has — which is exactly what "Update 'Trips 2024'" does —
/// would collide with the filter's own row and be rejected as a duplicate. The
/// same trap `UpdateTagUseCase` exists to avoid.
bool isSavedFilterNameTaken(
  String name,
  Iterable<SavedFilterEntity> filters, {
  String? excludingId,
}) {
  final trimmed = name.trim().toLowerCase();
  return filters
      .where((filter) => filter.id != excludingId)
      .any((filter) => filter.name.toLowerCase() == trimmed);
}

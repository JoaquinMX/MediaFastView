import 'package:uuid/uuid.dart';

import '../entities/saved_filter_entity.dart';
import '../repositories/saved_filter_repository.dart';
import '../saved_filter_validation.dart';
import '../tag_validation.dart';

/// Mints the id for a new saved filter. Injectable so tests can pin it.
typedef SavedFilterIdGenerator = String Function();

String _uuidV4() => const Uuid().v4();

/// Creates a new saved filter, or updates an existing one in place.
class SaveFilterUseCase {
  const SaveFilterUseCase(
    this._repository, {
    SavedFilterIdGenerator generateId = _uuidV4,
  }) : _generateId = generateId;

  final SavedFilterRepository _repository;
  final SavedFilterIdGenerator _generateId;

  /// Saves [definition] under [name].
  ///
  /// Pass [existingId] to update a filter in place — it keeps its id and
  /// `createdAt`, which is what "Update 'Trips 2024'" does. Omit it to create a
  /// new one.
  ///
  /// Throws [TagValidationException] when the name breaks the rules, is taken by
  /// a *different* filter, or the definition narrows nothing.
  Future<SavedFilterEntity> call({
    required String name,
    required SavedFilterDefinition definition,
    String? existingId,
  }) async {
    validateSavedFilterName(name);
    validateSavedFilterDefinition(definition);

    final trimmedName = name.trim();
    final filters = await _repository.getFilters();

    // Excluding the filter being updated is what lets it keep its own name.
    if (isSavedFilterNameTaken(
      trimmedName,
      filters,
      excludingId: existingId,
    )) {
      throw const TagValidationException(
        'A filter with this name already exists',
      );
    }

    final now = DateTime.now();
    final existing = existingId == null
        ? null
        : filters.where((filter) => filter.id == existingId).firstOrNull;

    final filter = SavedFilterEntity(
      id: existing?.id ?? _generateId(),
      name: trimmedName,
      definition: definition,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await _repository.saveFilter(filter);
    return filter;
  }
}

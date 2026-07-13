import '../../domain/entities/saved_filter_entity.dart';
import '../../domain/repositories/saved_filter_repository.dart';
import '../isar/isar_saved_filter_data_source.dart';
import '../models/saved_filter_model.dart';

class SavedFilterRepositoryImpl implements SavedFilterRepository {
  SavedFilterRepositoryImpl(this._dataSource);

  final IsarSavedFilterDataSource _dataSource;

  @override
  Future<List<SavedFilterEntity>> getFilters() async {
    final models = await _dataSource.getFilters();
    return models.map(_modelToEntity).toList(growable: false);
  }

  @override
  Future<SavedFilterEntity?> getFilterById(String id) async {
    final filters = await getFilters();
    return filters.where((filter) => filter.id == id).firstOrNull;
  }

  @override
  Future<void> saveFilter(SavedFilterEntity filter) {
    return _dataSource.saveFilter(_entityToModel(filter));
  }

  @override
  Future<void> deleteFilter(String id) => _dataSource.removeFilter(id);

  @override
  Future<void> rewriteTagId({
    required String sourceTagId,
    required String targetTagId,
  }) {
    return _rewriteTagIds(
      (tagIds) => tagIds.contains(sourceTagId)
          // Through a set, so a filter that already names the target does not
          // end up holding it twice.
          ? (tagIds.map((id) => id == sourceTagId ? targetTagId : id).toSet())
          : null,
    );
  }

  @override
  Future<void> removeTagId(String tagId) {
    return _rewriteTagIds(
      (tagIds) => tagIds.contains(tagId)
          ? (tagIds.where((id) => id != tagId).toSet())
          : null,
    );
  }

  /// Applies [rewrite] to each of the three tag lists of every saved filter, and
  /// re-persists only the filters it actually changed.
  ///
  /// [rewrite] returns `null` when a list is untouched, which is how a filter
  /// that never referenced the tag avoids a pointless write.
  Future<void> _rewriteTagIds(
    Set<String>? Function(Set<String> tagIds) rewrite,
  ) async {
    final filters = await getFilters();
    final updated = <SavedFilterModel>[];

    for (final filter in filters) {
      final definition = filter.definition;
      final required = rewrite(definition.requiredTagIds);
      final optional = rewrite(definition.optionalTagIds);
      final excluded = rewrite(definition.excludedTagIds);

      if (required == null && optional == null && excluded == null) {
        continue;
      }

      updated.add(
        _entityToModel(
          filter.copyWith(
            definition: definition.copyWith(
              requiredTagIds: required,
              optionalTagIds: optional,
              excludedTagIds: excluded,
            ),
            updatedAt: DateTime.now(),
          ),
        ),
      );
    }

    if (updated.isEmpty) {
      return;
    }
    await _dataSource.saveFilters(updated);
  }

  SavedFilterEntity _modelToEntity(SavedFilterModel model) {
    return SavedFilterEntity(
      id: model.id,
      name: model.name,
      definition: SavedFilterDefinition(
        requiredTagIds: model.requiredTagIds.toSet(),
        optionalTagIds: model.optionalTagIds.toSet(),
        excludedTagIds: model.excludedTagIds.toSet(),
        filterMode: model.filterMode,
        mediaTypeFilter: model.mediaTypeFilter,
        directoryPaths: model.directoryPaths.toSet(),
      ),
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  SavedFilterModel _entityToModel(SavedFilterEntity entity) {
    final definition = entity.definition;
    return SavedFilterModel(
      id: entity.id,
      name: entity.name,
      requiredTagIds: definition.requiredTagIds.toList(growable: false),
      optionalTagIds: definition.optionalTagIds.toList(growable: false),
      excludedTagIds: definition.excludedTagIds.toList(growable: false),
      filterMode: definition.filterMode,
      mediaTypeFilter: definition.mediaTypeFilter,
      directoryPaths: definition.directoryPaths.toList(growable: false),
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}

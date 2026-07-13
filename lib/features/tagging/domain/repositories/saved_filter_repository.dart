import '../entities/saved_filter_entity.dart';

/// Storage for named Tags-tab queries.
abstract interface class SavedFilterRepository {
  /// All saved filters, oldest first.
  Future<List<SavedFilterEntity>> getFilters();

  Future<SavedFilterEntity?> getFilterById(String id);

  /// Creates or replaces [filter], keyed on its id.
  Future<void> saveFilter(SavedFilterEntity filter);

  Future<void> deleteFilter(String id);

  /// Repoints every reference to [sourceTagId] at [targetTagId].
  ///
  /// A saved filter is a *third* holder of tag ids, alongside media and
  /// directories. When a tag is merged away, this is what stops a filter that
  /// required it from silently requiring nothing.
  Future<void> rewriteTagId({
    required String sourceTagId,
    required String targetTagId,
  });

  /// Strips [tagId] from every saved filter, for when a tag is deleted outright.
  Future<void> removeTagId(String tagId);
}

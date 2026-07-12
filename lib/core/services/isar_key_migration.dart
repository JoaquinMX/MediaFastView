import 'package:isar/isar.dart';

import '../../features/favorites/data/isar/favorite_collection.dart';
import '../../features/favorites/data/isar/isar_favorites_data_source.dart';
import '../../features/tagging/data/isar/isar_tag_data_source.dart';
import '../../features/tagging/data/isar/tag_collection.dart';
import 'logging_service.dart';

/// What a migration run did, so the caller can log it and tests can assert it.
class IsarKeyMigrationReport {
  const IsarKeyMigrationReport({
    required this.tagsRekeyed,
    required this.favoritesRekeyed,
  });

  static const none = IsarKeyMigrationReport(
    tagsRekeyed: 0,
    favoritesRekeyed: 0,
  );

  final int tagsRekeyed;
  final int favoritesRekeyed;

  bool get didAnything => tagsRekeyed > 0 || favoritesRekeyed > 0;

  @override
  String toString() =>
      'IsarKeyMigrationReport(tags: $tagsRekeyed, favorites: $favoritesRekeyed)';
}

/// Moves tag and favorite rows off the legacy Isar primary key onto the current
/// one.
///
/// Those two collections used to derive their `Id` by summing the bytes of a
/// SHA-256 digest, which collapses the key space to ~2,800 values and makes rows
/// silently overwrite one another. Fixing the derivation changes every existing
/// row's key: the rows stay on disk under their old ids, still reachable through
/// `getAll()` and the string indexes, but unreachable through `get(id)` — which
/// is exactly what the delete and lookup paths use. So they must be re-keyed.
///
/// The re-key itself is trivial because `set id` is a no-op on these
/// collections: the id is *computed* on read, so rows loaded by `getAll()`
/// already carry their new id. Clearing and re-putting them is enough.
///
/// Self-detecting and therefore idempotent — no version flag to get out of sync.
/// Rows already destroyed by a collision are gone; this preserves the survivors
/// and cannot resurrect the rest.
class IsarKeyMigration {
  const IsarKeyMigration();

  /// Runs against an open [isar], snapshotting the database via [backUp] if — and
  /// only if — something actually needs re-keying.
  Future<IsarKeyMigrationReport> run(
    Isar isar, {
    Future<void> Function()? backUp,
  }) {
    return runOnStores(
      tags: IsarTagCollectionStore.forIsar(isar),
      favorites: IsarFavoriteCollectionStore.forIsar(isar),
      backUp: backUp,
    );
  }

  /// The migration proper, against the store abstractions so it can be driven by
  /// in-memory fakes in tests.
  Future<IsarKeyMigrationReport> runOnStores({
    required TagCollectionStore tags,
    required FavoriteCollectionStore favorites,
    Future<void> Function()? backUp,
  }) async {
    final tagRows = await _legacyRows(
      await tags.getAll(),
      (row) => tags.getById(row.id),
    );
    final favoriteRows = await _legacyRows(
      await favorites.getAll(),
      (row) => favorites.getById(row.id),
    );

    if (tagRows.isEmpty && favoriteRows.isEmpty) {
      return IsarKeyMigrationReport.none;
    }

    // Snapshot before the first mutation, never on a launch that has nothing to
    // do — otherwise every start would leave a backup behind.
    await backUp?.call();

    final tagCount = await _rekeyTags(tags, tagRows);
    final favoriteCount = await _rekeyFavorites(favorites, favoriteRows);

    final report = IsarKeyMigrationReport(
      tagsRekeyed: tagCount,
      favoritesRekeyed: favoriteCount,
    );
    LoggingService.instance.warning(
      'Re-keyed legacy Isar rows after the primary-key fix: $report. '
      'Rows already destroyed by a key collision cannot be recovered.',
    );
    return report;
  }

  Future<int> _rekeyTags(
    TagCollectionStore store,
    List<TagCollection> rows,
  ) async {
    if (rows.isEmpty) {
      return 0;
    }

    // Two legacy rows can no longer land on one new id (63 bits, versus the
    // ~2,800 the old scheme reached), but dedupe on the natural key anyway so a
    // putAll can never silently drop one.
    final unique = <String, TagCollection>{
      for (final row in rows) row.tagId: row,
    };

    await store.writeTxn(() async {
      await store.clear();
      await store.putAll(unique.values.toList(growable: false));
    });
    return unique.length;
  }

  Future<int> _rekeyFavorites(
    FavoriteCollectionStore store,
    List<FavoriteCollection> rows,
  ) async {
    if (rows.isEmpty) {
      return 0;
    }

    final unique = <String, FavoriteCollection>{
      for (final row in rows) favoriteKey(row.itemId, row.itemType): row,
    };

    await store.writeTxn(() async {
      await store.clear();
      await store.putAll(unique.values.toList(growable: false));
    });
    return unique.length;
  }

  /// The rows that are stored under keys other than the ones they now compute.
  ///
  /// A row written under the current scheme resolves at its own id; one written
  /// under the legacy scheme does not, because the id is derived afresh on read
  /// (`set id` is a no-op). Self-detecting, so the migration is idempotent and
  /// needs no version flag to keep in sync.
  Future<List<T>> _legacyRows<T>(
    List<T> rows,
    Future<T?> Function(T row) getById,
  ) async {
    if (rows.isEmpty) {
      return const [];
    }

    final resolved = await Future.wait(rows.map(getById));
    final anyStale = resolved.any((row) => row == null);
    return anyStale ? rows : const [];
  }

}

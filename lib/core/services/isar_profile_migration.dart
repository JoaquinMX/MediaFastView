import 'package:isar/isar.dart';
import 'package:uuid/uuid.dart';

import '../../features/favorites/data/isar/favorite_collection.dart';
import '../../features/favorites/data/isar/isar_favorites_data_source.dart';
import '../../features/media_library/data/isar/directory_collection.dart';
import '../../features/media_library/data/isar/isar_directory_data_source.dart';
import '../../features/profiles/data/isar/isar_profile_data_source.dart';
import '../../features/profiles/data/isar/profile_collection.dart';
import '../../features/tagging/data/isar/isar_saved_filter_data_source.dart';
import '../../features/tagging/data/isar/isar_tag_data_source.dart';
import '../../features/tagging/data/isar/saved_filter_collection.dart';
import '../../features/tagging/data/isar/tag_collection.dart';
import 'logging_service.dart';

/// The name given to the profile that adopts a pre-profiles library.
const String defaultProfileName = 'Default';

/// What a migration run did, so the caller can log it and tests can assert it.
class IsarProfileMigrationReport {
  const IsarProfileMigrationReport({
    required this.profileId,
    required this.directoriesStamped,
    required this.tagsStamped,
    required this.favoritesStamped,
    required this.filtersStamped,
  });

  static const none = IsarProfileMigrationReport(
    profileId: null,
    directoriesStamped: 0,
    tagsStamped: 0,
    favoritesStamped: 0,
    filtersStamped: 0,
  );

  /// The profile the orphaned rows were adopted into, or null if nothing ran.
  final String? profileId;

  final int directoriesStamped;
  final int tagsStamped;
  final int favoritesStamped;
  final int filtersStamped;

  bool get didAnything => profileId != null;

  @override
  String toString() => 'IsarProfileMigrationReport(profile: $profileId, '
      'directories: $directoriesStamped, tags: $tagsStamped, '
      'favorites: $favoritesStamped, filters: $filtersStamped)';
}

/// Adopts a pre-profiles library into a single "Default" profile.
///
/// Before profiles existed there was one implicit library: every directory, tag,
/// favorite and saved filter was global. Those rows deserialize with an empty
/// profile — Isar defaults a newly added `String` to `''` and a `List<String>`
/// to `[]` — which is exactly what this detects. It mints one profile and stamps
/// them into it, so an upgrading user sees the library they had, unchanged,
/// under a profile they did not have to create.
///
/// Favorites are the only collection that has to be re-keyed: the profile is part
/// of their natural key (their `itemId` is content-derived, so two profiles can
/// favorite the same media and would otherwise collide on one id). The re-key is
/// cheap because `set id` is a no-op — a row loaded by `getAll()` already carries
/// its new id, so clearing and re-putting is enough. Directories, tags and
/// filters keep their ids and take a plain `put`.
///
/// Self-detecting and therefore idempotent — no version flag to get out of sync.
class IsarProfileMigration {
  const IsarProfileMigration({Uuid uuid = const Uuid()}) : _uuid = uuid;

  final Uuid _uuid;

  /// Runs against an open [isar], snapshotting the database via [backUp] if — and
  /// only if — something actually needs adopting.
  Future<IsarProfileMigrationReport> run(
    Isar isar, {
    Future<void> Function()? backUp,
  }) {
    return runOnStores(
      profiles: IsarProfileCollectionStore.forIsar(isar),
      directories: IsarDirectoryCollectionStore.forIsar(isar),
      tags: IsarTagCollectionStore.forIsar(isar),
      favorites: IsarFavoriteCollectionStore.forIsar(isar),
      filters: IsarSavedFilterCollectionStore.forIsar(isar),
      backUp: backUp,
    );
  }

  /// The migration proper, against the store abstractions so it can be driven by
  /// in-memory fakes in tests.
  Future<IsarProfileMigrationReport> runOnStores({
    required ProfileCollectionStore profiles,
    required DirectoryCollectionStore directories,
    required TagCollectionStore tags,
    required FavoriteCollectionStore favorites,
    required SavedFilterCollectionStore filters,
    Future<void> Function()? backUp,
  }) async {
    final directoryRows = await directories.getAll();
    final tagRows = await tags.getAll();
    final favoriteRows = await favorites.getAll();
    final filterRows = await filters.getAll();

    final orphanedDirectories =
        directoryRows.where((row) => row.profileIds.isEmpty).toList();
    final orphanedTags = tagRows.where((row) => row.profileId.isEmpty).toList();
    final orphanedFavorites =
        favoriteRows.where((row) => row.profileId.isEmpty).toList();
    final orphanedFilters =
        filterRows.where((row) => row.profileId.isEmpty).toList();

    final hasOrphans = orphanedDirectories.isNotEmpty ||
        orphanedTags.isNotEmpty ||
        orphanedFavorites.isNotEmpty ||
        orphanedFilters.isNotEmpty;

    if (!hasOrphans) {
      return IsarProfileMigrationReport.none;
    }

    // Snapshot before the first mutation, never on a launch that has nothing to
    // do — otherwise every start would leave a backup behind.
    await backUp?.call();

    // Adopt into the existing profile when there is exactly one, so a database
    // that was partially stamped by an interrupted run finishes into the same
    // profile rather than growing a second "Default".
    final existing = await profiles.getAll();
    final profileId = existing.length == 1
        ? existing.single.profileId
        : await _createDefaultProfile(profiles, existingCount: existing.length);

    await _stampDirectories(directories, orphanedDirectories, profileId);
    await _stampTags(tags, orphanedTags, profileId);
    await _stampFilters(filters, orphanedFilters, profileId);
    await _rekeyFavorites(favorites, favoriteRows, orphanedFavorites, profileId);

    final report = IsarProfileMigrationReport(
      profileId: profileId,
      directoriesStamped: orphanedDirectories.length,
      tagsStamped: orphanedTags.length,
      favoritesStamped: orphanedFavorites.length,
      filtersStamped: orphanedFilters.length,
    );
    LoggingService.instance.info(
      'Adopted the pre-profiles library into a profile: $report',
    );
    return report;
  }

  Future<String> _createDefaultProfile(
    ProfileCollectionStore profiles, {
    required int existingCount,
  }) async {
    final profile = ProfileCollection(
      profileId: _uuid.v4(),
      name: defaultProfileName,
      sortOrder: existingCount,
      createdAt: DateTime.now(),
    );
    await profiles.writeTxn(() => profiles.put(profile));
    return profile.profileId;
  }

  Future<void> _stampDirectories(
    DirectoryCollectionStore store,
    List<DirectoryCollection> rows,
    String profileId,
  ) async {
    if (rows.isEmpty) {
      return;
    }
    for (final row in rows) {
      row.profileIds = <String>[profileId];
    }
    await store.writeTxn(() => store.putAll(rows));
  }

  Future<void> _stampTags(
    TagCollectionStore store,
    List<TagCollection> rows,
    String profileId,
  ) async {
    if (rows.isEmpty) {
      return;
    }
    for (final row in rows) {
      row.profileId = profileId;
    }
    await store.writeTxn(() => store.putAll(rows));
  }

  Future<void> _stampFilters(
    SavedFilterCollectionStore store,
    List<SavedFilterCollection> rows,
    String profileId,
  ) async {
    if (rows.isEmpty) {
      return;
    }
    for (final row in rows) {
      row.profileId = profileId;
    }
    await store.writeTxn(() => store.putAll(rows));
  }

  /// Stamps the orphaned favorites and moves every row onto its current key.
  ///
  /// A plain `put` is not enough here: the profile is part of a favorite's
  /// natural key, so a stamped row computes an id different from the one it is
  /// stored under, and re-putting it would leave the old row behind under the old
  /// key. Nor can the stale ids simply be computed — what a row was stored under
  /// depends on which key scheme wrote it, and this must not care.
  ///
  /// So it clears the collection and re-inserts every row from [all], stamping
  /// the orphans on the way through. `set id` is a no-op, so rows loaded by
  /// `getAll()` already carry the id they should be stored under. Rows that
  /// already belong to a profile are carried across untouched, which is what
  /// makes a re-run safe.
  Future<void> _rekeyFavorites(
    FavoriteCollectionStore store,
    List<FavoriteCollection> all,
    List<FavoriteCollection> orphaned,
    String profileId,
  ) async {
    if (orphaned.isEmpty) {
      return;
    }

    for (final row in orphaned) {
      row.profileId = profileId;
    }

    // Dedupe on the new key so a putAll can never silently drop one.
    final unique = <String, FavoriteCollection>{
      for (final row in all)
        favoriteKey(row.profileId, row.itemId, row.itemType): row,
    };

    await store.writeTxn(() async {
      await store.clear();
      await store.putAll(unique.values.toList(growable: false));
    });
  }
}

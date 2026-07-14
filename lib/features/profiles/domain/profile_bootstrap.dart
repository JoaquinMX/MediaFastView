import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/isar_database.dart';
import '../../../core/services/isar_profile_migration.dart';
import '../data/active_profile_store.dart';
import '../data/isar/isar_profile_data_source.dart';
import '../data/models/profile_model.dart';

/// Decides which profile the app opens with, before the first frame.
///
/// Runs ahead of the widget tree so `activeProfileIdProvider` can be a plain
/// non-null `String`: every scoped provider reads it synchronously, and making
/// it async would push an `AsyncValue` into all of them for a value that is known
/// by the time anything renders.
///
/// One rule covers every case the stored id can be in — absent (fresh install),
/// naming a profile that the migration just created, or naming one that has since
/// been deleted: fall back to the first profile in switcher order.
class ProfileBootstrap {
  ProfileBootstrap({
    required IsarDatabase database,
    IsarProfileDataSource? profiles,
    ActiveProfileStore store = const ActiveProfileStore(),
    Uuid uuid = const Uuid(),
  })  : _database = database,
        _profiles = profiles ?? IsarProfileDataSource(database),
        _store = store,
        _uuid = uuid;

  final IsarDatabase _database;
  final IsarProfileDataSource _profiles;
  final ActiveProfileStore _store;
  final Uuid _uuid;

  /// Opens the database — which runs the migrations — and resolves the profile.
  Future<String> resolve() async {
    await _database.open();

    final profiles = await _ensureAtLeastOneProfile();
    final stored = await _store.read();

    // `getProfiles` is sorted by switcher order, so `first` is a stable choice.
    final resolved =
        profiles.firstWhereOrNull((profile) => profile.id == stored) ??
            profiles.first;

    if (resolved.id != stored) {
      await _store.write(resolved.id);
    }
    return resolved.id;
  }

  /// The profiles on disk, creating a default one if there are none.
  ///
  /// Only reachable on a genuinely fresh install: an upgrading user has rows to
  /// adopt, so [IsarProfileMigration] has already minted a profile for them.
  Future<List<ProfileModel>> _ensureAtLeastOneProfile() async {
    final existing = await _profiles.getProfiles();
    if (existing.isNotEmpty) {
      return existing;
    }

    final profile = ProfileModel(
      id: _uuid.v4(),
      name: defaultProfileName,
      sortOrder: 0,
      createdAt: DateTime.now(),
    );
    await _profiles.saveProfile(profile);
    return <ProfileModel>[profile];
  }
}

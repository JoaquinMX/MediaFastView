import 'package:shared_preferences/shared_preferences.dart';

import '../../features/favorites/data/data_sources/shared_preferences_data_source.dart';
import '../../features/favorites/data/isar/isar_favorites_data_source.dart';
import '../../features/media_library/data/data_sources/shared_preferences_data_source.dart';
import '../../features/media_library/data/data_sources/local_media_data_source.dart';
import '../../features/media_library/data/isar/isar_directory_data_source.dart';
import '../../features/media_library/data/isar/isar_media_data_source.dart';
import '../../features/tagging/data/data_sources/shared_preferences_data_source.dart';
import '../../features/tagging/data/isar/isar_tag_data_source.dart';

/// Handles migrating persisted state from SharedPreferences to Isar.
///
/// The migration runs once and copies directories, media, tags, and favorites
/// into the new Isar-backed stores. Subsequent invocations are no-ops based on
/// the persisted completion flag stored alongside the legacy payloads.
class PersistenceMigrationService {
  PersistenceMigrationService({
    required SharedPreferences sharedPreferences,
    required SharedPreferencesDirectoryDataSource legacyDirectoryDataSource,
    required SharedPreferencesMediaDataSource legacyMediaDataSource,
    required SharedPreferencesTagDataSource legacyTagDataSource,
    required SharedPreferencesFavoritesDataSource legacyFavoritesDataSource,
    required IsarDirectoryDataSource isarDirectoryDataSource,
    required IsarMediaDataSource isarMediaDataSource,
    required IsarTagDataSource isarTagDataSource,
    required IsarFavoritesDataSource isarFavoritesDataSource,
  })  : _sharedPreferences = sharedPreferences,
        _legacyDirectoryDataSource = legacyDirectoryDataSource,
        _legacyMediaDataSource = legacyMediaDataSource,
        _legacyTagDataSource = legacyTagDataSource,
        _legacyFavoritesDataSource = legacyFavoritesDataSource,
        _isarDirectoryDataSource = isarDirectoryDataSource,
        _isarMediaDataSource = isarMediaDataSource,
        _isarTagDataSource = isarTagDataSource,
        _isarFavoritesDataSource = isarFavoritesDataSource;

  static const String migrationCompletedKey = 'persistence.isarMigrationComplete';

  final SharedPreferences _sharedPreferences;
  final SharedPreferencesDirectoryDataSource _legacyDirectoryDataSource;
  final SharedPreferencesMediaDataSource _legacyMediaDataSource;
  final SharedPreferencesTagDataSource _legacyTagDataSource;
  final SharedPreferencesFavoritesDataSource _legacyFavoritesDataSource;
  final IsarDirectoryDataSource _isarDirectoryDataSource;
  final IsarMediaDataSource _isarMediaDataSource;
  final IsarTagDataSource _isarTagDataSource;
  final IsarFavoritesDataSource _isarFavoritesDataSource;

  /// Returns whether the migration has already completed.
  bool get hasCompletedMigration =>
      _sharedPreferences.getBool(migrationCompletedKey) ?? false;

  /// Migrates persisted payloads from SharedPreferences into Isar.
  ///
  /// When migration has already completed the method short-circuits to avoid
  /// repeating work. Otherwise, legacy payloads are copied into their
  /// respective Isar collections and a completion flag is stored.
  Future<void> migrateToIsar() async {
    if (hasCompletedMigration) {
      return;
    }

    final directories = await _legacyDirectoryDataSource.getDirectories();
    if (directories.isNotEmpty) {
      await _isarDirectoryDataSource.saveDirectories(directories);
    }

    final media = await _legacyMediaDataSource.getMedia();
    if (media.isNotEmpty) {
      await _isarMediaDataSource.saveMedia(media);
    }

    final tags = await _legacyTagDataSource.getTags();
    if (tags.isNotEmpty) {
      await _isarTagDataSource.saveTags(tags);
    }

    final favorites = await _legacyFavoritesDataSource.getFavorites();
    if (favorites.isNotEmpty) {
      await _isarFavoritesDataSource.saveFavorites(favorites);
    }

    await _sharedPreferences.setBool(migrationCompletedKey, true);
  }
}

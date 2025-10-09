import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/favorites/data/data_sources/isar_favorites_data_source.dart';
import '../../../features/favorites/data/models/favorite_model.dart';
import '../../../features/media_library/data/data_sources/isar_directory_data_source.dart';
import '../../../features/media_library/data/data_sources/isar_media_data_source.dart';
import '../../../features/media_library/data/models/directory_model.dart';
import '../../../features/media_library/data/models/media_model.dart';
import '../../../features/tagging/data/data_sources/isar_tag_data_source.dart';
import '../../../features/media_library/data/models/tag_model.dart';

/// Handles one-off migrations from SharedPreferences to Isar.
class DatabaseMigrator {
  DatabaseMigrator({
    required SharedPreferences sharedPreferences,
    required IsarDirectoryDataSource directoryDataSource,
    required IsarMediaDataSource mediaDataSource,
    required IsarTagDataSource tagDataSource,
    required IsarFavoritesDataSource favoritesDataSource,
  })  : _sharedPreferences = sharedPreferences,
        _directoryDataSource = directoryDataSource,
        _mediaDataSource = mediaDataSource,
        _tagDataSource = tagDataSource,
        _favoritesDataSource = favoritesDataSource;

  static const int _targetVersion = 1;
  static const String _versionKey = 'database_schema_version';

  final SharedPreferences _sharedPreferences;
  final IsarDirectoryDataSource _directoryDataSource;
  final IsarMediaDataSource _mediaDataSource;
  final IsarTagDataSource _tagDataSource;
  final IsarFavoritesDataSource _favoritesDataSource;

  Future<void> migrateIfNeeded() async {
    final currentVersion = _sharedPreferences.getInt(_versionKey) ?? 0;
    if (currentVersion >= _targetVersion) {
      return;
    }

    final directoriesRaw = _sharedPreferences.getString('directories');
    final mediaRaw = _sharedPreferences.getString('media');
    final tagsRaw = _sharedPreferences.getString('tags');
    final favoritesRaw = _sharedPreferences.getString('favorites');

    if (directoriesRaw != null) {
      final directoryJson = jsonDecode(directoriesRaw) as List<dynamic>;
      final directories = directoryJson
          .map(
            (item) => DirectoryModel.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
      await _directoryDataSource.putAll(directories);
    }

    if (mediaRaw != null) {
      final mediaJson = jsonDecode(mediaRaw) as List<dynamic>;
      final media = mediaJson
          .map(
            (item) => MediaModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      await _mediaDataSource.upsertMedia(media);
    }

    if (tagsRaw != null) {
      final tagsJson = jsonDecode(tagsRaw) as List<dynamic>;
      for (final tag in tagsJson) {
        await _tagDataSource.addTag(
          TagModel.fromJson(tag as Map<String, dynamic>),
        );
      }
    }

    if (favoritesRaw != null) {
      final favoritesJson = jsonDecode(favoritesRaw) as List<dynamic>;
      for (final favorite in favoritesJson) {
        await _favoritesDataSource.addFavorite(
          FavoriteModel.fromJson(favorite as Map<String, dynamic>),
        );
      }
    }

    await _sharedPreferences.setInt(_versionKey, _targetVersion);
    await _sharedPreferences.remove('directories');
    await _sharedPreferences.remove('media');
    await _sharedPreferences.remove('tags');
    await _sharedPreferences.remove('favorites');
  }
}

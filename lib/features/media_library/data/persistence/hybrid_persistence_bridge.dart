import 'package:collection/collection.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_media_data_source.dart';

import '../../../../core/services/logging_service.dart';
import '../data_sources/shared_preferences_data_source.dart';
import '../isar/isar_directory_data_source.dart';
import '../isar/isar_media_data_source.dart';
import '../models/directory_model.dart';
import '../models/media_model.dart';

/// Coordinates persistence between the new Isar-backed data sources and the
/// legacy SharedPreferences stores so repositories can interact with a single
/// abstraction during the migration period.
class DirectoryPersistenceBridge {
  DirectoryPersistenceBridge({
    required IsarDirectoryDataSource isarDirectoryDataSource,
    required SharedPreferencesDirectoryDataSource legacyDirectoryDataSource,
    required IsarMediaDataSource isarMediaDataSource,
    required SharedPreferencesMediaDataSource legacyMediaDataSource,
  })  : _isarDirectoryDataSource = isarDirectoryDataSource,
        _legacyDirectoryDataSource = legacyDirectoryDataSource,
        _isarMediaDataSource = isarMediaDataSource,
        _legacyMediaDataSource = legacyMediaDataSource;

  final IsarDirectoryDataSource _isarDirectoryDataSource;
  final SharedPreferencesDirectoryDataSource _legacyDirectoryDataSource;
  final IsarMediaDataSource _isarMediaDataSource;
  final SharedPreferencesMediaDataSource _legacyMediaDataSource;

  /// Retrieves all directories using Isar as the primary source. When the Isar
  /// store has not been populated yet the bridge falls back to the legacy
  /// SharedPreferences payload and seeds Isar to keep downstream queries in
  /// sync.
  Future<List<DirectoryModel>> loadDirectories() async {
    final isarDirectories = await _isarDirectoryDataSource.getDirectories();
    if (isarDirectories.isNotEmpty) {
      return isarDirectories;
    }

    final legacyDirectories = await _legacyDirectoryDataSource.getDirectories();
    if (legacyDirectories.isNotEmpty) {
      LoggingService.instance.info(
        'Seeding ${legacyDirectories.length} directories from legacy storage into Isar.',
      );
      await _isarDirectoryDataSource.saveDirectories(legacyDirectories);
    }
    return legacyDirectories;
  }

  /// Persists [directory] ensuring both stores remain consistent.
  Future<void> addDirectory(DirectoryModel directory) async {
    await _isarDirectoryDataSource.addDirectory(directory);
    await _legacyDirectoryDataSource.addDirectory(directory);
  }

  /// Updates the stored representation of [directory] across both stores.
  Future<void> updateDirectory(DirectoryModel directory) async {
    await _isarDirectoryDataSource.updateDirectory(directory);
    await _legacyDirectoryDataSource.updateDirectory(directory);
  }

  /// Removes the directory identified by [directoryId] from both stores.
  Future<void> removeDirectory(String directoryId) async {
    await _isarDirectoryDataSource.removeDirectory(directoryId);
    await _legacyDirectoryDataSource.removeDirectory(directoryId);
  }

  /// Replaces every stored directory with [directories].
  Future<void> saveDirectories(List<DirectoryModel> directories) async {
    await _isarDirectoryDataSource.saveDirectories(directories);
    await _legacyDirectoryDataSource.saveDirectories(directories);
  }

  /// Clears the persisted directory information from both stores.
  Future<void> clear() async {
    await _isarDirectoryDataSource.clearDirectories();
    await _legacyDirectoryDataSource.clearDirectories();
  }

  /// Ensures references to a legacy directory identifier are re-written to the
  /// provided [stableDirectoryId].
  Future<void> migrateDirectoryId(
    String legacyDirectoryId,
    String stableDirectoryId,
  ) async {
    await _isarMediaDataSource.migrateDirectoryId(
      legacyDirectoryId,
      stableDirectoryId,
    );
    await _legacyMediaDataSource.migrateDirectoryId(
      legacyDirectoryId,
      stableDirectoryId,
    );
  }

  /// Replaces the directory record keyed by [legacyDirectoryId] with
  /// [replacement] across both stores.
  Future<void> replaceDirectoryId(
    String legacyDirectoryId,
    DirectoryModel replacement,
  ) async {
    await _isarDirectoryDataSource.removeDirectory(legacyDirectoryId);
    await _legacyDirectoryDataSource.removeDirectory(legacyDirectoryId);
    await addDirectory(replacement);
  }

  /// Returns the persisted directory identified by [directoryId] when available.
  Future<DirectoryModel?> getDirectoryById(String directoryId) async {
    final directories = await loadDirectories();
    return directories.firstWhereOrNull((dir) => dir.id == directoryId);
  }
}

/// Coordinates media persistence across Isar and SharedPreferences.
class MediaPersistenceBridge {
  MediaPersistenceBridge({
    required IsarMediaDataSource isarMediaDataSource,
    required SharedPreferencesMediaDataSource legacyMediaDataSource,
  })  : _isarMediaDataSource = isarMediaDataSource,
        _legacyMediaDataSource = legacyMediaDataSource;

  final IsarMediaDataSource _isarMediaDataSource;
  final SharedPreferencesMediaDataSource _legacyMediaDataSource;

  /// Retrieves all media entries preferring the Isar-backed store.
  Future<List<MediaModel>> loadAllMedia() async {
    final isarMedia = await _isarMediaDataSource.getMedia();
    if (isarMedia.isNotEmpty) {
      return isarMedia;
    }

    final legacyMedia = await _legacyMediaDataSource.getMedia();
    if (legacyMedia.isNotEmpty) {
      LoggingService.instance.info(
        'Seeding ${legacyMedia.length} media records from legacy storage into Isar.',
      );
      await _isarMediaDataSource.saveMedia(legacyMedia);
    }
    return legacyMedia;
  }

  /// Retrieves media stored for [directoryId], seeding Isar when the legacy
  /// store still contains the authoritative data.
  Future<List<MediaModel>> loadMediaForDirectory(String directoryId) async {
    final isarMedia = await _isarMediaDataSource.getMediaForDirectory(directoryId);
    if (isarMedia.isNotEmpty) {
      return isarMedia;
    }

    final legacyMedia = await _legacyMediaDataSource.getMediaForDirectory(directoryId);
    if (legacyMedia.isNotEmpty) {
      LoggingService.instance.info(
        'Seeding ${legacyMedia.length} media items for directory $directoryId into Isar.',
      );
      await _isarMediaDataSource.upsertMedia(legacyMedia);
    }
    return legacyMedia;
  }

  /// Persists [media] replacing the existing contents of both stores.
  Future<void> saveMedia(List<MediaModel> media) async {
    await _isarMediaDataSource.saveMedia(media);
    await _legacyMediaDataSource.saveMedia(media);
  }

  /// Upserts the provided [media] across both stores.
  Future<void> upsertMedia(List<MediaModel> media) async {
    await _isarMediaDataSource.upsertMedia(media);
    await _legacyMediaDataSource.upsertMedia(media);
  }

  /// Replaces the tags associated with [mediaId].
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    await _isarMediaDataSource.updateMediaTags(mediaId, tagIds);
    await _legacyMediaDataSource.updateMediaTags(mediaId, tagIds);
  }

  /// Removes all media entries for the specified [directoryId].
  Future<void> removeMediaForDirectory(String directoryId) async {
    await _isarMediaDataSource.removeMediaForDirectory(directoryId);
    await _legacyMediaDataSource.removeMediaForDirectory(directoryId);
  }

  /// Rewrites references from [legacyDirectoryId] to [stableDirectoryId].
  Future<void> migrateDirectoryId(
    String legacyDirectoryId,
    String stableDirectoryId,
  ) async {
    await _isarMediaDataSource.migrateDirectoryId(
      legacyDirectoryId,
      stableDirectoryId,
    );
    await _legacyMediaDataSource.migrateDirectoryId(
      legacyDirectoryId,
      stableDirectoryId,
    );
  }
}

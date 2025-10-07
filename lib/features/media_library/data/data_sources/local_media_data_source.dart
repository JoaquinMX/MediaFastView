import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/services/logging_service.dart';
import '../models/media_model.dart';

/// Data source for media operations using SharedPreferences.
class SharedPreferencesMediaDataSource {
  const SharedPreferencesMediaDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const String _mediaKey = 'media';

  /// Retrieves all media from storage.
  Future<List<MediaModel>> getMedia() async {
    final startTime = DateTime.now();
    try {
      final jsonString = _prefs.getString(_mediaKey);
      if (jsonString == null) {
        LoggingService.instance.info('No media stored in SharedPreferences');
        return [];
      }

      final decodeStart = DateTime.now();
      final jsonList = json.decode(jsonString) as List<dynamic>;
      final decodeTime = DateTime.now().difference(decodeStart);

      final mapStart = DateTime.now();
      final media = jsonList
          .map((json) => MediaModel.fromJson(json as Map<String, dynamic>))
          .toList();
      final mapTime = DateTime.now().difference(mapStart);

      final totalTime = DateTime.now().difference(startTime);
      LoggingService.instance.info('Loaded ${media.length} media items from SharedPreferences in ${totalTime.inMilliseconds}ms (decode: ${decodeTime.inMilliseconds}ms, map: ${mapTime.inMilliseconds}ms)');
      return media;
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime);
      LoggingService.instance.error('Failed to load media after ${totalTime.inMilliseconds}ms: $e');
      throw PersistenceError('Failed to load media: $e');
    }
  }

  /// Saves all media to storage.
  Future<void> saveMedia(List<MediaModel> media) async {
    try {
      final jsonList = media.map((item) => item.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs.setString(_mediaKey, jsonString);
    } catch (e) {
      throw PersistenceError('Failed to save media: $e');
    }
  }

  /// Upserts media entries, preserving existing items that aren't replaced.
  Future<void> upsertMedia(List<MediaModel> media) async {
    final existing = await getMedia();
    final existingMap = {for (final item in existing) item.id: item};

    for (final item in media) {
      existingMap[item.id] = item;
    }

    await saveMedia(existingMap.values.toList());
  }

  /// Retrieves media for a specific directory.
  Future<List<MediaModel>> getMediaForDirectory(String directoryId) async {
    LoggingService.instance.debug('getMediaForDirectory called with directoryId: $directoryId');
    final allMedia = await getMedia();
    LoggingService.instance.debug('allMedia has ${allMedia.length} items');
    final filtered = allMedia.where((media) => media.directoryId == directoryId).toList();
    LoggingService.instance.info('filtered media has ${filtered.length} items for directoryId: $directoryId');
    return filtered;
  }

  /// Adds media items.
  Future<void> addMedia(List<MediaModel> mediaItems) async {
    final allMedia = await getMedia();
    allMedia.addAll(mediaItems);
    await saveMedia(allMedia);
  }

  /// Updates media tags.
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    final allMedia = await getMedia();
    final index = allMedia.indexWhere((media) => media.id == mediaId);
    if (index != -1) {
      allMedia[index] = allMedia[index].copyWith(tagIds: tagIds);
      await saveMedia(allMedia);
    }
  }

  /// Removes media for a directory.
  Future<void> removeMediaForDirectory(String directoryId) async {
    final allMedia = await getMedia();
    allMedia.removeWhere((media) => media.directoryId == directoryId);
    await saveMedia(allMedia);
  }
}

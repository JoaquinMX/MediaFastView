import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/app_error.dart';
import '../../../media_library/data/models/tag_model.dart';

/// Data source for tag operations using SharedPreferences.
class SharedPreferencesTagDataSource {
  const SharedPreferencesTagDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const String _tagsKey = 'tags';

  /// Retrieves all tags from storage.
  Future<List<TagModel>> getTags() async {
    try {
      final jsonString = _prefs.getString(_tagsKey);
      if (jsonString == null) return [];

      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => TagModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw PersistenceError('Failed to load tags: $e');
    }
  }

  /// Saves all tags to storage.
  Future<void> saveTags(List<TagModel> tags) async {
    try {
      final jsonList = tags.map((tag) => tag.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs.setString(_tagsKey, jsonString);
    } catch (e) {
      throw PersistenceError('Failed to save tags: $e');
    }
  }

  /// Adds a tag.
  Future<void> addTag(TagModel tag) async {
    final tags = await getTags();
    tags.add(tag);
    await saveTags(tags);
  }

  /// Updates a tag.
  Future<void> updateTag(TagModel updatedTag) async {
    final tags = await getTags();
    final index = tags.indexWhere((tag) => tag.id == updatedTag.id);
    if (index != -1) {
      tags[index] = updatedTag;
      await saveTags(tags);
    }
  }

  /// Removes a tag by ID.
  Future<void> removeTag(String id) async {
    final tags = await getTags();
    tags.removeWhere((tag) => tag.id == id);
    await saveTags(tags);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/app_error.dart';
import '../models/directory_model.dart';

/// Data source for directory operations using SharedPreferences.
class SharedPreferencesDirectoryDataSource {
  const SharedPreferencesDirectoryDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const String _directoriesKey = 'directories';

  /// Retrieves all directories from storage.
  Future<List<DirectoryModel>> getDirectories() async {
    try {
      final jsonString = _prefs.getString(_directoriesKey);
      if (jsonString == null) return [];

      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => DirectoryModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw PersistenceError('Failed to load directories: $e');
    }
  }

  /// Saves all directories to storage.
  Future<void> saveDirectories(List<DirectoryModel> directories) async {
    try {
      final jsonList = directories.map((dir) => dir.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs.setString(_directoriesKey, jsonString);
    } catch (e) {
      throw PersistenceError('Failed to save directories: $e');
    }
  }

  /// Adds a single directory.
  Future<void> addDirectory(DirectoryModel directory) async {
    final directories = await getDirectories();
    directories.add(directory);
    await saveDirectories(directories);
  }

  /// Removes a directory by ID.
  Future<void> removeDirectory(String id) async {
    final directories = await getDirectories();
    directories.removeWhere((dir) => dir.id == id);
    await saveDirectories(directories);
  }

  /// Updates a directory.
  Future<void> updateDirectory(DirectoryModel updatedDirectory) async {
    final directories = await getDirectories();
    final index = directories.indexWhere(
      (dir) => dir.id == updatedDirectory.id,
    );
    if (index != -1) {
      directories[index] = updatedDirectory;
      await saveDirectories(directories);
    }
  }

  /// Clears all directories from storage.
  Future<void> clearDirectories() async {
    try {
      await _prefs.remove(_directoriesKey);
    } catch (e) {
      throw PersistenceError('Failed to clear directories: $e');
    }
  }
}

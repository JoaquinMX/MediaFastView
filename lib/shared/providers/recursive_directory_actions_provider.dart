import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls whether directory-level actions should cascade to contained media.
///
/// When enabled, tagging or favoriting a directory will also apply the action to
/// every media item inside that directory and its subdirectories.
final recursiveDirectoryActionsProvider =
    StateNotifierProvider<RecursiveDirectoryActionsNotifier, bool>((ref) {
  return RecursiveDirectoryActionsNotifier();
});

class RecursiveDirectoryActionsNotifier extends StateNotifier<bool> {
  RecursiveDirectoryActionsNotifier() : super(false) {
    _loadPreference();
  }

  static const _preferenceKey = 'recursive_directory_actions_enabled';

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_preferenceKey) ?? false;
  }

  Future<void> setRecursiveDirectoryActions(bool enabled) async {
    debugPrint(
      'RecursiveDirectoryActions: Updating preference from $state to $enabled',
    );
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, enabled);
  }
}

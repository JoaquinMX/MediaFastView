import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that controls whether the app should auto-navigate to sibling
/// directories without asking for confirmation when browsing in full-screen.
final autoNavigateSiblingDirectoriesProvider =
    StateNotifierProvider<AutoNavigateSiblingDirectoriesNotifier, bool>((ref) {
  return AutoNavigateSiblingDirectoriesNotifier();
});

/// Manages the persisted preference for automatically navigating between
/// sibling directories.
class AutoNavigateSiblingDirectoriesNotifier extends StateNotifier<bool> {
  AutoNavigateSiblingDirectoriesNotifier() : super(false) {
    _loadPreference();
  }

  static const _preferenceKey = 'auto_navigate_sibling_directories';

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_preferenceKey) ?? false;
  }

  Future<void> setAutoNavigateSiblingDirectories(bool enabled) async {
    debugPrint(
      'AutoNavigateSiblingDirectories: Updating preference from $state to $enabled',
    );
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, enabled);
  }
}

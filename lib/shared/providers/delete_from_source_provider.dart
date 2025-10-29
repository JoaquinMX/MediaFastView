import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that controls whether delete operations remove files from the
/// original source on disk.
final deleteFromSourceProvider =
    StateNotifierProvider<DeleteFromSourceNotifier, bool>((ref) {
  return DeleteFromSourceNotifier();
});

/// Manages the persisted preference for deleting files from their source.
class DeleteFromSourceNotifier extends StateNotifier<bool> {
  DeleteFromSourceNotifier() : super(false) {
    _loadPreference();
  }

  static const _preferenceKey = 'delete_from_source_enabled';

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_preferenceKey) ?? false;
  }

  Future<void> setDeleteFromSource(bool enabled) async {
    debugPrint(
      'DeleteFromSourceProvider: Updating preference from $state to $enabled',
    );
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_preferenceKey, enabled);
    debugPrint(
      'DeleteFromSourceProvider: Preference persisted with value $enabled',
    );
  }
}

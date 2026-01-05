import 'package:shared_preferences/shared_preferences.dart';

/// Persists and loads the ordered list of tag identifiers that should be
/// exposed as keyboard shortcuts.
class TagShortcutPreferences {
  TagShortcutPreferences({SharedPreferences? preferences})
      : _preferencesFuture =
            preferences != null ? Future.value(preferences) : SharedPreferences.getInstance();

  static const String _shortcutKey = 'tag_shortcut_ids';

  final Future<SharedPreferences> _preferencesFuture;

  /// Returns the stored tag identifiers in shortcut order (1-based externally).
  Future<List<String>> loadShortcutTagIds() async {
    final prefs = await _preferencesFuture;
    return prefs.getStringList(_shortcutKey) ?? const <String>[];
  }

  /// Saves the provided [tagIds] in shortcut order.
  Future<void> saveShortcutTagIds(List<String> tagIds) async {
    final prefs = await _preferencesFuture;
    await prefs.setStringList(_shortcutKey, tagIds);
  }
}

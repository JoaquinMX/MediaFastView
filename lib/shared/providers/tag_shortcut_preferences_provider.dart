import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/tag_shortcut_preferences.dart';

/// Provides access to persisted tag shortcut configuration.
final tagShortcutPreferencesProvider =
    Provider<TagShortcutPreferences>((ref) => TagShortcutPreferences());

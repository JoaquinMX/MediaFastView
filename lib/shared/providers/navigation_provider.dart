import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tabs of [MainNavigation], in the order they appear in its `IndexedStack`
/// and `BottomNavigationBar`.
enum AppTab { library, tags, settings }

/// The currently selected tab.
///
/// Held in a provider rather than in `_MainNavigationState` so that code outside
/// the navigation bar can move the user between tabs — a "go to directory"
/// action in the full-screen viewer has to land them on the Library tab, and it
/// runs from a route pushed on top of the whole shell.
final selectedTabProvider = StateProvider<AppTab>((ref) => AppTab.library);

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/presentation/screens/directory_grid_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/tagging/presentation/screens/tags_screen.dart';
import '../../features/tagging/presentation/view_models/tags_view_model.dart';
import '../providers/active_profile_provider.dart';
import '../providers/navigation_provider.dart';

/// Main navigation widget with bottom navigation bar.
class MainNavigation extends ConsumerWidget {
  const MainNavigation({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    // Listening rather than reacting inside the tap handler, so the Tags tab
    // still refreshes when something moves the user here programmatically —
    // "go to directory" switches tabs without anyone touching the bar.
    ref.listen<AppTab>(selectedTabProvider, (previous, next) {
      if (previous != next && next == AppTab.tags) {
        ref.read(tagsViewModelProvider.notifier).refreshTags();
      }
    });

    // Switching profiles rebuilds every scoped provider, and the view models
    // reload themselves when they are recreated. Reading the notifier here is
    // what guarantees the Tags one is actually *alive* to be recreated: it is
    // autoDispose, and if the user switches while sitting on the Library tab
    // nothing is listening to it, so it would only wake up — already scoped
    // correctly — on the next visit.
    ref.listen<String>(activeProfileIdProvider, (previous, next) {
      if (previous != next) {
        ref.read(tagsViewModelProvider.notifier).loadTags();
      }
    });

    return Scaffold(
      body: IndexedStack(
        index: selectedTab.index,
        children: const <Widget>[
          DirectoryGridScreen(),
          TagsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.label),
            label: 'Tags',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: selectedTab.index,
        onTap: (index) =>
            ref.read(selectedTabProvider.notifier).state = AppTab.values[index],
      ),
    );
  }
}

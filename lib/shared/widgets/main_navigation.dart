import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/presentation/screens/directory_grid_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/tagging/presentation/screens/tags_screen.dart';
import '../../features/tagging/presentation/view_models/tags_view_model.dart';

/// Main navigation widget with bottom navigation bar.
class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});

  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }

    if (index == 1) {
      ref.read(tagsViewModelProvider.notifier).refreshTags();
    }
  }
}

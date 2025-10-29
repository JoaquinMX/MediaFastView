import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../../../features/favorites/presentation/view_models/favorites_view_model.dart';
import '../../../../shared/providers/delete_from_source_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/providers/thumbnail_caching_provider.dart';
import '../../../../shared/providers/video_playback_settings_provider.dart';
import '../../../../shared/widgets/app_bar.dart';

/// Screen for displaying application settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);
    final isThumbnailCachingEnabled = ref.watch(thumbnailCachingProvider);
    final thumbnailCachingNotifier = ref.read(thumbnailCachingProvider.notifier);
    final playbackSettings = ref.watch(videoPlaybackSettingsProvider);
    final playbackSettingsNotifier =
        ref.read(videoPlaybackSettingsProvider.notifier);
    final deleteFromSourceEnabled = ref.watch(deleteFromSourceProvider);
    final deleteFromSourceNotifier =
        ref.read(deleteFromSourceProvider.notifier);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Appearance'),
          _buildThemeSetting(themeMode, themeNotifier),
          const Divider(),
          _buildSectionHeader('Playback'),
          _buildAutoplaySetting(
            playbackSettings.autoplayVideos,
            playbackSettingsNotifier,
          ),
          _buildLoopSetting(
            playbackSettings.loopVideos,
            playbackSettingsNotifier,
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          _buildThumbnailCachingSetting(
            isThumbnailCachingEnabled,
            thumbnailCachingNotifier,
          ),
          _buildDeleteFromSourceSetting(
            deleteFromSourceEnabled,
            deleteFromSourceNotifier,
          ),
          _buildClearCacheTile(context, ref),
          _buildClearFavoritesTile(context, ref),
          const Divider(),
          _buildSectionHeader('About'),
          _buildAboutTile(context),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildThemeSetting(ThemeMode themeMode, ThemeNotifier themeNotifier) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(_getThemeModeText(themeMode)),
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        onChanged: (ThemeMode? newMode) {
          if (newMode != null) {
            themeNotifier.setThemeMode(newMode);
          }
        },
        items: ThemeMode.values.map((ThemeMode mode) {
          return DropdownMenuItem<ThemeMode>(
            value: mode,
            child: Text(_getThemeModeText(mode)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThumbnailCachingSetting(bool isEnabled, ThumbnailCachingNotifier notifier) {
    return ListTile(
      title: const Text('Thumbnail Caching'),
      subtitle: const Text('Cache thumbnails for faster loading (uses more storage)'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          notifier.setThumbnailCaching(value);
        },
      ),
    );
  }

  Widget _buildDeleteFromSourceSetting(
    bool isEnabled,
    DeleteFromSourceNotifier notifier,
  ) {
    return ListTile(
      title: const Text('Delete From Source'),
      subtitle: const Text(
        'When enabled, delete operations remove the original files or directories '
        'from disk. When disabled, files remain on disk.',
      ),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          notifier.setDeleteFromSource(value);
        },
      ),
    );
  }

  Widget _buildAutoplaySetting(
    bool isEnabled,
    VideoPlaybackSettingsNotifier notifier,
  ) {
    return ListTile(
      title: const Text('Autoplay Videos'),
      subtitle: const Text('Automatically start playback when a video loads'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          notifier.setAutoplayVideos(value);
        },
      ),
    );
  }

  Widget _buildLoopSetting(
    bool isEnabled,
    VideoPlaybackSettingsNotifier notifier,
  ) {
    return ListTile(
      title: const Text('Loop Videos'),
      subtitle: const Text('Repeat videos automatically when they finish'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          notifier.setLoopVideos(value);
        },
      ),
    );
  }

  Widget _buildClearCacheTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Clear Directory Cache'),
      subtitle: const Text('Remove all stored directory data and bookmarks'),
      trailing: const Icon(Icons.delete_forever, color: Colors.red),
      onTap: () => _showClearCacheDialog(context, ref),
    );
  }

  Widget _buildClearFavoritesTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Clear All Favorites'),
      subtitle: const Text('Remove all favorited media items'),
      trailing: const Icon(Icons.favorite_border, color: Colors.red),
      onTap: () => _showClearFavoritesDialog(context, ref),
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      title: const Text('About Media Fast View'),
      subtitle: const Text('Version 1.0.0'),
      onTap: () => _showAboutDialog(context),
    );
  }

  void _showClearCacheDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Directory Cache'),
        content: const Text(
          'This will remove all stored directory data and bookmarks. '
          'You will need to re-add your directories after clearing the cache. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final directoryViewModel = ref.read(directoryViewModelProvider.notifier);
                await directoryViewModel.clearDirectories();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Directory cache cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear cache: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearFavoritesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Favorites'),
        content: const Text(
          'This will remove all favorited media items. '
          'You can re-favorite items after clearing. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final favoritesViewModel = ref.read(favoritesViewModelProvider.notifier);
                await favoritesViewModel.clearAllFavorites();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All favorites cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear favorites: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Media Fast View'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A fast and efficient media viewer for your local files.'),
            SizedBox(height: 8),
            Text('Built with Flutter and Riverpod.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'System',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }
}
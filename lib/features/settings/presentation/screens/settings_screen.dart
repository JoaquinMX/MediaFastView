import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../../../features/favorites/presentation/view_models/favorites_view_model.dart';
import '../../../../shared/providers/delete_from_source_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/providers/thumbnail_caching_provider.dart';
import '../../../../shared/providers/auto_navigate_sibling_directories_provider.dart';
import '../../../../shared/providers/slideshow_controls_hide_delay_provider.dart';
import '../../../../shared/providers/video_playback_settings_provider.dart';
import '../../../../shared/widgets/app_bar.dart';
import '../widgets/destructive_confirmation_dialog.dart';
import '../widgets/settings_switch_tile.dart';

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
    final autoNavigateSiblingDirectories =
        ref.watch(autoNavigateSiblingDirectoriesProvider);
    final autoNavigateSiblingDirectoriesNotifier =
        ref.read(autoNavigateSiblingDirectoriesProvider.notifier);
    final slideshowControlsHideDelay =
        ref.watch(slideshowControlsHideDelayProvider);
    final slideshowControlsHideDelayNotifier =
        ref.read(slideshowControlsHideDelayProvider.notifier);

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
          SettingsSwitchTile(
            title: 'Autoplay Videos',
            subtitle: 'Automatically start playback when a video loads',
            value: playbackSettings.autoplayVideos,
            onChanged: playbackSettingsNotifier.setAutoplayVideos,
          ),
          SettingsSwitchTile(
            title: 'Loop Videos',
            subtitle: 'Repeat videos automatically when they finish',
            value: playbackSettings.loopVideos,
            onChanged: playbackSettingsNotifier.setLoopVideos,
          ),
          _buildSlideshowControlsHideDelaySetting(
            slideshowControlsHideDelay,
            slideshowControlsHideDelayNotifier,
          ),
          const Divider(),
          _buildSectionHeader('Navigation'),
          SettingsSwitchTile(
            title: 'Auto-Navigate Sibling Directories',
            subtitle:
                'Skip confirmation prompts when moving between sibling directories in full-screen view.',
            value: autoNavigateSiblingDirectories,
            onChanged:
                autoNavigateSiblingDirectoriesNotifier.setAutoNavigateSiblingDirectories,
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          SettingsSwitchTile(
            title: 'Thumbnail Caching',
            subtitle:
                'Cache thumbnails for faster loading (uses more storage)',
            value: isThumbnailCachingEnabled,
            onChanged: thumbnailCachingNotifier.setThumbnailCaching,
          ),
          SettingsSwitchTile(
            title: 'Delete From Source',
            subtitle:
                'When enabled, delete operations remove the original files or directories from disk. When disabled, files remain on disk.',
            value: deleteFromSourceEnabled,
            onChanged: deleteFromSourceNotifier.setDeleteFromSource,
          ),
          _buildClearCacheTile(context, ref),
          _buildClearFavoritesTile(context, ref),
          _buildClearTagAssignmentsTile(context, ref),
          _buildClearTagsTile(context, ref),
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

  Widget _buildSlideshowControlsHideDelaySetting(
    Duration delay,
    SlideshowControlsHideDelayNotifier notifier,
  ) {
    final seconds = delay.inSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Slideshow controls auto-hide'),
          subtitle: Text(
            'Hide slideshow controls after $seconds second${seconds == 1 ? '' : 's'} '
            'of inactivity.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Slider(
            value: seconds
                .clamp(
                  slideshowControlsHideDelayMinSeconds,
                  slideshowControlsHideDelayMaxSeconds,
                )
                .toDouble(),
            min: slideshowControlsHideDelayMinSeconds.toDouble(),
            max: slideshowControlsHideDelayMaxSeconds.toDouble(),
            divisions: slideshowControlsHideDelayMaxSeconds -
                slideshowControlsHideDelayMinSeconds,
            label: '$seconds s',
            onChanged: (value) => notifier.setDelay(
              Duration(seconds: value.round()),
            ),
          ),
        ),
      ],
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

  Widget _buildClearTagAssignmentsTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Clear All Assigned Tags'),
      subtitle: const Text(
        'Remove tag assignments from all media and directories',
      ),
      trailing: const Icon(Icons.label_off, color: Colors.red),
      onTap: () => _showClearTagAssignmentsDialog(context, ref),
    );
  }

  Widget _buildClearTagsTile(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: const Text('Clear All Tags'),
      subtitle: const Text('Delete all tags and their assignments'),
      trailing: const Icon(Icons.delete_sweep, color: Colors.red),
      onTap: () => _showClearTagsDialog(context, ref),
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
    showDestructiveConfirmationDialog(
      context,
      title: 'Clear Directory Cache',
      content: 'This will remove all stored directory data and bookmarks. '
          'You will need to re-add your directories after clearing the cache. '
          'This action cannot be undone.',
      confirmLabel: 'Clear',
      successMessage: 'Directory cache cleared successfully',
      errorPrefix: 'Failed to clear cache',
      onConfirm: () async {
        final directoryViewModel = ref.read(directoryViewModelProvider.notifier);
        await directoryViewModel.clearDirectories();
      },
    );
  }

  void _showClearFavoritesDialog(BuildContext context, WidgetRef ref) {
    showDestructiveConfirmationDialog(
      context,
      title: 'Clear All Favorites',
      content: 'This will remove all favorited media items. '
          'You can re-favorite items after clearing. '
          'This action cannot be undone.',
      confirmLabel: 'Clear',
      successMessage: 'All favorites cleared successfully',
      errorPrefix: 'Failed to clear favorites',
      onConfirm: () async {
        final favoritesViewModel = ref.read(favoritesViewModelProvider.notifier);
        await favoritesViewModel.clearAllFavorites();
      },
    );
  }

  void _showClearTagAssignmentsDialog(BuildContext context, WidgetRef ref) {
    showDestructiveConfirmationDialog(
      context,
      title: 'Clear All Assigned Tags',
      content: 'This will remove tag assignments from all media items and '
          'directories while keeping your tags. This action cannot be undone.',
      confirmLabel: 'Clear',
      successMessage: 'All tag assignments cleared successfully',
      errorPrefix: 'Failed to clear tag assignments',
      onConfirm: () => ref.read(clearTagAssignmentsUseCaseProvider)(),
    );
  }

  void _showClearTagsDialog(BuildContext context, WidgetRef ref) {
    showDestructiveConfirmationDialog(
      context,
      title: 'Clear All Tags',
      content: 'This will delete all tags and remove their assignments from your '
          'library. This action cannot be undone.',
      confirmLabel: 'Clear',
      successMessage: 'All tags cleared successfully',
      errorPrefix: 'Failed to clear tags',
      onConfirm: () => ref.read(clearTagsUseCaseProvider)(),
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

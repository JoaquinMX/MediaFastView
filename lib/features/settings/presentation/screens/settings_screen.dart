import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_bar.dart';
import '../../domain/entities/app_settings.dart';
import '../view_models/settings_view_model.dart';

/// Screen for displaying application settings.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    return settingsState.when(
      data: (settings) => _buildLoadedState(
        context,
        viewModel,
        settings,
      ),
      loading: () => const Scaffold(
        appBar: CustomAppBar(
          title: 'Settings',
        ),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const CustomAppBar(
          title: 'Settings',
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load settings'),
              const SizedBox(height: 8),
              Text('$error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: viewModel.refreshSettings,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedState(
    BuildContext context,
    SettingsViewModel viewModel,
    AppSettings settings,
  ) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSectionHeader('Appearance'),
          _buildThemeSetting(settings.themeMode, viewModel),
          const Divider(),
          _buildSectionHeader('Playback'),
          _buildAutoplaySetting(
            settings.playbackSettings.autoplayVideos,
            viewModel,
          ),
          _buildLoopSetting(
            settings.playbackSettings.loopVideos,
            viewModel,
          ),
          _buildSlideshowControlsHideDelaySetting(
            settings.slideshowControlsHideDelay,
            viewModel,
          ),
          const Divider(),
          _buildSectionHeader('Navigation'),
          _buildSiblingNavigationSetting(
            settings.autoNavigateSiblingDirectories,
            viewModel,
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          _buildThumbnailCachingSetting(
            settings.thumbnailCachingEnabled,
            viewModel,
          ),
          _buildDeleteFromSourceSetting(
            settings.deleteFromSourceEnabled,
            viewModel,
          ),
          _buildClearMediaCacheTile(context, viewModel),
          _buildClearCacheTile(context, viewModel),
          _buildClearFavoritesTile(context, viewModel),
          _buildClearTagAssignmentsTile(context, viewModel),
          _buildClearTagsTile(context, viewModel),
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

  Widget _buildThemeSetting(ThemeMode themeMode, SettingsViewModel viewModel) {
    return ListTile(
      title: const Text('Theme'),
      subtitle: Text(_getThemeModeText(themeMode)),
      trailing: DropdownButton<ThemeMode>(
        value: themeMode,
        onChanged: (ThemeMode? newMode) {
          if (newMode != null) {
            viewModel.updateThemeMode(newMode);
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

  Widget _buildThumbnailCachingSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Thumbnail Caching'),
      subtitle: const Text('Cache thumbnails for faster loading (uses more storage)'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateThumbnailCaching(value);
        },
      ),
    );
  }

  Widget _buildDeleteFromSourceSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
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
          viewModel.updateDeleteFromSource(value);
        },
      ),
    );
  }

  Widget _buildAutoplaySetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Autoplay Videos'),
      subtitle: const Text('Automatically start playback when a video loads'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateAutoplayVideos(value);
        },
      ),
    );
  }

  Widget _buildLoopSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Loop Videos'),
      subtitle: const Text('Repeat videos automatically when they finish'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateLoopVideos(value);
        },
      ),
    );
  }

  Widget _buildSlideshowControlsHideDelaySetting(
    Duration delay,
    SettingsViewModel viewModel,
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
            onChanged: (value) => viewModel.updateSlideshowControlsHideDelay(
              Duration(seconds: value.round()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSiblingNavigationSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Auto-Navigate Sibling Directories'),
      subtitle: const Text(
        'Skip confirmation prompts when moving between sibling directories in full-screen view.',
      ),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateAutoNavigateSiblingDirectories(value);
        },
      ),
    );
  }

  Widget _buildClearMediaCacheTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Clean Cached Media'),
      subtitle: const Text(
        'Remove stored media entries so deleted files or directories stop '
        'appearing in tag filters.',
      ),
      trailing: const Icon(Icons.cleaning_services, color: Colors.red),
      onTap: () => _showClearMediaCacheDialog(context, viewModel),
    );
  }

  Widget _buildClearCacheTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Clear Directory Cache'),
      subtitle: const Text('Remove all stored directory data and bookmarks'),
      trailing: const Icon(Icons.delete_forever, color: Colors.red),
      onTap: () => _showClearCacheDialog(context, viewModel),
    );
  }

  Widget _buildClearFavoritesTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Clear All Favorites'),
      subtitle: const Text('Remove all favorited media items'),
      trailing: const Icon(Icons.favorite_border, color: Colors.red),
      onTap: () => _showClearFavoritesDialog(context, viewModel),
    );
  }

  Widget _buildClearTagAssignmentsTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Clear All Assigned Tags'),
      subtitle: const Text(
        'Remove tag assignments from all media and directories',
      ),
      trailing: const Icon(Icons.label_off, color: Colors.red),
      onTap: () => _showClearTagAssignmentsDialog(context, viewModel),
    );
  }

  Widget _buildClearTagsTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Clear All Tags'),
      subtitle: const Text('Delete all tags and their assignments'),
      trailing: const Icon(Icons.delete_sweep, color: Colors.red),
      onTap: () => _showClearTagsDialog(context, viewModel),
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      title: const Text('About Media Fast View'),
      subtitle: const Text('Version 1.0.0'),
      onTap: () => _showAboutDialog(context),
    );
  }

  void _showClearMediaCacheDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Cached Media'),
        content: const Text(
          'This will remove all cached media entries, including those from deleted '
          'directories. Media will be rebuilt from disk on the next scan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await viewModel.clearMediaCache();
              _showOperationResult(
                context,
                success,
                successMessage: 'Cached media cleaned successfully',
                failurePrefix: 'Failed to clean media cache',
              );
            },
            child: const Text('Clean', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
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
              final success = await viewModel.clearDirectoryCache();
              _showOperationResult(
                context,
                success,
                successMessage: 'Directory cache cleared successfully',
                failurePrefix: 'Failed to clear cache',
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearFavoritesDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
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
              final success = await viewModel.clearFavorites();
              _showOperationResult(
                context,
                success,
                successMessage: 'All favorites cleared successfully',
                failurePrefix: 'Failed to clear favorites',
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearTagAssignmentsDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Assigned Tags'),
        content: const Text(
          'This will remove tag assignments from all media items and '
          'directories while keeping your tags. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await viewModel.clearTagAssignments();
              _showOperationResult(
                context,
                success,
                successMessage: 'All tag assignments cleared successfully',
                failurePrefix: 'Failed to clear tag assignments',
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearTagsDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Tags'),
        content: const Text(
          'This will delete all tags and remove their assignments from your '
          'library. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await viewModel.clearTags();
              _showOperationResult(
                context,
                success,
                successMessage: 'All tags cleared successfully',
                failurePrefix: 'Failed to clear tags',
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showOperationResult(
    BuildContext context,
    bool success, {
    required String successMessage,
    required String failurePrefix,
  }) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? successMessage : '$failurePrefix.',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
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

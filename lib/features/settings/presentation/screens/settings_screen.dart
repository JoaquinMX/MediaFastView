import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_bar.dart';
import '../../../thumbnails/presentation/thumbnail_batch_controller.dart';
import '../../../thumbnails/presentation/thumbnail_batch_progress_dialog.dart';
import '../../../thumbnails/presentation/thumbnail_providers.dart';
import '../../../../core/utils/file_size_formatter.dart';
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
      data: (settings) => _buildLoadedState(context, ref, viewModel, settings),
      loading: () => const Scaffold(
        appBar: CustomAppBar(title: 'Settings'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: const CustomAppBar(title: 'Settings'),
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
    WidgetRef ref,
    SettingsViewModel viewModel,
    AppSettings settings,
  ) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings'),
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
          _buildLoopSetting(settings.playbackSettings.loopVideos, viewModel),
          _buildStartMutedSetting(
            settings.playbackSettings.startMuted,
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
          _buildShowDirectoryTaggedMediaCountsSetting(
            settings.showDirectoryTaggedMediaCounts,
            viewModel,
          ),
          const Divider(),
          _buildSectionHeader('Data Management'),
          _buildThumbnailDiskCacheSetting(
            settings.thumbnailDiskCacheEnabled,
            viewModel,
          ),
          _buildGenerateThumbnailsTile(
            context,
            ref,
            settings.thumbnailDiskCacheEnabled,
          ),
          _buildThumbnailCacheTile(context, ref),
          _buildDeleteFromSourceSetting(
            settings.deleteFromSourceEnabled,
            viewModel,
          ),
          _buildNavigateToSiblingAfterDirectoryDeleteSetting(
            settings.navigateToSiblingAfterDirectoryDelete,
            viewModel,
          ),
          if (Platform.isMacOS) ...[
            _buildExportSidecarsTile(context, viewModel),
            _buildImportSidecarsTile(context, viewModel),
          ],
          _buildRescanLibraryTile(context, viewModel),
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

  Widget _buildThumbnailDiskCacheSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Thumbnail Caching'),
      subtitle: const Text(
        'Keep generated image and video previews on disk for faster browsing. '
        'When disabled, previews are temporary and memory-only.',
      ),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateThumbnailDiskCache(value);
        },
      ),
    );
  }

  Widget _buildGenerateThumbnailsTile(
    BuildContext context,
    WidgetRef ref,
    bool cacheEnabled,
  ) {
    final progress = ref.watch(thumbnailBatchControllerProvider);
    return ListTile(
      enabled: cacheEnabled,
      title: const Text('Pre-generate Thumbnails'),
      subtitle: Text(
        !cacheEnabled
            ? 'Enable thumbnail caching to generate previews in advance.'
            : progress.isActive
            ? '${progress.completed} of ${progress.total} processed'
            : 'Generate image and video previews for the active library.',
      ),
      trailing: progress.isActive
          ? SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(value: progress.fraction),
            )
          : const Icon(Icons.photo_library_outlined),
      onTap: cacheEnabled
          ? () => _showGenerateThumbnailsDialog(context, ref)
          : null,
    );
  }

  Widget _buildThumbnailCacheTile(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(thumbnailCacheUsageProvider);
    return ListTile(
      title: const Text('Clear Thumbnail Cache'),
      subtitle: Text(
        usage.when(
          data: (bytes) => '${formatFileSize(bytes)} currently stored',
          loading: () => 'Calculating cache usage…',
          error: (_, __) => 'Cache usage unavailable',
        ),
      ),
      trailing: const Icon(Icons.delete_outline),
      onTap: () => _showClearThumbnailCacheDialog(context, ref),
    );
  }

  Future<void> _showGenerateThumbnailsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final controller = ref.read(thumbnailBatchControllerProvider.notifier);
    final current = ref.read(thumbnailBatchControllerProvider);
    if (!current.isActive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pre-generate Thumbnails'),
          content: const Text(
            'Generate standard-size previews for every image and video in the '
            'active library? Browsing remains available and visible thumbnails '
            'take priority. You can cancel at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Generate'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) {
        return;
      }
      unawaited(controller.start());
    }

    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ThumbnailBatchProgressDialog(),
    );
  }

  Future<void> _showClearThumbnailCacheDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Thumbnail Cache'),
        content: const Text(
          'Remove all generated image and video previews? Original media is not '
          'changed, and previews will be generated again as needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final cleared = await ref
        .read(thumbnailBatchControllerProvider.notifier)
        .clearCache();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cleared
              ? 'Thumbnail cache cleared.'
              : 'Could not clear the thumbnail cache while generation is active.',
        ),
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

  Widget _buildNavigateToSiblingAfterDirectoryDeleteSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Open Next Folder After Delete'),
      subtitle: const Text(
        'After deleting the folder you are viewing, open the next sibling '
        'folder (or the previous one) instead of going back. Falls back to '
        'going back when there are no sibling folders.',
      ),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateNavigateToSiblingAfterDirectoryDelete(value);
        },
      ),
    );
  }

  Widget _buildAutoplaySetting(bool isEnabled, SettingsViewModel viewModel) {
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

  Widget _buildLoopSetting(bool isEnabled, SettingsViewModel viewModel) {
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

  Widget _buildStartMutedSetting(bool isEnabled, SettingsViewModel viewModel) {
    return ListTile(
      title: const Text('Start Videos Muted'),
      subtitle: const Text('Mute videos by default when they begin playback'),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateStartMuted(value);
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
            divisions:
                slideshowControlsHideDelayMaxSeconds -
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

  Widget _buildShowDirectoryTaggedMediaCountsSetting(
    bool isEnabled,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Show Directory Tagged Media Counts'),
      subtitle: const Text(
        'Display tagged versus total media counts on directory cards.',
      ),
      trailing: Switch(
        value: isEnabled,
        onChanged: (bool value) {
          viewModel.updateShowDirectoryTaggedMediaCounts(value);
        },
      ),
    );
  }

  Widget _buildExportSidecarsTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Save Tags & Favorites to Disk'),
      subtitle: const Text(
        'Write a .mediafastview.json file into each tagged folder so your tags '
        'and favorites survive a cache clear and travel with the files.',
      ),
      trailing: const Icon(Icons.save_alt),
      onTap: () => _showExportSidecarsDialog(context, viewModel),
    );
  }

  Widget _buildImportSidecarsTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Load Tags & Favorites from Disk'),
      subtitle: const Text(
        'Read .mediafastview.json files from your library folders and merge '
        'their tags and favorites into the current profile.',
      ),
      trailing: const Icon(Icons.file_download_outlined),
      onTap: () => _showImportSidecarsDialog(context, viewModel),
    );
  }

  Widget _buildRescanLibraryTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Rescan Library'),
      subtitle: const Text(
        'Re-read every folder from disk to pick up files added, changed, or '
        'removed outside the app. Tags and favorites are kept for everything '
        'still present.',
      ),
      trailing: const Icon(Icons.refresh),
      onTap: () => _showRescanLibraryDialog(context, viewModel),
    );
  }

  Widget _buildClearMediaCacheTile(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return ListTile(
      title: const Text('Clean Cached Media'),
      subtitle: const Text(
        'Remove entries for files and folders that no longer exist on disk, so '
        'they stop appearing in tag filters. Tags and favorites are kept for '
        'everything still present.',
      ),
      trailing: const Icon(Icons.cleaning_services),
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

  Future<void> _showExportSidecarsDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Tags & Favorites to Disk'),
        content: const Text(
          'This writes a hidden .mediafastview.json file into each folder that '
          'has tagged or favorited items. It only overwrites Media Fast View\'s '
          'own manifests and never changes your media files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double?>(null);
    _showSidecarProgressDialog(context, 'Saving tags & favorites…', progress);

    final result = await viewModel.exportSidecars(
      onProgress: (done, total) {
        progress.value = total > 0 ? done / total : null;
      },
    );

    rootNavigator.pop();
    progress.dispose();
    _showSidecarSummary(
      messenger,
      result?.describe() ?? 'Failed to save tags & favorites.',
      isError: result == null || result.hasFailures,
    );
  }

  Future<void> _showImportSidecarsDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Tags & Favorites from Disk'),
        content: const Text(
          'This reads .mediafastview.json files from your library folders and '
          'merges their tags and favorites into the current profile. Existing '
          'tags are never deleted — only added to.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Load'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double?>(null);
    _showSidecarProgressDialog(context, 'Loading tags & favorites…', progress);

    final result = await viewModel.importSidecars(
      onProgress: (done, total) {
        progress.value = total > 0 ? done / total : null;
      },
    );

    rootNavigator.pop();
    progress.dispose();
    _showSidecarSummary(
      messenger,
      result?.describe() ?? 'Failed to load tags & favorites.',
      isError: result == null || result.hasFailures,
    );
  }

  void _showSidecarProgressDialog(
    BuildContext context,
    String label,
    ValueNotifier<double?> progress,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: ValueListenableBuilder<double?>(
                valueListenable: progress,
                builder: (context, value, _) =>
                    CircularProgressIndicator(value: value),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }

  void _showSidecarSummary(
    ScaffoldMessengerState messenger,
    String message, {
    required bool isError,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _showRescanLibraryDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rescan Library'),
        content: const Text(
          'This re-reads every folder in your library from disk. It can take a '
          'while on a large library, and nothing on disk is changed — your tags '
          'and favorites are kept for every file that is still there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final progress = ValueNotifier<double?>(null);
    _showSidecarProgressDialog(context, 'Rescanning library…', progress);

    final folders = await viewModel.rescanLibrary(
      onProgress: (done, total) {
        progress.value = total > 0 ? done / total : null;
      },
    );

    rootNavigator.pop();
    progress.dispose();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          folders == null
              ? 'Failed to rescan the library.'
              : 'Rescanned $folders '
                    '${folders == 1 ? 'folder' : 'folders'} from disk.',
        ),
        backgroundColor: folders == null ? Colors.red : Colors.green,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _showClearMediaCacheDialog(
    BuildContext context,
    SettingsViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Cached Media'),
        content: const Text(
          'This checks your library against disk and removes cached entries '
          'whose file or folder is gone. Anything still on disk keeps its tags '
          'and favorites, and nothing is deleted from disk.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clean'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final removed = await viewModel.clearMediaCache();

    final String message;
    if (removed == null) {
      message = 'Failed to clean media cache.';
    } else if (removed == 0) {
      message = 'Everything in the cache is still on disk — nothing to clean.';
    } else {
      message =
          'Removed $removed stale '
          '${removed == 1 ? 'entry' : 'entries'} for files no longer on disk.';
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: removed == null ? Colors.red : Colors.green,
        duration: const Duration(seconds: 5),
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

  void _showClearTagsDialog(BuildContext context, SettingsViewModel viewModel) {
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
        content: Text(success ? successMessage : '$failurePrefix.'),
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

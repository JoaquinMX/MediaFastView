import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/widgets/permission_issue_panel.dart';

import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../full_screen/presentation/models/full_screen_exit_result.dart';
import '../../../tagging/presentation/widgets/bulk_tag_assignment_dialog.dart';
import '../../../tagging/presentation/widgets/tag_management_dialog.dart';
import '../../domain/entities/media_entity.dart';
import '../controllers/media_marquee_controller.dart';
import '../controllers/media_navigation_handler.dart';
import '../models/directory_navigation_target.dart';
import '../view_models/media_grid_view_model.dart';
import '../widgets/media_filter_bar.dart';
import '../widgets/column_selector_popup.dart';
import '../widgets/media_grid_view.dart';

/// Screen for displaying media in a customizable grid layout.
class MediaGridScreen extends ConsumerStatefulWidget {
  const MediaGridScreen({
    super.key,
    required this.directoryPath,
    required this.directoryName,
    this.bookmarkData,
    this.siblingDirectories,
    this.currentDirectoryIndex,
  });

  final String directoryPath;
  final String directoryName;
  final String? bookmarkData;
  final List<DirectoryNavigationTarget>? siblingDirectories;
  final int? currentDirectoryIndex;

  @override
  ConsumerState<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends ConsumerState<MediaGridScreen> {
  MediaViewModelParams? _params;
  MediaViewModel? _viewModel;
  late final MediaMarqueeController _marqueeController;
  late final MediaNavigationHandler _navigationHandler;
  List<MediaEntity> _visibleMediaCache = const [];

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _marqueeController = MediaMarqueeController();
    _navigationHandler = MediaNavigationHandler(
      siblings: widget.siblingDirectories,
      currentIndex: widget.currentDirectoryIndex,
    );
  }

  @override
  void didUpdateWidget(covariant MediaGridScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.siblingDirectories != oldWidget.siblingDirectories ||
        widget.currentDirectoryIndex != oldWidget.currentDirectoryIndex) {
      setState(() {
        _navigationHandler.updateNavigationContext(
          widget.siblingDirectories,
          widget.currentDirectoryIndex,
        );
      });
    }
  }

  @override
  void dispose() {
    _marqueeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'MediaGridScreen: Building for ${widget.directoryName}, screen size: ${MediaQuery.of(context).size}',
    );
    _params = MediaViewModelParams(
      directoryPath: widget.directoryPath,
      directoryName: widget.directoryName,
      bookmarkData: widget.bookmarkData,
      navigateToDirectory:
          (path, name, bookmarkData, siblingDirectories, currentIndex) {
            final destination = MediaGridScreen(
              directoryPath: path,
              directoryName: name,
              bookmarkData: bookmarkData,
              siblingDirectories: siblingDirectories,
              currentDirectoryIndex: currentIndex,
            );

            Navigator.of(context).pushReplacement(
              _navigationHandler.buildNavigationRoute(
                destination: destination,
                isBackwardNavigation:
                    _navigationHandler.isBackwardNavigation(currentIndex),
              ),
            );
          },
      onPermissionRecoveryNeeded: () async {
        return await FilePicker.platform.getDirectoryPath();
      },
    );
    final state = ref.watch(mediaViewModelProvider(_params!));
    _viewModel = ref.read(mediaViewModelProvider(_params!).notifier);
    final selectedMediaIds = ref.watch(selectedMediaIdsProvider(_params!));
    final isSelectionMode = ref.watch(mediaSelectionModeProvider(_params!));
    final selectedMediaCount = ref.watch(selectedMediaCountProvider(_params!));
    if (state case MediaLoaded(:final media)) {
      _visibleMediaCache = media;
    } else {
      _visibleMediaCache = const [];
    }
    final sortOption = state is MediaLoaded
        ? state.sortOption
        : _viewModel?.currentSortOption ?? MediaSortOption.nameAscending;
    final hasSiblingNavigation = _navigationHandler.hasSiblingNavigation;
    final favoritesState = ref.watch(favoritesViewModelProvider);

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): _ClearMediaSelectionIntent(),
        if (_isMacOS)
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA):
              const _SelectAllMediaIntent(),
        if (hasSiblingNavigation)
          LogicalKeySet(LogicalKeyboardKey.arrowLeft):
              const _NavigateToPreviousDirectoryIntent(),
        if (hasSiblingNavigation)
          LogicalKeySet(LogicalKeyboardKey.arrowRight):
              const _NavigateToNextDirectoryIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ClearMediaSelectionIntent:
              CallbackAction<_ClearMediaSelectionIntent>(
                onInvoke: (_) {
                  final selectionActive = ref.read(
                    mediaSelectionModeProvider(_params!),
                  );
                  if (selectionActive) {
                    ref
                        .read(mediaViewModelProvider(_params!).notifier)
                        .clearMediaSelection();
                  }
                  return null;
                },
              ),
          if (_isMacOS)
            _SelectAllMediaIntent: CallbackAction<_SelectAllMediaIntent>(
              onInvoke: (_) {
                if (_viewModel == null || _visibleMediaCache.isEmpty) {
                  return null;
                }
                _viewModel!.selectMediaRange(
                  _visibleMediaCache.map((media) => media.id),
                );
                return null;
              },
            ),
          _NavigateToPreviousDirectoryIntent:
              CallbackAction<_NavigateToPreviousDirectoryIntent>(
                onInvoke: (_) {
                  _navigateToSibling(-1);
                  return null;
                },
              ),
          _NavigateToNextDirectoryIntent:
              CallbackAction<_NavigateToNextDirectoryIntent>(
                onInvoke: (_) {
                  _navigateToSibling(1);
                  return null;
                },
              ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: isSelectionMode
                ? _buildSelectionAppBar(
                    selectedMediaCount,
                    _viewModel!,
                    state as MediaLoaded,
                    selectedMediaIds,
                  )
                : _buildNormalAppBar(sortOption, _viewModel!),
            body: Stack(
              children: [
                Column(
                  children: [
                    MediaFilterBar(
                      viewModel: _viewModel!,
                      state: state,
                      favoritesState: favoritesState,
                      isSelectionMode: isSelectionMode,
                    ),
                    Expanded(
                      child: switch (state) {
                        MediaLoading() => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        MediaLoaded(:final media, :final columns) => MediaGridView(
                            media: media,
                            columns: columns,
                            viewModel: _viewModel!,
                            selectedMediaIds: selectedMediaIds,
                            isSelectionMode: isSelectionMode,
                            marqueeController: _marqueeController,
                            onMediaTap: (media) => _onMediaTap(context, media),
                            onMediaDoubleTap: (media) =>
                                _onMediaDoubleTap(context, media),
                            onMediaLongPress: (media) =>
                                _onMediaLongPress(context, media),
                            onMediaSecondaryTap: (media) =>
                                _onMediaSecondaryTap(context, media),
                          ),
                        MediaPermissionRevoked(
                          :final directoryPath,
                          :final directoryName,
                        ) =>
                          _buildPermissionRevoked(
                            directoryPath,
                            directoryName,
                            _viewModel!,
                          ),
                        MediaError(:final message) => _buildError(
                          message,
                          _viewModel!,
                        ),
                        MediaEmpty() => _buildEmpty(_viewModel!),
                      },
                    ),
                  ],
                ),
                if (hasSiblingNavigation) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: _handleSiblingSwipe,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: _navigationHandler.canNavigateToPrevious
                            ? () => _navigateToSibling(-1)
                            : null,
                        icon: Icon(
                          Icons.chevron_left,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 36,
                        ),
                        tooltip: 'Previous directory',
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: _navigationHandler.canNavigateToNext
                            ? () => _navigateToSibling(1)
                            : null,
                        icon: Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 36,
                        ),
                        tooltip: 'Next directory',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildNormalAppBar(
    MediaSortOption sortOption,
    MediaViewModel viewModel,
  ) {
    return AppBar(
      title: Text(widget.directoryName),
      actions: [
        IconButton(
          icon: const Icon(Icons.tag),
          tooltip: 'Manage Tags',
          onPressed: () => TagManagementDialog.show(context),
        ),
        PopupMenuButton<MediaSortOption>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: viewModel.changeSortOption,
          itemBuilder: (context) => [
            for (final option in MediaSortOption.values)
              CheckedPopupMenuItem<MediaSortOption>(
                value: option,
                checked: option == sortOption,
                child: Text(option.label),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.view_module),
          onPressed: () => _showColumnSelector(context),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar(
    int selectedCount,
    MediaViewModel viewModel,
    MediaLoaded state,
    Set<String> selectedMediaIds,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final favoritesState = ref.watch(favoritesViewModelProvider);
    final favoriteActionLabel = _favoriteBulkActionLabel(
      favoritesState,
      selectedMediaIds,
    );

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Clear selection',
        onPressed: viewModel.clearMediaSelection,
      ),
      title: Text(
        '$selectedCount selected',
        style: theme.textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => unawaited(_assignTagsToSelectedMedia(viewModel)),
          icon: const Icon(Icons.tag),
          label: const Text('Assign Tags'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => unawaited(
            _toggleSelectedMediaFavorites(state.media, selectedMediaIds),
          ),
          icon: const Icon(Icons.favorite),
          label: Text(favoriteActionLabel),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _favoriteBulkActionLabel(
    FavoritesState favoritesState,
    Set<String> selectedMediaIds,
  ) {
    if (selectedMediaIds.isEmpty) {
      return 'Favorite All';
    }

    if (favoritesState is FavoritesLoaded) {
      final favoritesSet = favoritesState.favorites.toSet();
      final allSelectedAreFavorites = selectedMediaIds.every(
        (id) => favoritesSet.contains(id),
      );
      if (allSelectedAreFavorites) {
        return 'Unfavorite All';
      }
      return 'Favorite All';
    }

    if (favoritesState is FavoritesEmpty) {
      return 'Favorite All';
    }

    return 'Toggle Favorites';
  }

  Future<void> _assignTagsToSelectedMedia(MediaViewModel viewModel) async {
    final selectionCount = viewModel.selectedMediaCount;
    final initialTags = viewModel.commonTagIdsForSelection();

    final applied = await BulkTagAssignmentDialog.show(
      context,
      title: 'Assign Tags ($selectionCount selected)',
      description:
          'Choose the tags that should be applied to every selected media item. '
          'Existing tags will be replaced.',
      initialTagIds: initialTags,
      onTagsAssigned: viewModel.applyTagsToSelection,
    );

    if (!mounted || !applied) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated tags for $selectionCount media items')),
    );
  }

  Future<void> _toggleSelectedMediaFavorites(
    List<MediaEntity> media,
    Set<String> selectedMediaIds,
  ) async {
    if (selectedMediaIds.isEmpty) {
      return;
    }

    final favoritesViewModel = ref.read(favoritesViewModelProvider.notifier);
    final selectedMedia = media
        .where((item) => selectedMediaIds.contains(item.id))
        .toList(growable: false);

    final result = await favoritesViewModel.toggleFavoritesForMedia(
      selectedMedia,
    );

    if (!mounted) {
      return;
    }

    final favoritesState = ref.read(favoritesViewModelProvider);
    if (favoritesState is FavoritesError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(favoritesState.message)));
      return;
    }

    final message = switch ((result.added, result.removed)) {
      (final added, final removed) when added > 0 && removed > 0 =>
        'Added $added and removed $removed favorites',
      (final added, _) when added > 0 =>
        'Added $added item${added == 1 ? '' : 's'} to favorites',
      (_, final removed) when removed > 0 =>
        'Removed $removed item${removed == 1 ? '' : 's'} from favorites',
      _ => 'No changes to favorites',
    };

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildError(String message, MediaViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: UiSizing.iconHuge, color: UiColors.red),
          SizedBox(height: UiSpacing.verticalGap),
          Text('Error: $message'),
          SizedBox(height: UiSpacing.verticalGap),
          ElevatedButton(
            onPressed: viewModel.loadMedia,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(MediaViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported,
            size: UiSizing.iconHuge,
            color: UiColors.grey,
          ),
          SizedBox(height: UiSpacing.verticalGap),
          const Text('No media files found in this directory'),
          SizedBox(height: UiSpacing.verticalGap),
          ElevatedButton(
            onPressed: viewModel.loadMedia,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRevoked(
    String directoryPath,
    String directoryName,
    MediaViewModel viewModel,
  ) {
    return Center(
      child: PermissionIssuePanel(
        message:
            'The permissions for "$directoryName" are no longer available.',
        helpText:
            'This can happen when security-scoped bookmarks expire or when directory permissions change.',
        recoverLabel: 'Re-select Directory',
        recoverIcon: Icons.folder_open,
        tryAgainIcon: Icons.refresh,
        backIcon: Icons.arrow_back,
        tryAgainLabel: 'Try Again',
        backLabel: 'Go Back',
        onRecover: () async {
          try {
            await viewModel.recoverPermissions();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permissions recovered successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to recover permissions: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        onTryAgain: viewModel.loadMedia,
        onBack: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _showColumnSelector(BuildContext context) {
    final currentColumns = ref.read(gridColumnsProvider);
    showDialog(
      context: context,
      builder: (context) => ColumnSelectorPopup(
        currentColumns: currentColumns,
        onColumnsSelected: (columns) {
          _viewModel?.setColumns(columns);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _navigateToSibling(int offset) {
    if (_viewModel == null) {
      return;
    }

    _navigationHandler.navigateToSibling(
      context,
      offset,
      _navigateToTarget,
    );
  }

  void _handleSiblingSwipe(DragEndDetails details) {
    if (_viewModel == null) {
      return;
    }

    _navigationHandler.handleSwipe(
      details,
      context,
      _navigateToTarget,
    );
  }

  void _navigateToTarget(
    DirectoryNavigationTarget target,
    int targetIndex,
  ) {
    _viewModel!.navigateToDirectory(
      target.path,
      target.name,
      bookmarkData: target.bookmarkData,
      siblingDirectories: _navigationHandler.siblingNavigationTargets,
      currentIndex: targetIndex,
    );
  }

  List<DirectoryNavigationTarget> _buildSiblingNavigationTargetsFromCache() {
    return _visibleMediaCache
        .where((media) => media.type == MediaType.directory)
        .map(
          (media) => DirectoryNavigationTarget(
            path: media.path,
            name: media.name,
            bookmarkData: media.bookmarkData,
          ),
        )
        .toList();
  }

  Future<void> _onMediaTap(BuildContext context, MediaEntity media) async {
    if (media.type == MediaType.directory) {
      final siblingNavigation = _buildSiblingNavigationTargetsFromCache();
      final targetIndex = siblingNavigation.indexWhere(
        (directory) => directory.path == media.path,
      );
      _viewModel!.navigateToDirectory(
        media.path,
        media.name,
        bookmarkData: media.bookmarkData,
        siblingDirectories: siblingNavigation.isEmpty
            ? null
            : siblingNavigation,
        currentIndex: targetIndex == -1 ? null : targetIndex,
      );
    } else {
      // Open full-screen viewer
      final result = await Navigator.of(context).push<FullScreenExitResult?>(
        MaterialPageRoute(
          builder: (context) => FullScreenViewerScreen(
            directoryPath: widget.directoryPath,
            directoryName: widget.directoryName,
            initialMediaId: media.id,
            bookmarkData: widget.bookmarkData,
            mediaList: _visibleMediaCache.isNotEmpty
                ? _visibleMediaCache
                : null,
            siblingDirectories: _navigationHandler.siblingNavigationTargets,
            currentDirectoryIndex:
                _navigationHandler.currentDirectoryNavigationIndex,
          ),
        ),
      );

      if (!context.mounted || result == null) return;

      setState(() {
        _navigationHandler.updateNavigationContext(
          result.siblingDirectories,
          result.currentDirectoryIndex,
        );
      });

      if (result.currentDirectory.path != widget.directoryPath) {
        _viewModel?.navigateToDirectory(
          result.currentDirectory.path,
          result.currentDirectory.name,
          bookmarkData: result.currentDirectory.bookmarkData,
          siblingDirectories: result.siblingDirectories,
          currentIndex: result.currentDirectoryIndex,
        );
      }
    }
  }

  void _onMediaDoubleTap(BuildContext context, MediaEntity media) {
    // Double-tap opens full-screen viewer
    _onMediaTap(context, media);
  }

  void _onMediaLongPress(BuildContext context, MediaEntity media) {
    // Long-press shows media info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(media.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Path: ${media.path}'),
            Text('Type: ${media.type.name}'),
            Text('Size: ${_formatFileSize(media.size)}'),
            Text('Modified: ${_formatDate(media.lastModified)}'),
            if (media.tagIds.isNotEmpty) Text('Tags: ${media.tagIds.length}'),
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

  void _onMediaSecondaryTap(BuildContext context, MediaEntity media) {
    // Right-click shows context menu
    showMenu(
      context: context,
      position: UiPosition.contextMenu,
      items: [
        PopupMenuItem(
          child: const Text('Open'),
          onTap: () => _onMediaTap(context, media),
        ),
        PopupMenuItem(
          child: const Text('Info'),
          onTap: () => _onMediaLongPress(context, media),
        ),
        // Delete option is handled by FileOperationButton
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < AppConfig.kbBytes) {
      return '$bytes ${AppConfig.byteSuffix}';
    }
    if (bytes < AppConfig.mbBytes) {
      return '${(bytes / AppConfig.kbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.kbSuffix}';
    }
    if (bytes < AppConfig.gbBytes) {
      return '${(bytes / AppConfig.mbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.mbSuffix}';
    }
    return '${(bytes / AppConfig.gbBytes).toStringAsFixed(AppConfig.fileSizeDecimalPlaces)} ${AppConfig.gbSuffix}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ClearMediaSelectionIntent extends Intent {
  const _ClearMediaSelectionIntent();
}

class _SelectAllMediaIntent extends Intent {
  const _SelectAllMediaIntent();
}

class _NavigateToPreviousDirectoryIntent extends Intent {
  const _NavigateToPreviousDirectoryIntent();
}

class _NavigateToNextDirectoryIntent extends Intent {
  const _NavigateToNextDirectoryIntent();
}

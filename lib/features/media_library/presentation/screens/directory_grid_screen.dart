import 'dart:async';

import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_constants.dart';

import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/permission_issue_panel.dart';
import '../../domain/entities/tag_entity.dart';
import '../../../tagging/presentation/states/tag_state.dart';
import '../../../tagging/presentation/view_models/tag_management_view_model.dart';
import '../../../tagging/presentation/widgets/bulk_tag_assignment_dialog.dart';
import '../../../tagging/presentation/widgets/selectable_tag_chip_strip.dart';
import '../../../tagging/presentation/widgets/tag_creation_dialog.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../domain/entities/directory_entity.dart';
import '../models/directory_navigation_target.dart';
import '../view_models/directory_grid_view_model.dart';
import '../widgets/directory_grid_item.dart';
import '../widgets/directory_search_bar.dart';
import '../widgets/column_selector_popup.dart';
import '../widgets/duplicate_media_panel.dart';
import 'media_grid_screen.dart';

/// Screen for displaying directories in a customizable grid layout.
class DirectoryGridScreen extends ConsumerStatefulWidget {
  const DirectoryGridScreen({super.key});

  @override
  ConsumerState<DirectoryGridScreen> createState() =>
      _DirectoryGridScreenState();
}

class _DirectoryGridScreenState extends ConsumerState<DirectoryGridScreen> {
  bool _isDragging = false;
  final GlobalKey _directoryGridOverlayKey = GlobalKey();
  final Map<String, GlobalKey> _directoryItemKeys = <String, GlobalKey>{};
  Rect? _directorySelectionRect;
  Offset? _directoryDragStart;
  bool _isDirectoryMarqueeActive = false;
  bool _directoryAppendMode = false;
  Set<String> _directoryMarqueeBaseSelection = <String>{};
  Set<String> _directoryLastMarqueeSelection = <String>{};
  Map<String, Rect> _directoryCachedItemRects = <String, Rect>{};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directoryViewModelProvider);
    final viewModel = ref.read(directoryViewModelProvider.notifier);
    final selectedDirectoryIds = ref.watch(selectedDirectoryIdsProvider);
    final isSelectionMode = ref.watch(directorySelectionModeProvider);
    final currentSortOption = switch (state) {
      DirectoryLoaded(:final sortOption) => sortOption,
      DirectoryPermissionRevoked(:final sortOption) => sortOption,
      DirectoryBookmarkInvalid(:final sortOption) => sortOption,
      _ => viewModel.currentSortOption,
    };

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape):
            _ClearDirectorySelectionIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ClearDirectorySelectionIntent:
              CallbackAction<_ClearDirectorySelectionIntent>(
                onInvoke: (_) {
                  final hasSelection = ref.read(directorySelectionModeProvider);
                  if (hasSelection) {
                    ref
                        .read(directoryViewModelProvider.notifier)
                        .clearDirectorySelection();
                  }
                  return null;
                },
              ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: isSelectionMode
                ? _buildDirectorySelectionAppBar(
                    viewModel.selectedDirectoryCount,
                    viewModel,
                    state,
                    selectedDirectoryIds,
                  )
                : _buildDirectoryNormalAppBar(currentSortOption, viewModel, ref),
            body: DropTarget(
              onDragDone: (details) => _onDragDone(details, viewModel),
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              child: Stack(
                children: [
                  Column(
                    children: [
                      const DirectorySearchBar(),
                      _buildTagFilter(viewModel),
                      const DuplicateMediaPanel(),
                      Expanded(
                        child: switch (state) {
                          DirectoryLoading() => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          DirectoryLoaded(:final directories, :final columns) =>
                            _buildGrid(
                              directories,
                              columns,
                              viewModel,
                              selectedDirectoryIds,
                              isSelectionMode,
                            ),
                          DirectoryPermissionRevoked(
                            :final inaccessibleDirectories,
                            :final accessibleDirectories,
                            :final columns,
                          ) =>
                            _buildPermissionRevokedGrid(
                              accessibleDirectories,
                              inaccessibleDirectories,
                              columns,
                              viewModel,
                              selectedDirectoryIds,
                              isSelectionMode,
                            ),
                          DirectoryBookmarkInvalid(
                            :final invalidDirectories,
                            :final accessibleDirectories,
                            :final columns,
                          ) =>
                            _buildBookmarkInvalidGrid(
                              accessibleDirectories,
                              invalidDirectories,
                              columns,
                              viewModel,
                              selectedDirectoryIds,
                              isSelectionMode,
                            ),
                          DirectoryError(:final message) => _buildError(
                            message,
                            viewModel,
                          ),
                          DirectoryEmpty() => _buildEmpty(viewModel),
                        },
                      ),
                    ],
                  ),
                  if (_isDragging)
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: UiOpacity.subtle),
                      child: Center(
                        child: Container(
                          padding: UiSpacing.dialogPadding,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(
                              UiSizing.borderRadiusMedium,
                            ),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: UiSizing.borderWidth,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder, size: UiSizing.iconExtraLarge),
                              SizedBox(height: UiSpacing.verticalGap),
                              const Text('Drop directories here to add them'),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildDirectoryNormalAppBar(
    DirectorySortOption currentSortOption,
    DirectoryViewModel viewModel,
    WidgetRef ref,
  ) {
    return AppBar(
      title: const Text('Directories'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showAddDirectoryDialog(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.tag),
          onPressed: () => TagCreationDialog.show(context),
        ),
        PopupMenuButton<DirectorySortOption>(
          icon: const Icon(Icons.sort),
          tooltip: 'Sort',
          onSelected: viewModel.changeSortOption,
          itemBuilder: (context) => [
            for (final option in DirectorySortOption.values)
              CheckedPopupMenuItem<DirectorySortOption>(
                value: option,
                checked: option == currentSortOption,
                child: Text(option.label),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.view_module),
          onPressed: () => _showColumnSelector(context, ref),
        ),
      ],
    );
  }

  AppBar _buildDirectorySelectionAppBar(
    int selectedCount,
    DirectoryViewModel viewModel,
    DirectoryState state,
    Set<String> selectedDirectoryIds,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Clear selection',
        onPressed: viewModel.clearDirectorySelection,
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
          onPressed: () => unawaited(_assignTagsToSelectedDirectories(viewModel)),
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
            _toggleSelectedDirectoryFavorites(state, selectedDirectoryIds),
          ),
          icon: const Icon(Icons.favorite),
          label: const Text('Toggle Favorites'),
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

  void _onDragDone(DropDoneDetails details, DirectoryViewModel viewModel) {
    setState(() => _isDragging = false);

    for (final file in details.files) {
      // Only add directories, not files
      if (file.path.endsWith('/') || !file.path.contains('.')) {
        viewModel.addDirectory(file.path, silent: true);
      }
    }
  }


  Future<void> _assignTagsToSelectedDirectories(
    DirectoryViewModel viewModel,
  ) async {
    final selectionCount = viewModel.selectedDirectoryCount;
    final initialTags = viewModel.commonTagIdsForSelection();

    final applied = await BulkTagAssignmentDialog.show(
      context,
      title: 'Assign Tags ($selectionCount selected)',
      description:
          'Choose the tags that should be applied to every selected directory. '
          'Existing tags will be replaced.',
      initialTagIds: initialTags,
      onTagsAssigned: viewModel.applyTagsToSelection,
    );

    if (!mounted || !applied) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated tags for $selectionCount directories')),
    );
  }

  Future<void> _toggleSelectedDirectoryFavorites(
    DirectoryState state,
    Set<String> selectedDirectoryIds,
  ) async {
    if (selectedDirectoryIds.isEmpty) {
      return;
    }

    final directories = switch (state) {
      DirectoryLoaded(:final directories) => directories,
      DirectoryPermissionRevoked(:final accessibleDirectories) =>
        accessibleDirectories,
      DirectoryBookmarkInvalid(:final accessibleDirectories) =>
        accessibleDirectories,
      _ => const <DirectoryEntity>[],
    };

    final selectedDirectories = directories
        .where((directory) => selectedDirectoryIds.contains(directory.id))
        .toList(growable: false);

    if (selectedDirectories.isEmpty) {
      return;
    }

    final favoritesViewModel = ref.read(favoritesViewModelProvider.notifier);
    final result = await favoritesViewModel
        .toggleFavoritesForDirectories(selectedDirectories);

    if (!mounted) {
      return;
    }

    final favoritesState = ref.read(favoritesViewModelProvider);
    if (favoritesState is FavoritesError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(favoritesState.message)),
      );
      return;
    }

    final message = switch ((result.added, result.removed)) {
      (final added, final removed) when added > 0 && removed > 0 =>
        'Added $added and removed $removed directory favorites',
      (final added, _) when added > 0 =>
        'Added $added director${added == 1 ? 'y' : 'ies'} to favorites',
      (_, final removed) when removed > 0 =>
        'Removed $removed director${removed == 1 ? 'y' : 'ies'} from favorites',
      _ => 'No changes to directory favorites',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTagFilter(DirectoryViewModel viewModel) {
    final tagState = ref.watch(tagViewModelProvider);
    final directoryState = ref.watch(directoryViewModelProvider);
    final selectedTagIds = switch (directoryState) {
      DirectoryLoaded(:final selectedTagIds) => selectedTagIds,
      DirectoryPermissionRevoked(:final selectedTagIds) => selectedTagIds,
      DirectoryBookmarkInvalid(:final selectedTagIds) => selectedTagIds,
      _ => const <String>[],
    };
    final showFavoritesOnly = switch (directoryState) {
      DirectoryLoaded(:final showFavoritesOnly) => showFavoritesOnly,
      DirectoryPermissionRevoked(:final showFavoritesOnly) => showFavoritesOnly,
      DirectoryBookmarkInvalid(:final showFavoritesOnly) => showFavoritesOnly,
      _ => viewModel.showFavoritesOnly,
    };
    final normalizedSelectedTagIds = List<String>.from(selectedTagIds);

    // Debug logging for tag filter state
    debugPrint(
      'DirectoryGridScreen: Building tag filter with selectedTagIds: $normalizedSelectedTagIds',
    );

    final favoritesState = ref.watch(favoritesViewModelProvider);
    final hasFavoriteDirectories = switch (favoritesState) {
      FavoritesLoaded(:final directoryFavorites) =>
          directoryFavorites.isNotEmpty,
      _ => false,
    };

    final shouldShowFavoritesChip = hasFavoriteDirectories || showFavoritesOnly;

    return Container(
      height: UiSizing.tagFilterHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (shouldShowFavoritesChip) ...[
            FilterChip(
              label: const Text('Favorites'),
              avatar: const Icon(Icons.star, color: Colors.amber),
              selected: showFavoritesOnly,
              onSelected: (value) {
                if (!hasFavoriteDirectories && value) {
                  return;
                }
                viewModel.setShowFavoritesOnly(value);
              },
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: switch (tagState) {
              TagLoading() => const Center(child: CircularProgressIndicator()),
              TagError(:final message) => Center(
                  child: Text(
                    'Error loading tags: $message',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
              TagEmpty() => const SizedBox.shrink(),
              TagLoaded(:final tags) => _buildDirectoryTagFilterStrip(
                  tags,
                  normalizedSelectedTagIds,
                  viewModel,
                ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryTagFilterStrip(
    List<TagEntity> tags,
    List<String> selectedTagIds,
    DirectoryViewModel viewModel,
  ) {
    debugPrint(
      'DirectoryGridScreen: Available tags: ${tags.map((t) => t.name).toList()}',
    );

    return SelectableTagChipStrip(
      tags: tags,
      selectedTagIds: selectedTagIds,
      onSelectionChanged: (newSelection) {
        debugPrint(
          'DirectoryGridScreen: Tag selection changed: $newSelection',
        );
        viewModel.filterByTags(newSelection);
      },
    );
  }

  Widget _buildGrid(
    List<DirectoryEntity> directories,
    int columns,
    DirectoryViewModel viewModel,
    Set<String> selectedDirectoryIds,
    bool isSelectionMode,
  ) {
    _pruneDirectoryItemKeys(directories);
    final gridView = GridView.builder(
      padding: UiSpacing.gridPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: UiGrid.crossAxisSpacing,
        mainAxisSpacing: UiGrid.mainAxisSpacing,
        childAspectRatio: UiGrid.childAspectRatio,
      ),
      itemCount: directories.length,
      itemBuilder: (context, index) {
        final directory = directories[index];
        final isSelected = selectedDirectoryIds.contains(directory.id);
        final itemKey = _directoryItemKeys.putIfAbsent(
          directory.id,
          () => GlobalKey(),
        );
        return DirectoryGridItem(
          key: itemKey,
          directory: directory,
          onTap: () => _navigateToMediaGrid(
            context,
            directory,
            directories,
            index,
          ),
          onDelete: () =>
              _showDeleteConfirmation(context, directory, viewModel),
          onAssignTags: (tagIds) => _assignTagsToDirectory(directory, tagIds),
          onSelectionToggle: () =>
              viewModel.toggleDirectorySelection(directory.id),
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
        );
      },
    );
    return _buildDirectoryMarqueeWrapper(viewModel: viewModel, child: gridView);
  }

  Widget _buildPermissionRevokedGrid(
    List<DirectoryEntity> accessibleDirectories,
    List<DirectoryEntity> inaccessibleDirectories,
    int columns,
    DirectoryViewModel viewModel,
    Set<String> selectedDirectoryIds,
    bool isSelectionMode,
  ) {
    final allDirectories = [
      ...accessibleDirectories,
      ...inaccessibleDirectories,
    ];
    _pruneDirectoryItemKeys(allDirectories);

    return Column(
      children: [
        if (inaccessibleDirectories.isNotEmpty)
          PermissionIssuePanel(
            title: 'Access to some directories has been revoked',
            message:
                '${inaccessibleDirectories.length} directory(ies) are inaccessible due to permission changes.',
            helpText: 'Select "Re-grant Permissions" to restore access.',
            recoverLabel: 'Re-grant Permissions',
            recoverIcon: Icons.verified_user,
            accentColor: Theme.of(context).colorScheme.error,
            borderColor: Theme.of(context).colorScheme.error,
            backgroundColor: Theme.of(context).colorScheme.surface,
            margin: UiSpacing.gridPadding,
            padding: const EdgeInsets.all(16),
            fullWidth: true,
            dense: true,
            onRecover: () async => _showReGrantPermissionsDialog(
              context,
              inaccessibleDirectories,
              viewModel,
            ),
          ),
        Expanded(
          child: _buildDirectoryMarqueeWrapper(
            viewModel: viewModel,
            child: GridView.builder(
              padding: UiSpacing.gridPadding,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: UiGrid.crossAxisSpacing,
                mainAxisSpacing: UiGrid.mainAxisSpacing,
                childAspectRatio: UiGrid.childAspectRatio,
              ),
              itemCount: allDirectories.length,
              itemBuilder: (context, index) {
                final directory = allDirectories[index];
                final isInaccessible = inaccessibleDirectories.contains(
                  directory,
                );

                final isSelected = selectedDirectoryIds.contains(directory.id);
                final itemKey = _directoryItemKeys.putIfAbsent(
                  directory.id,
                  () => GlobalKey(),
                );
                return Opacity(
                  opacity: isInaccessible ? UiOpacity.disabled : 1.0,
                  child: DirectoryGridItem(
                    key: itemKey,
                    directory: directory,
                    onTap: isInaccessible
                        ? () {}
                        : () => _navigateToMediaGrid(
                              context,
                              directory,
                              allDirectories,
                              index,
                            ),
                    onDelete: () =>
                        _showDeleteConfirmation(context, directory, viewModel),
                    onAssignTags: (tagIds) =>
                        _assignTagsToDirectory(directory, tagIds),
                    onSelectionToggle: () =>
                        viewModel.toggleDirectorySelection(directory.id),
                    isSelected: isSelected,
                    isSelectionMode: isSelectionMode,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarkInvalidGrid(
    List<DirectoryEntity> accessibleDirectories,
    List<DirectoryEntity> invalidDirectories,
    int columns,
    DirectoryViewModel viewModel,
    Set<String> selectedDirectoryIds,
    bool isSelectionMode,
  ) {
    final allDirectories = [...accessibleDirectories, ...invalidDirectories];
    _pruneDirectoryItemKeys(allDirectories);

    return Column(
      children: [
        if (invalidDirectories.isNotEmpty)
          Container(
            padding: UiSpacing.gridPadding,
            color: Colors.red.shade50,
            child: Row(
              children: [
                Icon(Icons.error, color: UiColors.red),
                SizedBox(width: UiSpacing.smallGap),
                Expanded(
                  child: Text(
                    '${invalidDirectories.length} directory(ies) have invalid bookmarks. '
                    'Click "Recover Bookmarks" to re-select directories.',
                    style: TextStyle(color: UiColors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showRecoverBookmarksDialog(
                    context,
                    invalidDirectories,
                    viewModel,
                  ),
                  child: const Text('Recover Bookmarks'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _buildDirectoryMarqueeWrapper(
            viewModel: viewModel,
            child: GridView.builder(
              padding: UiSpacing.gridPadding,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: UiGrid.crossAxisSpacing,
                mainAxisSpacing: UiGrid.mainAxisSpacing,
                childAspectRatio: UiGrid.childAspectRatio,
              ),
              itemCount: allDirectories.length,
              itemBuilder: (context, index) {
                final directory = allDirectories[index];
                final isInvalid = invalidDirectories.contains(directory);

                final isSelected = selectedDirectoryIds.contains(directory.id);
                final itemKey = _directoryItemKeys.putIfAbsent(
                  directory.id,
                  () => GlobalKey(),
                );
                return Opacity(
                  opacity: isInvalid ? UiOpacity.disabled : 1.0,
                  child: DirectoryGridItem(
                    key: itemKey,
                    directory: directory,
                    onTap: isInvalid
                        ? () {}
                        : () => _navigateToMediaGrid(
                              context,
                              directory,
                              allDirectories,
                              index,
                            ),
                    onDelete: () =>
                        _showDeleteConfirmation(context, directory, viewModel),
                    onAssignTags: (tagIds) =>
                        _assignTagsToDirectory(directory, tagIds),
                    onSelectionToggle: () =>
                        viewModel.toggleDirectorySelection(directory.id),
                    isSelected: isSelected,
                    isSelectionMode: isSelectionMode,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryMarqueeWrapper({
    required Widget child,
    required DirectoryViewModel viewModel,
  }) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _handleDirectoryPointerDown(event, viewModel),
      onPointerMove: (event) => _handleDirectoryPointerMove(event, viewModel),
      onPointerUp: (_) => _endDirectoryMarquee(),
      onPointerCancel: (_) => _endDirectoryMarquee(),
      child: Stack(
        key: _directoryGridOverlayKey,
        children: [
          Positioned.fill(child: child),
          if (_directorySelectionRect != null)
            Positioned.fromRect(
              rect: _directorySelectionRect!,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: UiSizing.borderWidth,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _handleDirectoryPointerDown(
    PointerDownEvent event,
    DirectoryViewModel viewModel,
  ) {
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }

    final overlayContext = _directoryGridOverlayKey.currentContext;
    if (overlayContext == null) {
      return;
    }
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) {
      return;
    }

    _directoryCachedItemRects = _computeDirectoryItemRects();
    final localPosition = overlayBox.globalToLocal(event.position);
    if (_isPointInsideAnyRect(
      localPosition,
      _directoryCachedItemRects.values,
    )) {
      return;
    }

    final baseSelection = viewModel.selectedDirectoryIds;
    _directoryMarqueeBaseSelection = Set<String>.from(baseSelection);
    _directoryLastMarqueeSelection = Set<String>.from(baseSelection);
    _directoryAppendMode = _isMultiSelectModifierPressed();
    _isDirectoryMarqueeActive = true;
    _directoryDragStart = localPosition;

    setState(() {
      _directorySelectionRect = Rect.fromPoints(localPosition, localPosition);
    });

    _updateDirectoryMarqueeSelection(viewModel);
  }

  void _handleDirectoryPointerMove(
    PointerMoveEvent event,
    DirectoryViewModel viewModel,
  ) {
    if (!_isDirectoryMarqueeActive || _directoryDragStart == null) {
      return;
    }

    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) == 0) {
      _endDirectoryMarquee();
      return;
    }

    final overlayContext = _directoryGridOverlayKey.currentContext;
    if (overlayContext == null) {
      return;
    }
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) {
      return;
    }

    final localPosition = overlayBox.globalToLocal(event.position);
    setState(() {
      _directorySelectionRect = Rect.fromPoints(
        _directoryDragStart!,
        localPosition,
      );
    });

    _directoryCachedItemRects = _computeDirectoryItemRects();
    _updateDirectoryMarqueeSelection(viewModel);
  }

  void _endDirectoryMarquee() {
    if (!_isDirectoryMarqueeActive && _directorySelectionRect == null) {
      return;
    }

    setState(() {
      _directorySelectionRect = null;
    });
    _isDirectoryMarqueeActive = false;
    _directoryDragStart = null;
    _directoryAppendMode = false;
    _directoryMarqueeBaseSelection = <String>{};
    _directoryLastMarqueeSelection = <String>{};
    _directoryCachedItemRects = <String, Rect>{};
  }

  void _updateDirectoryMarqueeSelection(DirectoryViewModel viewModel) {
    if (!_isDirectoryMarqueeActive) {
      return;
    }

    final selectionRect = _directorySelectionRect;
    final rects = _directoryCachedItemRects;
    final intersectingIds = <String>{};

    if (selectionRect != null) {
      for (final entry in rects.entries) {
        if (entry.value.overlaps(selectionRect)) {
          intersectingIds.add(entry.key);
        }
      }
    }

    final desiredSelection = _directoryAppendMode
        ? {..._directoryMarqueeBaseSelection, ...intersectingIds}
        : intersectingIds;

    if (setEquals(desiredSelection, _directoryLastMarqueeSelection)) {
      return;
    }

    _directoryLastMarqueeSelection = desiredSelection;
    viewModel.selectDirectoryRange(desiredSelection, append: false);
  }

  Map<String, Rect> _computeDirectoryItemRects() {
    final overlayContext = _directoryGridOverlayKey.currentContext;
    if (overlayContext == null) {
      return <String, Rect>{};
    }

    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) {
      return <String, Rect>{};
    }

    final rects = <String, Rect>{};
    final staleKeys = <String>[];
    _directoryItemKeys.forEach((id, key) {
      final context = key.currentContext;
      if (context == null) {
        staleKeys.add(id);
        return;
      }
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        staleKeys.add(id);
        return;
      }
      final topLeft = renderObject.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
      rects[id] = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        renderObject.size.width,
        renderObject.size.height,
      );
    });

    for (final id in staleKeys) {
      _directoryItemKeys.remove(id);
    }

    return rects;
  }

  void _pruneDirectoryItemKeys(Iterable<DirectoryEntity> directories) {
    final validIds = directories.map((directory) => directory.id).toSet();
    _directoryItemKeys.removeWhere((id, _) => !validIds.contains(id));
  }

  bool _isPointInsideAnyRect(Offset point, Iterable<Rect> rects) {
    for (final rect in rects) {
      if (rect.contains(point)) {
        return true;
      }
    }
    return false;
  }

  bool _isMultiSelectModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
  }

  Widget _buildError(String message, DirectoryViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: UiSizing.iconHuge, color: UiColors.red),
          SizedBox(height: UiSpacing.verticalGap),
          Text('Error: $message'),
          SizedBox(height: UiSpacing.verticalGap),
          ElevatedButton(
            onPressed: viewModel.loadDirectories,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(DirectoryViewModel viewModel) {
    return Consumer(
      builder: (context, ref, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open,
                size: UiSizing.iconHuge,
                color: UiColors.grey,
              ),
              SizedBox(height: UiSpacing.verticalGap),
              const Text('No directories found'),
              SizedBox(height: UiSpacing.verticalGap),
              ElevatedButton(
                onPressed: () => _showAddDirectoryDialog(context, ref),
                child: const Text('Add Directory'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDirectoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Directory'),
        content: const Text(
          'You can drag and drop directories onto the screen, or click below to browse and select a directory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final path = await FilePicker.platform.getDirectoryPath();
              if (path != null) {
                final viewModel = ref.read(directoryViewModelProvider.notifier);
                await viewModel.addDirectory(path);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Browse'),
          ),
        ],
      ),
    );
  }

  void _showColumnSelector(BuildContext context, WidgetRef ref) {
    final currentColumns = ref.read(gridColumnsProvider);
    showDialog(
      context: context,
      builder: (context) => ColumnSelectorPopup(
        currentColumns: currentColumns,
        onColumnsSelected: (columns) {
          ref.read(directoryViewModelProvider.notifier).setColumns(columns);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  List<DirectoryNavigationTarget> _mapDirectoriesToNavigationTargets(
    List<DirectoryEntity> directories,
  ) {
    return directories
        .map(
          (directory) => DirectoryNavigationTarget(
            path: directory.path,
            name: directory.name,
            bookmarkData: directory.bookmarkData,
          ),
        )
        .toList();
  }

  void _navigateToMediaGrid(
    BuildContext context,
    DirectoryEntity directory,
    List<DirectoryEntity> siblingDirectories,
    int currentIndex,
  ) {
    final navigationTargets =
        _mapDirectoriesToNavigationTargets(siblingDirectories);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGridScreen(
          directoryPath: directory.path,
          directoryName: directory.name,
          bookmarkData: directory.bookmarkData,
          siblingDirectories: navigationTargets,
          currentDirectoryIndex: currentIndex,
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    DirectoryEntity directory,
    DirectoryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Directory'),
        content: Text(
          'Are you sure you want to remove "${directory.name}" from the library?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.removeDirectory(directory.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showReGrantPermissionsDialog(
    BuildContext context,
    List<DirectoryEntity> inaccessibleDirectories,
    DirectoryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-grant Permissions'),
        content: Text(
          'This will re-add ${inaccessibleDirectories.length} directory(ies) to restore access. '
          'You will need to grant permissions again when prompted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              for (final directory in inaccessibleDirectories) {
                await viewModel.reGrantDirectoryPermissions(directory.path);
              }
            },
            child: const Text('Re-grant Permissions'),
          ),
        ],
      ),
    );
  }

  void _showRecoverBookmarksDialog(
    BuildContext context,
    List<DirectoryEntity> invalidDirectories,
    DirectoryViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recover Bookmarks'),
        content: Text(
          'This will prompt you to re-select ${invalidDirectories.length} directory(ies) to recover bookmarks. '
          'You will need to select the same directories again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              for (final directory in invalidDirectories) {
                await viewModel.recoverDirectoryBookmark(
                  directory.id,
                  directory.path,
                );
              }
            },
            child: const Text('Recover Bookmarks'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignTagsToDirectory(
    DirectoryEntity directory,
    List<String> tagIds,
  ) async {
    final assignTagUseCase = ref.read(assignTagUseCaseProvider);

    try {
      await assignTagUseCase.setTagsForDirectory(directory.id, tagIds);
      await ref.read(directoryViewModelProvider.notifier).loadDirectories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to assign tags: $e')));
      }
      rethrow;
    }
  }
}

class _ClearDirectorySelectionIntent extends Intent {
  const _ClearDirectorySelectionIntent();
}

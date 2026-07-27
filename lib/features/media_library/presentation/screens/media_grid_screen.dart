import 'dart:async';

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/utils/file_size_formatter.dart';
import '../../../../core/services/directory_picker_service.dart';
import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/grid_scroll_offset.dart';
import '../../../../core/services/file_transfer_result.dart';
import '../../../../shared/widgets/delete_media_action.dart';
import '../../../../shared/widgets/media_marquee_selector.dart';
import '../../../../shared/widgets/move_copy_media_action.dart';
import '../../../../shared/widgets/permission_issue_panel.dart';
import '../../../../shared/widgets/shortcut_help_overlay.dart';

import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../full_screen/presentation/models/full_screen_exit_result.dart';
import '../../../tagging/presentation/widgets/bulk_tag_assignment_dialog.dart';
import '../../../tagging/presentation/widgets/tag_filter_chips.dart';
import '../../../tagging/presentation/widgets/tag_management_dialog.dart';
import '../../domain/entities/media_entity.dart';
import '../models/directory_navigation_target.dart';
import '../providers/directory_cover_controller.dart';
import '../providers/directory_cover_providers.dart';
import '../view_models/directory_grid_view_model.dart';
import '../view_models/media_grid_view_model.dart';
import '../widgets/media_grid_item.dart';
import '../widgets/column_selector_popup.dart';
import '../widgets/directory_cover_picker_dialog.dart';

/// How long a revealed item stays called out. Long enough for the eye to land on
/// it after the scroll, short enough not to be mistaken for a selection.
const Duration _revealHighlightDuration = Duration(milliseconds: 2500);

/// Screen for displaying media in a customizable grid layout.
class MediaGridScreen extends ConsumerStatefulWidget {
  const MediaGridScreen({
    super.key,
    required this.directoryPath,
    required this.directoryName,
    this.bookmarkData,
    this.siblingDirectories,
    this.currentDirectoryIndex,
    this.initialMediaId,
  });

  final String directoryPath;
  final String directoryName;
  final String? bookmarkData;
  final List<DirectoryNavigationTarget>? siblingDirectories;
  final int? currentDirectoryIndex;

  /// Media to scroll to and briefly highlight once the grid has loaded.
  ///
  /// Set when the user was brought here to find a specific item ("go to
  /// directory" in the viewer). Mirrors `FullScreenViewerScreen.initialMediaId`,
  /// and like it, an id that is not in the list is simply ignored.
  final String? initialMediaId;

  @override
  ConsumerState<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends ConsumerState<MediaGridScreen> {
  MediaViewModelParams? _params;
  MediaViewModel? _viewModel;
  final GlobalKey _mediaGridOverlayKey = GlobalKey();
  final Map<String, GlobalKey> _mediaItemKeys = <String, GlobalKey>{};
  final ScrollController _gridScrollController = ScrollController();
  List<MediaEntity> _visibleMediaCache = const [];

  /// Item currently called out by the reveal, cleared once the highlight fades.
  String? _revealedMediaId;
  Timer? _revealHighlightTimer;

  /// The reveal is a one-shot on arrival — re-running it on every rebuild would
  /// yank the grid back under a user who has since scrolled away.
  bool _hasRevealed = false;
  List<DirectoryNavigationTarget> _siblingNavigationTargets = const [];
  int _currentDirectoryNavigationIndex = 0;
  late final FocusNode _focusNode;
  Size? _lastLoggedScreenSize;
  Size? _lastLoggedGridSize;
  String? _lastLoggedDirectoryName;
  int? _lastLoggedGridItemCount;
  int? _lastLoggedGridColumns;

  bool get _isMacOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _applyNavigationContext(
      widget.siblingDirectories,
      widget.currentDirectoryIndex,
    );
  }

  @override
  void dispose() {
    _revealHighlightTimer?.cancel();
    _gridScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MediaGridScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.siblingDirectories != oldWidget.siblingDirectories ||
        widget.currentDirectoryIndex != oldWidget.currentDirectoryIndex) {
      _applyNavigationContext(
        widget.siblingDirectories,
        widget.currentDirectoryIndex,
        withSetState: true,
      );
    }
  }

  void _applyNavigationContext(
    List<DirectoryNavigationTarget>? siblings,
    int? currentIndex, {
    bool withSetState = false,
  }) {
    void updater() {
      _siblingNavigationTargets = List<DirectoryNavigationTarget>.from(
        siblings ?? const [],
      );
      if (_siblingNavigationTargets.isEmpty) {
        _currentDirectoryNavigationIndex = 0;
        return;
      }

      final maxIndex = _siblingNavigationTargets.length - 1;
      final safeIndex = (currentIndex ?? 0).clamp(0, maxIndex);
      _currentDirectoryNavigationIndex = safeIndex;
    }

    if (withSetState) {
      setState(updater);
    } else {
      updater();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(directoryCoverControllerProvider(widget.directoryPath));
    final screenSize = MediaQuery.of(context).size;
    if (_shouldLogBuild(screenSize)) {
      _logMediaDebug(
        'MediaGridScreen: Building for ${widget.directoryName}, screen size: $screenSize',
      );
    }
    _params = MediaViewModelParams(
      directoryPath: widget.directoryPath,
      directoryName: widget.directoryName,
      bookmarkData: widget.bookmarkData,
      navigateToDirectory:
          (
            path,
            name,
            bookmarkData,
            siblingDirectories,
            currentIndex, {
            bool replaceCurrentRoute = false,
          }) {
            final targetIndex =
                currentIndex ?? _currentDirectoryNavigationIndex;
            final hasSiblingNavigation =
                (siblingDirectories?.isNotEmpty ?? false) &&
                _siblingNavigationTargets.isNotEmpty;
            final isBackwardNavigation =
                replaceCurrentRoute && hasSiblingNavigation
                ? targetIndex < _currentDirectoryNavigationIndex
                : false;

            final route = PageRouteBuilder(
              transitionDuration: const Duration(milliseconds: 250),
              reverseTransitionDuration: const Duration(milliseconds: 250),
              pageBuilder: (context, animation, secondaryAnimation) =>
                  MediaGridScreen(
                    directoryPath: path,
                    directoryName: name,
                    bookmarkData: bookmarkData,
                    siblingDirectories: siblingDirectories,
                    currentDirectoryIndex: currentIndex,
                  ),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    final beginOffset = isBackwardNavigation
                        ? const Offset(-1, 0)
                        : const Offset(1, 0);
                    final tween = Tween(
                      begin: beginOffset,
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOutCubic));

                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
            );

            if (replaceCurrentRoute) {
              Navigator.of(context).pushReplacement(route);
            } else {
              Navigator.of(context).push(route);
            }
          },
      onPermissionRecoveryNeeded: () async {
        try {
          final directoryPickerService = DirectoryPickerService();
          return await directoryPickerService.pickSingleDirectory();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to select directory: $e')),
            );
          }
          return null;
        }
      },
    );
    final state = ref.watch(mediaViewModelProvider(_params!));
    _viewModel = ref.read(mediaViewModelProvider(_params!).notifier);
    final selectedMediaIds = ref.watch(selectedMediaIdsProvider(_params!));
    final isSelectionMode = ref.watch(mediaSelectionModeProvider(_params!));
    final selectedMediaCount = ref.watch(selectedMediaCountProvider(_params!));
    if (state case MediaLoaded(:final media)) {
      _visibleMediaCache = media;
      _scheduleReveal();
    } else {
      _visibleMediaCache = const [];
    }
    final sortOption = state is MediaLoaded
        ? state.sortOption
        : _viewModel?.currentSortOption ?? MediaSortOption.nameAscending;
    final hasSiblingNavigation = _siblingNavigationTargets.length > 1;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): _ClearMediaSelectionIntent(),
        if (_isMacOS)
          LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyA):
              const _SelectAllMediaIntent(),
        if (_isMacOS)
          LogicalKeySet(LogicalKeyboardKey.delete):
              const _DeleteSelectedMediaIntent(),
        if (_isMacOS)
          LogicalKeySet(LogicalKeyboardKey.backspace):
              const _DeleteSelectedMediaIntent(),
        if (hasSiblingNavigation)
          LogicalKeySet(LogicalKeyboardKey.arrowLeft):
              const _NavigateToPreviousDirectoryIntent(),
        if (hasSiblingNavigation)
          LogicalKeySet(LogicalKeyboardKey.arrowRight):
              const _NavigateToNextDirectoryIntent(),
        LogicalKeySet(
          _isMacOS ? LogicalKeyboardKey.meta : LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyR,
        ): const _RefreshMediaIntent(),
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
          if (_isMacOS)
            _DeleteSelectedMediaIntent:
                CallbackAction<_DeleteSelectedMediaIntent>(
                  onInvoke: (_) {
                    final selectionActive = ref.read(
                      mediaSelectionModeProvider(_params!),
                    );
                    if (!selectionActive || _viewModel == null) {
                      return null;
                    }
                    unawaited(
                      _deleteSelectedMedia(
                        _visibleMediaCache,
                        ref.read(selectedMediaIdsProvider(_params!)),
                        _viewModel!,
                      ),
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
          _RefreshMediaIntent: CallbackAction<_RefreshMediaIntent>(
            onInvoke: (_) {
              unawaited(_viewModel?.loadMedia() ?? Future<void>.value());
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
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
                    _buildTagFilter(_viewModel!, state, isSelectionMode),
                    Expanded(
                      child: switch (state) {
                        MediaLoading() => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        MediaLoaded(:final media, :final columns) => _buildGrid(
                          media,
                          columns,
                          _viewModel!,
                          selectedMediaIds,
                          isSelectionMode,
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
                        onPressed: _currentDirectoryNavigationIndex > 0
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
                        onPressed:
                            _currentDirectoryNavigationIndex <
                                _siblingNavigationTargets.length - 1
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
    final hasCustomCover =
        ref.watch(directoryCoverProvider(widget.directoryPath)).valueOrNull !=
        null;
    return AppBar(
      title: Text(widget.directoryName),
      actions: [
        IconButton(
          icon: const Icon(Icons.tag),
          tooltip: 'Manage Tags',
          onPressed: () => TagManagementDialog.show(context),
        ),
        PopupMenuButton<_CurrentDirectoryCoverAction>(
          icon: const Icon(Icons.image_outlined),
          tooltip: 'Directory cover',
          onSelected: _handleCurrentDirectoryCoverAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _CurrentDirectoryCoverAction.choose,
              child: Text('Choose Cover…'),
            ),
            if (hasCustomCover)
              const PopupMenuItem(
                value: _CurrentDirectoryCoverAction.reset,
                child: Text('Reset Cover'),
              ),
          ],
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
        // Operations update the grid in place, so nothing re-reads the folder on
        // its own any more. This is how a change made outside the app gets
        // picked up.
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: _isMacOS ? 'Refresh (⌘R)' : 'Refresh (Ctrl+R)',
          onPressed: () => unawaited(viewModel.loadMedia()),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'Keyboard shortcuts (?)',
          onPressed: _showShortcutHelp,
        ),
        if (_isMacOS)
          IconButton(
            icon: const Icon(Icons.drive_file_move_outline),
            tooltip: 'Move this folder',
            onPressed: () => unawaited(_moveCurrentDirectory()),
          ),
        if (_isMacOS)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete this folder',
            onPressed: () => unawaited(_deleteCurrentDirectory()),
          ),
      ],
    );
  }

  /// Moves the directory currently being viewed into another folder and follows
  /// it there, so the user stays with the content they were looking at.
  ///
  /// Only a move is offered, not a copy: duplicating a folder would have to give
  /// every file inside it a fresh identity, which is a lot of cache churn for
  /// little benefit.
  Future<void> _moveCurrentDirectory() async {
    final media = _currentDirectoryAsMedia();
    final container = ProviderScope.containerOf(context, listen: false);

    // Whether this is a tracked library root decides what has to be refreshed
    // afterwards, and the folder is easiest to identify before it moves.
    final trackedRoot = await container
        .read(directoryRepositoryProvider)
        .getDirectoryById(media.id);
    if (!mounted) return;

    final moved = await pickDestinationAndTransferMedia(
      context,
      media,
      mode: TransferMode.move,
    );
    if (moved == null || !mounted) return;

    // The parent grid drops this folder's tile from the mutation the transfer
    // published, so nothing needs rescanning. Only the library grid, which bakes
    // counts into its own entities, still has to reload.
    if (trackedRoot != null) {
      container.invalidate(directoryViewModelProvider);
    }
    if (!mounted) return;

    // This route is keyed by the old path, which no longer exists. Replace it
    // with one pointing at where the folder landed.
    _viewModel?.navigateToDirectory(
      moved.path,
      moved.name,
      bookmarkData: trackedRoot?.bookmarkData ?? widget.bookmarkData,
      replaceCurrentRoute: true,
    );
  }

  /// Represents the directory currently being viewed as a deletable item.
  MediaEntity _currentDirectoryAsMedia() {
    final id = generateDirectoryId(widget.directoryPath);
    return MediaEntity(
      id: id,
      path: widget.directoryPath,
      name: widget.directoryName,
      type: MediaType.directory,
      size: 0,
      lastModified: DateTime.now(),
      tagIds: const [],
      directoryId: id,
      bookmarkData: widget.bookmarkData,
    );
  }

  /// Moves the directory currently being viewed to the Trash, cleans up any
  /// dangling library/cache state, and pops back to the previous route.
  Future<void> _deleteCurrentDirectory() async {
    final media = _currentDirectoryAsMedia();
    final container = ProviderScope.containerOf(context, listen: false);
    final directoryRepository = container.read(directoryRepositoryProvider);

    // Determine up front whether this is a tracked library root (vs. a
    // subdirectory), while the folder still exists on disk.
    final trackedRoot = await directoryRepository.getDirectoryById(media.id);
    if (!mounted) return;

    final deleted = await confirmAndDeleteMedia(context, media);
    if (!deleted || !mounted) return;

    // The folder is now in the Trash. Its cached rows were purged by the delete
    // itself, and the parent grid drops its tile from the mutation that was
    // published — so the only thing left is the library entry, if it was one.
    if (trackedRoot != null) {
      await directoryRepository.removeDirectory(trackedRoot.id);
      container.invalidate(directoryViewModelProvider);
    }
    if (!mounted) return;

    // Optionally move to a sibling directory instead of going back.
    final goToSibling = container.read(
      navigateToSiblingAfterDirectoryDeleteProvider,
    );
    final navigatedToSibling = goToSibling && _navigateToSiblingAfterDelete();

    if (!navigatedToSibling) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  /// Replaces the current route with a sibling directory — the next one, or the
  /// previous one when already at the end. Returns false when there are no
  /// other siblings (the caller then falls back to popping).
  bool _navigateToSiblingAfterDelete() {
    final siblings = _siblingNavigationTargets;
    final currentIndex = _currentDirectoryNavigationIndex;
    if (siblings.length < 2 ||
        currentIndex < 0 ||
        currentIndex >= siblings.length) {
      return false;
    }

    final int targetIndex;
    if (currentIndex + 1 < siblings.length) {
      targetIndex = currentIndex + 1;
    } else if (currentIndex - 1 >= 0) {
      targetIndex = currentIndex - 1;
    } else {
      return false;
    }

    final target = siblings[targetIndex];
    // Hand the next screen a sibling list without the just-deleted directory.
    final updatedSiblings = <DirectoryNavigationTarget>[
      for (var i = 0; i < siblings.length; i++)
        if (i != currentIndex) siblings[i],
    ];
    final updatedIndex = updatedSiblings.indexWhere(
      (d) => d.path == target.path,
    );

    _viewModel?.navigateToDirectory(
      target.path,
      target.name,
      bookmarkData: target.bookmarkData,
      siblingDirectories: updatedSiblings.isEmpty ? null : updatedSiblings,
      currentIndex: updatedIndex == -1 ? null : updatedIndex,
      replaceCurrentRoute: true,
    );
    return true;
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
        if (_isMacOS) ...[
          const SizedBox(width: 8),
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                onPressed: () => unawaited(
                  _transferSelectedMedia(
                    state.media,
                    selectedMediaIds,
                    viewModel,
                    TransferMode.move,
                  ),
                ),
                child: const Text('Move to…'),
              ),
              MenuItemButton(
                onPressed: () => unawaited(
                  _transferSelectedMedia(
                    state.media,
                    selectedMediaIds,
                    viewModel,
                    TransferMode.copy,
                  ),
                ),
                child: const Text('Copy to…'),
              ),
            ],
            builder: (context, controller, _) => FilledButton.icon(
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Move'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => unawaited(
              _deleteSelectedMedia(state.media, selectedMediaIds, viewModel),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        IconButton(
          onPressed: _showShortcutHelp,
          icon: const Icon(Icons.help_outline),
          tooltip: 'Keyboard shortcuts (?)',
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

  Widget _buildTagFilter(
    MediaViewModel viewModel,
    MediaState state,
    bool isSelectionMode,
  ) {
    final selectedTagIds = state is MediaLoaded
        ? state.selectedTagIds
        : const <String>[];
    final showFavoritesOnly = state is MediaLoaded
        ? state.showFavoritesOnly
        : viewModel.showFavoritesOnly;
    final showUntaggedOnly = state is MediaLoaded
        ? state.showUntaggedOnly
        : viewModel.showUntaggedOnly;
    final visibleMediaTypes = state is MediaLoaded
        ? state.visibleMediaTypes
        : viewModel.visibleMediaTypes;
    return Container(
      padding: UiSpacing.tagFilterPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final type in [
                MediaType.image,
                MediaType.video,
                MediaType.audio,
                MediaType.directory,
              ])
                FilterChip(
                  label: Text(type.label),
                  avatar: Icon(_iconForType(type)),
                  selected: visibleMediaTypes.contains(type),
                  onSelected: (selected) => _onMediaTypeSelected(
                    type,
                    selected,
                    visibleMediaTypes,
                    viewModel,
                  ),
                ),
              FilterChip(
                label: const Text('Favorites'),
                avatar: const Icon(Icons.star, color: Colors.amber),
                selected: showFavoritesOnly,
                onSelected: viewModel.setShowFavoritesOnly,
              ),
              FilterChip(
                label: const Text('Untagged'),
                avatar: const Icon(Icons.label_off),
                selected: showUntaggedOnly,
                onSelected: (value) async {
                  await viewModel.setShowUntaggedOnly(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TagFilterChips(
            selectedTagIds: isSelectionMode
                ? viewModel.tagIdsInSelection()
                : selectedTagIds,
            onSelectionChanged: isSelectionMode
                ? (_) {}
                : viewModel.filterByTags,
            onTagTapped: isSelectionMode
                ? (tag, _) => viewModel.toggleTagForSelection(tag)
                : null,
            showAllButton: !isSelectionMode,
          ),
        ],
      ),
    );
  }

  IconData _iconForType(MediaType type) => switch (type) {
    MediaType.image => Icons.image_outlined,
    MediaType.video => Icons.movie_creation_outlined,
    MediaType.audio => Icons.audiotrack,
    MediaType.directory => Icons.folder,
    MediaType.text => Icons.description_outlined,
  };

  void _onMediaTypeSelected(
    MediaType type,
    bool isSelected,
    Set<MediaType> currentSelection,
    MediaViewModel viewModel,
  ) {
    final updatedSelection = Set<MediaType>.from(currentSelection);
    if (isSelected) {
      updatedSelection.add(type);
    } else {
      if (updatedSelection.length == 1) {
        return; // Prevent clearing all types
      }
      updatedSelection.remove(type);
    }

    viewModel.setVisibleMediaTypes(updatedSelection);
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

  /// Moves every selected file and subfolder to the Trash, then refreshes the
  /// grid. Subfolders take their contents with them, so a selection that mixes
  /// a folder with files inside it still results in a single folder delete
  /// (handled by [FileOperationsViewModel.deleteMediaBatch]).
  Future<void> _deleteSelectedMedia(
    List<MediaEntity> media,
    Set<String> selectedMediaIds,
    MediaViewModel viewModel,
  ) async {
    if (selectedMediaIds.isEmpty) {
      return;
    }

    final selected = media
        .where((item) => selectedMediaIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      return;
    }

    final container = ProviderScope.containerOf(context, listen: false);
    final result = await confirmAndDeleteMediaBatch(context, selected);
    if (result == null || !result.hasSuccesses || !mounted) {
      return;
    }

    final deletedIds = result.successfulIds.toSet();
    final deletedDirectories = selected.where(
      (item) =>
          item.type == MediaType.directory && deletedIds.contains(item.id),
    );
    await _dropLibraryEntriesFor(deletedDirectories, container);

    // The tiles are dropped by the mutation the delete published, and the
    // selection prunes itself down to whatever survived — so anything that
    // failed stays on screen and stays selected, ready to be retried.
  }

  /// Moves or copies the current selection into one folder.
  Future<void> _transferSelectedMedia(
    List<MediaEntity> media,
    Set<String> selectedMediaIds,
    MediaViewModel viewModel,
    TransferMode mode,
  ) async {
    final selected = media
        .where((item) => selectedMediaIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      return;
    }

    await pickDestinationAndTransferMediaBatch(context, selected, mode: mode);

    // The moved tiles are dropped by the mutation that was published, which also
    // prunes them from the selection. A copy moves nothing, so its selection
    // correctly survives.
  }

  /// Removes library/cache state for any trashed folder that also happened to
  /// be a tracked library root (possible when both a parent and a child folder
  /// were added to the library).
  Future<void> _dropLibraryEntriesFor(
    Iterable<MediaEntity> deletedDirectories,
    ProviderContainer container,
  ) async {
    if (deletedDirectories.isEmpty) {
      return;
    }

    final directoryRepository = container.read(directoryRepositoryProvider);
    // Match by path: the scan derives subdirectory ids from a normalized path,
    // which can differ from the tracked root's id.
    final trackedDirectories = await directoryRepository.getDirectories();
    final trackedByPath = {
      for (final directory in trackedDirectories) directory.path: directory,
    };

    // The cached rows under each trashed folder were already purged by the
    // delete itself; only the library entry is left to remove.
    var removedTrackedRoot = false;
    for (final deleted in deletedDirectories) {
      final trackedRoot = trackedByPath[deleted.path];
      if (trackedRoot != null) {
        await directoryRepository.removeDirectory(trackedRoot.id);
        removedTrackedRoot = true;
      }
    }

    if (removedTrackedRoot) {
      container.invalidate(directoryViewModelProvider);
    }
  }

  Widget _buildGrid(
    List<MediaEntity> media,
    int columns,
    MediaViewModel viewModel,
    Set<String> selectedMediaIds,
    bool isSelectionMode,
  ) {
    final screenSize = MediaQuery.of(context).size;
    if (_shouldLogGrid(media.length, columns, screenSize)) {
      _logMediaDebug(
        'MediaGridScreen: Building grid with ${media.length} items, $columns columns, screen size: $screenSize',
      );
    }
    _pruneMediaItemKeys(media);
    final gridView = GridView.builder(
      controller: _gridScrollController,
      padding: UiSpacing.gridPadding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: UiGrid.crossAxisSpacing,
        mainAxisSpacing: UiGrid.mainAxisSpacing,
        childAspectRatio: UiGrid.childAspectRatio,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        final isSelected = selectedMediaIds.contains(mediaItem.id);
        final itemKey = _mediaItemKeys.putIfAbsent(
          mediaItem.id,
          () => GlobalKey(),
        );
        return MediaGridItem(
          key: itemKey,
          media: mediaItem,
          bookmarkData: widget.bookmarkData,
          onTap: () => _onMediaTap(context, mediaItem),
          onDoubleTap: () => _onMediaDoubleTap(context, mediaItem),
          onLongPress: () => _onMediaLongPress(context, mediaItem),
          onSecondaryTap: () => _onMediaSecondaryTap(context, mediaItem),
          onSelectionToggle: () => viewModel.toggleMediaSelection(mediaItem.id),
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          isHighlighted: mediaItem.id == _revealedMediaId,
        );
      },
    );
    return _buildMediaMarqueeWrapper(viewModel: viewModel, child: gridView);
  }

  /// Queues the one-shot scroll-to-and-highlight for [MediaGridScreen.initialMediaId].
  ///
  /// Called from `build` the first time the media list arrives; the actual work
  /// waits for the frame, because the grid has no scroll position (and no width)
  /// until it has been laid out at least once.
  void _scheduleReveal() {
    if (_hasRevealed || widget.initialMediaId == null) {
      return;
    }
    _hasRevealed = true;

    final mediaId = widget.initialMediaId!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealMedia(mediaId));
  }

  void _revealMedia(String mediaId) {
    if (!mounted) {
      return;
    }

    final index = _visibleMediaCache.indexWhere((item) => item.id == mediaId);
    if (index < 0) {
      // The item isn't here — it may have been moved or deleted since. Opening
      // the folder is still the useful half of the request, so leave it at that.
      return;
    }

    _scrollToIndex(index);

    setState(() => _revealedMediaId = mediaId);
    _revealHighlightTimer?.cancel();
    _revealHighlightTimer = Timer(_revealHighlightDuration, () {
      if (mounted) {
        setState(() => _revealedMediaId = null);
      }
    });
  }

  void _scrollToIndex(int index) {
    if (!_gridScrollController.hasClients) {
      return;
    }

    // The grid's own width, not the screen's: the offset depends on tile size,
    // which depends on how wide the grid actually is.
    final gridBox =
        _mediaGridOverlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (gridBox == null || !gridBox.hasSize) {
      return;
    }

    final offset = gridScrollOffsetForIndex(
      index: index,
      columns: ref.read(gridColumnsProvider),
      viewportWidth: gridBox.size.width,
    );

    final position = _gridScrollController.position;
    _gridScrollController.jumpTo(
      offset.clamp(position.minScrollExtent, position.maxScrollExtent),
    );
  }

  Widget _buildMediaMarqueeWrapper({
    required Widget child,
    required MediaViewModel viewModel,
  }) {
    return MediaMarqueeSelector(
      key: _mediaGridOverlayKey,
      itemKeys: _mediaItemKeys,
      selection: viewModel.selectedMediaIds,
      isSelectionMode: viewModel.isSelectionMode,
      onSelectionChanged: (ids) =>
          viewModel.selectMediaRange(ids, append: false),
      onEnableSelectionMode: viewModel.enableSelectionMode,
      onClearSelection: viewModel.clearMediaSelection,
      child: child,
    );
  }

  bool _shouldLogBuild(Size screenSize) {
    final hasDirectoryChanged =
        _lastLoggedDirectoryName != widget.directoryName;
    final hasScreenChanged = _lastLoggedScreenSize != screenSize;
    if (hasDirectoryChanged || hasScreenChanged) {
      _lastLoggedDirectoryName = widget.directoryName;
      _lastLoggedScreenSize = screenSize;
      return true;
    }
    return false;
  }

  bool _shouldLogGrid(int itemCount, int columns, Size screenSize) {
    final hasItemCountChanged = _lastLoggedGridItemCount != itemCount;
    final hasColumnChanged = _lastLoggedGridColumns != columns;
    final hasScreenSizeChanged = _lastLoggedGridSize != screenSize;

    if (hasItemCountChanged || hasColumnChanged || hasScreenSizeChanged) {
      _lastLoggedGridItemCount = itemCount;
      _lastLoggedGridColumns = columns;
      _lastLoggedGridSize = screenSize;
      return true;
    }

    return false;
  }

  void _logMediaDebug(String message) {
    if (!kDebugMode) {
      return;
    }
    developer.log(message, name: 'MediaGridScreen');
  }

  void _pruneMediaItemKeys(Iterable<MediaEntity> media) {
    final validIds = media.map((item) => item.id).toSet();
    _mediaItemKeys.removeWhere((id, _) => !validIds.contains(id));
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
    if (_siblingNavigationTargets.length < 2 || _viewModel == null) {
      return;
    }

    final targetIndex = _currentDirectoryNavigationIndex + offset;
    if (targetIndex < 0 || targetIndex >= _siblingNavigationTargets.length) {
      return;
    }

    final target = _siblingNavigationTargets[targetIndex];
    _viewModel!.navigateToDirectory(
      target.path,
      target.name,
      bookmarkData: target.bookmarkData,
      siblingDirectories: _siblingNavigationTargets,
      currentIndex: targetIndex,
      replaceCurrentRoute: true,
    );
  }

  void _handleSiblingSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -100) {
      _navigateToSibling(1);
    } else if (velocity > 100) {
      _navigateToSibling(-1);
    }
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
            siblingDirectories: _siblingNavigationTargets,
            currentDirectoryIndex: _currentDirectoryNavigationIndex,
          ),
        ),
      );

      if (!context.mounted || result == null) return;

      _applyNavigationContext(
        result.siblingDirectories,
        result.currentDirectoryIndex,
        withSetState: true,
      );

      if (result.currentDirectory.path != widget.directoryPath) {
        _viewModel?.navigateToDirectory(
          result.currentDirectory.path,
          result.currentDirectory.name,
          bookmarkData: result.currentDirectory.bookmarkData,
          siblingDirectories: result.siblingDirectories,
          currentIndex: result.currentDirectoryIndex,
          replaceCurrentRoute: true,
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
            Text('Size: ${formatFileSize(media.size)}'),
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
        if (media.type == MediaType.image)
          PopupMenuItem(
            child: const Text('Use as Folder Cover'),
            onTap: () => unawaited(_useAsFolderCover(media)),
          ),
        if (_isMacOS) ...[
          PopupMenuItem(
            child: const Text('Move to…'),
            // Routed through the State's context, not the menu's: the menu is
            // gone by the time the destination picker opens.
            onTap: () => unawaited(_transferMedia(media, TransferMode.move)),
          ),
          PopupMenuItem(
            child: const Text('Copy to…'),
            onTap: () => unawaited(_transferMedia(media, TransferMode.copy)),
          ),
        ],
        // Delete option is handled by FileOperationButton
      ],
    );
  }

  /// The grid updates itself from the mutation the transfer publishes, so there
  /// is nothing to do here afterwards.
  Future<void> _transferMedia(MediaEntity media, TransferMode mode) {
    return pickDestinationAndTransferMedia(context, media, mode: mode);
  }

  Future<void> _handleCurrentDirectoryCoverAction(
    _CurrentDirectoryCoverAction action,
  ) async {
    switch (action) {
      case _CurrentDirectoryCoverAction.choose:
        await DirectoryCoverPickerDialog.show(
          context,
          directoryPath: widget.directoryPath,
          directoryName: widget.directoryName,
          bookmarkData: widget.bookmarkData,
        );
      case _CurrentDirectoryCoverAction.reset:
        await ref
            .read(
              directoryCoverControllerProvider(widget.directoryPath).notifier,
            )
            .resetCover();
    }
  }

  Future<void> _useAsFolderCover(MediaEntity media) async {
    await ref
        .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
        .setCover(media);
    if (!mounted) {
      return;
    }
    final result = ref.read(
      directoryCoverControllerProvider(widget.directoryPath),
    );
    result.when(
      data: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${media.name} is now the folder cover.')),
        );
      },
      loading: () {},
      error: (error, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set folder cover: $error')),
        );
      },
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (_isQuestionMark(event)) {
      unawaited(_showShortcutHelp());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  bool _isQuestionMark(KeyEvent event) {
    if (event.character == '?') {
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.slash) {
      final pressed = HardwareKeyboard.instance.logicalKeysPressed;
      return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
          pressed.contains(LogicalKeyboardKey.shiftRight);
    }

    return false;
  }

  Future<void> _showShortcutHelp() async {
    await ShortcutHelpOverlay.show(context);
    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ClearMediaSelectionIntent extends Intent {
  const _ClearMediaSelectionIntent();
}

enum _CurrentDirectoryCoverAction { choose, reset }

class _SelectAllMediaIntent extends Intent {
  const _SelectAllMediaIntent();
}

class _DeleteSelectedMediaIntent extends Intent {
  const _DeleteSelectedMediaIntent();
}

class _NavigateToPreviousDirectoryIntent extends Intent {
  const _NavigateToPreviousDirectoryIntent();
}

class _RefreshMediaIntent extends Intent {
  const _RefreshMediaIntent();
}

class _NavigateToNextDirectoryIntent extends Intent {
  const _NavigateToNextDirectoryIntent();
}

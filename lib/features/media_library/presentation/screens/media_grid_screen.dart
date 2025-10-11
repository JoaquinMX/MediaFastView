import 'dart:async';

import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/providers/grid_columns_provider.dart';

import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../tagging/presentation/widgets/bulk_tag_assignment_dialog.dart';
import '../../../tagging/presentation/widgets/tag_filter_chips.dart';
import '../../../tagging/presentation/widgets/tag_management_dialog.dart';
import '../../domain/entities/media_entity.dart';
import '../view_models/media_grid_view_model.dart';
import '../widgets/media_grid_item.dart';
import '../widgets/column_selector_popup.dart';

/// Screen for displaying media in a customizable grid layout.
class MediaGridScreen extends ConsumerStatefulWidget {
  const MediaGridScreen({
    super.key,
    required this.directoryPath,
    required this.directoryName,
    this.bookmarkData,
  });

  final String directoryPath;
  final String directoryName;
  final String? bookmarkData;

  @override
  ConsumerState<MediaGridScreen> createState() => _MediaGridScreenState();
}

class _MediaGridScreenState extends ConsumerState<MediaGridScreen> {
  MediaViewModelParams? _params;
  MediaViewModel? _viewModel;
  final GlobalKey _mediaGridOverlayKey = GlobalKey();
  final Map<String, GlobalKey> _mediaItemKeys = <String, GlobalKey>{};
  final ScrollController _mediaScrollController = ScrollController();
  Rect? _mediaSelectionRect;
  Offset? _mediaDragStart;
  bool _isMediaMarqueeActive = false;
  bool _mediaAppendMode = false;
  Set<String> _mediaMarqueeBaseSelection = <String>{};
  Set<String> _mediaLastMarqueeSelection = <String>{};
  Map<String, Rect> _mediaCachedItemRects = <String, Rect>{};
  Timer? _mediaAutoScrollTimer;
  double _mediaAutoScrollVelocity = 0;

  static const double _mediaAutoScrollEdgeExtent = 120;
  static const double _mediaAutoScrollMaxVelocity = 780;
  static const Duration _mediaAutoScrollTick = Duration(milliseconds: 16);

  @override
  void initState() {
    super.initState();
    _mediaScrollController.addListener(_onMediaGridScroll);
  }

  @override
  void dispose() {
    _mediaAutoScrollTimer?.cancel();
    _mediaScrollController.dispose();
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
      navigateToDirectory: (path, name, bookmarkData) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MediaGridScreen(
              directoryPath: path,
              directoryName: name,
              bookmarkData: bookmarkData,
            ),
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
    final sortOption = state is MediaLoaded
        ? state.sortOption
        : _viewModel?.currentSortOption ?? MediaSortOption.nameAscending;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.escape):
            _ClearMediaSelectionIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            _SelectAllMediaIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _SelectAllMediaIntent(),
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
          _SelectAllMediaIntent: CallbackAction<_SelectAllMediaIntent>(
            onInvoke: (_) {
              final params = _params;
              final viewModel = _viewModel;
              if (params == null || viewModel == null) {
                return null;
              }
              final state = ref.read(mediaViewModelProvider(params));
              if (state is MediaLoaded && state.media.isNotEmpty) {
                viewModel.selectAllMedia();
              }
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
                    _buildTagFilter(_viewModel!, state),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildNormalAppBar(MediaSortOption sortOption, MediaViewModel viewModel) {
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
    final favoriteActionLabel =
        _favoriteBulkActionLabel(favoritesState, selectedMediaIds);

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
          onPressed: state.media.isEmpty ||
                  selectedMediaIds.length == state.media.length
              ? null
              : viewModel.selectAllMedia,
          icon: const Icon(Icons.select_all),
          label: const Text('Select All'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
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
      final allSelectedAreFavorites =
          selectedMediaIds.every((id) => favoritesSet.contains(id));
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

  Widget _buildTagFilter(MediaViewModel viewModel, MediaState state) {
    final selectedTagIds = state is MediaLoaded
        ? state.selectedTagIds
        : const <String>[];

    return Container(
      padding: UiSpacing.tagFilterPadding,
      child: TagFilterChips(
        selectedTagIds: selectedTagIds,
        onSelectionChanged: viewModel.filterByTags,
        maxChipsToShow: UiGrid.maxFilterChips, // Limit to prevent overflow
      ),
    );
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

    final result = await favoritesViewModel.toggleFavoritesForMedia(selectedMedia);

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
        'Added $added and removed $removed favorites',
      (final added, _) when added > 0 =>
        'Added $added item${added == 1 ? '' : 's'} to favorites',
      (_, final removed) when removed > 0 =>
        'Removed $removed item${removed == 1 ? '' : 's'} from favorites',
      _ => 'No changes to favorites',
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildGrid(
    List<MediaEntity> media,
    int columns,
    MediaViewModel viewModel,
    Set<String> selectedMediaIds,
    bool isSelectionMode,
  ) {
    debugPrint(
      'MediaGridScreen: Building grid with ${media.length} items, $columns columns, screen size: ${MediaQuery.of(context).size}',
    );
    _pruneMediaItemKeys(media);
    final gridView = GridView.builder(
      padding: UiSpacing.gridPadding,
      controller: _mediaScrollController,
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
          onTap: () => _onMediaTap(context, mediaItem),
          onDoubleTap: () => _onMediaDoubleTap(context, mediaItem),
          onLongPress: () => _onMediaLongPress(context, mediaItem),
          onSecondaryTap: () => _onMediaSecondaryTap(context, mediaItem),
          onOperationComplete: () =>
              viewModel.loadMedia(), // Refresh after delete
          onSelectionToggle: () => viewModel.toggleMediaSelection(mediaItem.id),
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
        );
      },
    );
    return _buildMediaMarqueeWrapper(viewModel: viewModel, child: gridView);
  }

  Widget _buildMediaMarqueeWrapper({
    required Widget child,
    required MediaViewModel viewModel,
  }) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => _handleMediaPointerDown(event, viewModel),
      onPointerMove: (event) => _handleMediaPointerMove(event, viewModel),
      onPointerUp: (_) => _endMediaMarquee(),
      onPointerCancel: (_) => _endMediaMarquee(),
      child: Stack(
        key: _mediaGridOverlayKey,
        children: [
          Positioned.fill(child: child),
          if (_mediaSelectionRect != null)
            Positioned.fromRect(
              rect: _mediaSelectionRect!,
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

  void _handleMediaPointerDown(
    PointerDownEvent event,
    MediaViewModel viewModel,
  ) {
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }

    final overlayContext = _mediaGridOverlayKey.currentContext;
    if (overlayContext == null) {
      return;
    }
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) {
      return;
    }

    _mediaCachedItemRects = _computeMediaItemRects();
    final localPosition = overlayBox.globalToLocal(event.position);
    if (_isPointInsideAnyRect(localPosition, _mediaCachedItemRects.values)) {
      return;
    }

    final baseSelection = viewModel.selectedMediaIds;
    _mediaMarqueeBaseSelection = Set<String>.from(baseSelection);
    _mediaLastMarqueeSelection = Set<String>.from(baseSelection);
    _mediaAppendMode = _isMultiSelectModifierPressed();
    _isMediaMarqueeActive = true;
    _mediaDragStart = localPosition;

    setState(() {
      _mediaSelectionRect = Rect.fromPoints(localPosition, localPosition);
    });

    _updateMediaMarqueeSelection(viewModel);
  }

  void _handleMediaPointerMove(
    PointerMoveEvent event,
    MediaViewModel viewModel,
  ) {
    if (!_isMediaMarqueeActive || _mediaDragStart == null) {
      return;
    }

    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) == 0) {
      _endMediaMarquee();
      return;
    }

    final overlayContext = _mediaGridOverlayKey.currentContext;
    if (overlayContext == null) {
      return;
    }
    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) {
      return;
    }

    final localPosition = overlayBox.globalToLocal(event.position);
    setState(() {
      _mediaSelectionRect = Rect.fromPoints(_mediaDragStart!, localPosition);
    });

    _mediaCachedItemRects = _computeMediaItemRects();
    _updateMediaMarqueeSelection(viewModel);
    _updateMediaAutoScroll(localPosition, overlayBox.size);
  }

  void _endMediaMarquee() {
    if (!_isMediaMarqueeActive && _mediaSelectionRect == null) {
      return;
    }

    setState(() {
      _mediaSelectionRect = null;
    });
    _isMediaMarqueeActive = false;
    _mediaDragStart = null;
    _mediaAppendMode = false;
    _mediaMarqueeBaseSelection = <String>{};
    _mediaLastMarqueeSelection = <String>{};
    _mediaCachedItemRects = <String, Rect>{};
    _stopMediaAutoScroll();
  }

  void _updateMediaMarqueeSelection(MediaViewModel viewModel) {
    if (!_isMediaMarqueeActive) {
      return;
    }

    final selectionRect = _mediaSelectionRect;
    final rects = _mediaCachedItemRects;
    final intersectingIds = <String>{};

    if (selectionRect != null) {
      for (final entry in rects.entries) {
        if (entry.value.overlaps(selectionRect)) {
          intersectingIds.add(entry.key);
        }
      }
    }

    final desiredSelection = _mediaAppendMode
        ? {..._mediaMarqueeBaseSelection, ...intersectingIds}
        : intersectingIds;

    if (setEquals(desiredSelection, _mediaLastMarqueeSelection)) {
      return;
    }

    _mediaLastMarqueeSelection = desiredSelection;
    viewModel.selectMediaRange(desiredSelection, append: false);
  }

  Map<String, Rect> _computeMediaItemRects() {
    final overlayContext = _mediaGridOverlayKey.currentContext;
    if (overlayContext == null) {
      return <String, Rect>{};
    }

    final overlayBox = overlayContext.findRenderObject() as RenderBox?;
    if (overlayBox == null || !overlayBox.attached) {
      return <String, Rect>{};
    }

    final rects = <String, Rect>{};
    final staleKeys = <String>[];
    _mediaItemKeys.forEach((id, key) {
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
      _mediaItemKeys.remove(id);
    }

    return rects;
  }

  void _pruneMediaItemKeys(Iterable<MediaEntity> media) {
    final validIds = media.map((item) => item.id).toSet();
    _mediaItemKeys.removeWhere((id, _) => !validIds.contains(id));
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

  void _onMediaGridScroll() {
    if (!_isMediaMarqueeActive) {
      return;
    }
    final viewModel = _viewModel;
    if (viewModel == null) {
      return;
    }
    _mediaCachedItemRects = _computeMediaItemRects();
    _updateMediaMarqueeSelection(viewModel);
  }

  void _updateMediaAutoScroll(Offset localPosition, Size overlaySize) {
    if (!_isMediaMarqueeActive) {
      _stopMediaAutoScroll();
      return;
    }

    double velocity = 0;
    if (localPosition.dy < _mediaAutoScrollEdgeExtent) {
      final distance = (_mediaAutoScrollEdgeExtent - localPosition.dy)
          .clamp(0.0, _mediaAutoScrollEdgeExtent)
          .toDouble();
      velocity =
          -_mediaAutoScrollMaxVelocity * (distance / _mediaAutoScrollEdgeExtent);
    } else if (localPosition.dy >
        overlaySize.height - _mediaAutoScrollEdgeExtent) {
      final distance = (localPosition.dy -
              (overlaySize.height - _mediaAutoScrollEdgeExtent))
          .clamp(0.0, _mediaAutoScrollEdgeExtent)
          .toDouble();
      velocity =
          _mediaAutoScrollMaxVelocity * (distance / _mediaAutoScrollEdgeExtent);
    }

    _mediaAutoScrollVelocity = velocity;
    if (velocity == 0) {
      _stopMediaAutoScroll();
      return;
    }

    _startMediaAutoScroll();
  }

  void _startMediaAutoScroll() {
    _mediaAutoScrollTimer ??= Timer.periodic(_mediaAutoScrollTick, (_) {
      if (!_isMediaMarqueeActive || _mediaAutoScrollVelocity == 0) {
        _stopMediaAutoScroll();
        return;
      }
      if (!_mediaScrollController.hasClients) {
        return;
      }
      final position = _mediaScrollController.position;
      final delta =
          _mediaAutoScrollVelocity * (_mediaAutoScrollTick.inMilliseconds / 1000);
      final target = (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target == position.pixels) {
        _stopMediaAutoScroll();
        return;
      }
      _mediaScrollController.jumpTo(target);
      final viewModel = _viewModel;
      if (viewModel != null) {
        _mediaCachedItemRects = _computeMediaItemRects();
        _updateMediaMarqueeSelection(viewModel);
      }
    });
  }

  void _stopMediaAutoScroll() {
    _mediaAutoScrollVelocity = 0;
    _mediaAutoScrollTimer?.cancel();
    _mediaAutoScrollTimer = null;
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
      child: Container(
        padding: UiSpacing.dialogPadding,
        margin: UiSpacing.dialogMargin,
        decoration: BoxDecoration(
          color: UiColors.white,
          borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
          border: Border.all(
            color: UiColors.orange,
            width: UiSizing.borderWidth,
          ),
          boxShadow: [UiShadows.standard],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: UiSizing.iconHuge, color: UiColors.orange),
            SizedBox(height: UiSpacing.verticalGap),
            const Text(
              'Access to this directory has been revoked',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UiSpacing.smallGap),
            Text(
              'The permissions for "$directoryName" are no longer available.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            SizedBox(height: UiSpacing.smallGap),
            const Text(
              'This can happen when security-scoped bookmarks expire or when directory permissions change.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: UiSpacing.verticalGap * 1.5),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  await viewModel.recoverPermissions();
                  // Show success feedback
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permissions recovered successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  // Show error feedback
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
              icon: const Icon(Icons.folder_open),
              label: const Text('Re-select Directory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: UiColors.orange,
                foregroundColor: UiColors.white,
                padding: UiSpacing.buttonPadding,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  viewModel.loadMedia(), // Try refreshing without recovery
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            SizedBox(height: UiSpacing.verticalGap),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
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

  void _onMediaTap(BuildContext context, MediaEntity media) {
    if (media.type == MediaType.directory) {
      _viewModel!.navigateToDirectory(
        media.path,
        media.name,
        bookmarkData: media.bookmarkData,
      );
    } else {
      // Open full-screen viewer
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenViewerScreen(
            directoryPath: widget.directoryPath,
            initialMediaId: media.id,
            bookmarkData: widget.bookmarkData,
          ),
        ),
      );
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

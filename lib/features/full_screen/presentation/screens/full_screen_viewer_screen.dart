import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/models/directory_navigation_target.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/presentation/view_models/tags_view_model.dart';
import '../../domain/entities/viewer_state_entity.dart';
import '../models/full_screen_exit_result.dart';
import '../view_models/full_screen_view_model.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/full_screen_video_player.dart';
import '../widgets/full_screen_video_progress_slider.dart';
import '../../../../shared/widgets/media_playback_controls.dart';
import '../../../../shared/widgets/media_progress_indicator.dart';
import '../../../../shared/widgets/permission_issue_panel.dart';
import '../../../../shared/widgets/favorite_toggle_button.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/widgets/shortcut_help_overlay.dart';
import '../../../../shared/widgets/tag_overlay.dart';
import '../../../../shared/widgets/tag_selection_dialog.dart';
import '../../../../shared/utils/tag_mutation_service.dart';
import '../../../tagging/presentation/widgets/tag_creation_dialog.dart';

/// Full-screen media viewer screen
class FullScreenViewerScreen extends ConsumerStatefulWidget {
  const FullScreenViewerScreen({
    super.key,
    required this.directoryPath,
    this.directoryName,
    this.initialMediaId,
    this.bookmarkData,
    this.mediaList,
    this.siblingDirectories,
    this.currentDirectoryIndex,
  });

  final String directoryPath;
  final String? directoryName;
  final String? initialMediaId;
  final String? bookmarkData;
  final List<MediaEntity>? mediaList;
  final List<DirectoryNavigationTarget>? siblingDirectories;
  final int? currentDirectoryIndex;

  @override
  ConsumerState<FullScreenViewerScreen> createState() =>
      _FullScreenViewerScreenState();
}

class _FullScreenViewerScreenState
    extends ConsumerState<FullScreenViewerScreen> {
  bool _showControls = true;
  late final FullScreenViewModel _viewModel;
  Timer? _hideControlsTimer;
  final GlobalKey<FullScreenVideoPlayerState> _videoPlayerKey =
      GlobalKey<FullScreenVideoPlayerState>();
  late final FocusNode _focusNode;
  Offset? _swipeStartPosition;
  Offset? _swipeLatestPosition;
  int? _swipePointerId;
  Stopwatch? _swipeStopwatch;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _viewModel = ref.read(fullScreenViewModelProvider.notifier);
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    await _viewModel.initialize(
      widget.directoryPath,
      directoryName: widget.directoryName,
      initialMediaId: widget.initialMediaId,
      bookmarkData: widget.bookmarkData,
      mediaList: widget.mediaList,
      siblingDirectories: widget.siblingDirectories,
      currentDirectoryIndex: widget.currentDirectoryIndex,
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _videoPlayerKey.currentState?.stopPlayback();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fullScreenViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;

    debugPrint('FullScreenViewerScreen: Building with theme-aware UI elements, current theme brightness: ${Theme.of(context).brightness}');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Main content
            Positioned.fill(
              child: switch (state) {
                FullScreenInitial() => Center(
                  child: CircularProgressIndicator(color: colorScheme.onSurface),
                ),
                FullScreenLoading() => Center(
                  child: CircularProgressIndicator(color: colorScheme.onSurface),
                ),
                FullScreenLoaded() => _buildMediaContent(state),
                FullScreenPermissionRevoked() => _buildPermissionRevoked(),
                FullScreenError(message: final message) => Center(
                  child: Text(
                    message,
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              },
            ),

            // Overlay controls
            if (state is FullScreenLoaded && _showControls) ...[
              Positioned.fill(
                child: SafeArea(
                  top: true,
                  bottom: false,
                  child: Stack(
                    children: [
                      // Top bar with close button and favorite toggle
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: _popWithResult,
                                icon: Platform.isMacOS
                                    ? Icon(
                                        Icons.arrow_back,
                                        color: colorScheme.onSurface,
                                      )
                                    : Icon(
                                        Icons.close,
                                        color: colorScheme.onSurface,
                                      ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _showShortcutHelp,
                                icon: Icon(
                                  Icons.help_outline,
                                  color: colorScheme.onSurface,
                                ),
                                tooltip: 'Keyboard shortcuts (?)',
                              ),
                              FavoriteToggleButton(
                                isFavorite: state.isFavorite,
                                onToggle: () => _toggleFavoriteAndRefreshTags(),
                                iconSize: 28,
                                favoriteColor: colorScheme.error,
                                idleColor: colorScheme.onSurface,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Positioned(
                        top: 72,
                        left: 16,
                        right: 16,
                        child: _buildTagHeader(state),
                      ),

                      // Navigation arrows
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton(
                            onPressed: _handlePreviousNavigation,
                            icon: Icon(
                              Icons.chevron_left,
                              color: colorScheme.onSurface,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton(
                            onPressed: _handleNextNavigation,
                            icon: Icon(
                              Icons.chevron_right,
                              color: colorScheme.onSurface,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom controls for video
              if (state.currentMedia.type == MediaType.video)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SafeArea(
                      top: false,
                      child: _buildVideoControls(state),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(FullScreenLoaded state) {
    final media = state.currentMedia;
    final colorScheme = Theme.of(context).colorScheme;
    final isMobilePlatform = _isMobilePlatform();

    return Listener(
      onPointerDown: isMobilePlatform ? _handleSwipeStart : null,
      onPointerMove: isMobilePlatform ? _handleSwipeUpdate : null,
      onPointerUp: isMobilePlatform ? _handleSwipeEnd : null,
      onPointerCancel: isMobilePlatform ? _handleSwipeCancel : null,
      child: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onDoubleTap: () =>
            _popWithResult(), // Double-tap to exit full-screen
        onLongPress: () =>
            _showMediaInfo(media), // Long-press to show media info
        onSecondaryTap: () =>
            _showContextMenu(media), // Right-click context menu
        child: MouseRegion(
          onHover: (_) {
            _hideControlsTimer?.cancel();
            setState(() => _showControls = true);
          },
          onExit: (_) {
            _hideControlsTimer?.cancel();
            _hideControlsTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _showControls = false);
            });
          },
          child: switch (media.type) {
            MediaType.image => FullScreenImageViewer(media: media),
            MediaType.video => _buildVideoContent(media),
            MediaType.text => Center(
              child: Text(
                'Text file viewing not implemented',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
            MediaType.directory => Center(
              child: Text(
                'Directory viewing not supported',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildTagHeader(FullScreenLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;

    return TagOverlay(
      tags: state.allTags,
      selectedTagIds: state.currentMedia.tagIds.toSet(),
      onTagTapped: _handleTagChipTapped,
      trailing: IconButton.filledTonal(
        onPressed: () => _openTagEditor(state),
        icon: const Icon(Icons.add),
        tooltip: 'Add or edit tags',
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: colorScheme.primary.withOpacity(0.2),
        ),
      ),
    );
  }

  Widget _buildVideoControls(FullScreenLoaded state) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalItems = state.mediaList.length;
    final videoProgress = state.totalDuration.inMilliseconds > 0
        ? state.currentPosition.inMilliseconds /
            state.totalDuration.inMilliseconds
        : 0.0;
    final clampedProgress = videoProgress.clamp(0.0, 1.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalItems > 0)
          MediaProgressIndicator(
            currentIndex: state.currentIndex,
            totalItems: totalItems,
            showProgressBar: false,
            counterTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (totalItems > 0) const SizedBox(height: 12),
        MediaPlaybackControls(
          isPlaying: state.isPlaying,
          isLooping: state.isLooping,
          isMuted: state.isMuted,
          playbackSpeed: state.playbackSpeed,
          playbackSpeedOptions: const [1.0, 2.0, 2.5, 3.0, 4.0],
          onPlaybackSpeedSelected: _viewModel.setPlaybackSpeed,
          progress: clampedProgress,
          onPlayPause: _viewModel.togglePlayPause,
          onNext: _handleNextNavigation,
          onPrevious: _handlePreviousNavigation,
          onToggleLoop: _viewModel.toggleLoop,
          onToggleMute: _viewModel.toggleMute,
          visibility: const MediaPlaybackControlVisibility(
            showShuffle: false,
            showDurationSlider: false,
            showVideoLoop: false,
            showPlaybackSpeed: true,
          ),
          availability: MediaPlaybackControlAvailability(
            enablePrevious: state.currentIndex > 0 ||
                _viewModel.currentDirectoryIndex > 0,
            enablePlayPause: true,
            enableNext: state.currentIndex < totalItems - 1 ||
                _viewModel.currentDirectoryIndex <
                    (_viewModel.siblingDirectories.length - 1),
            enableLoop: true,
            enableShuffle: false,
            enableMute: true,
            enableDurationSlider: false,
            enableVideoLoop: false,
            enablePlaybackSpeed: true,
          ),
          style: MediaPlaybackControlStyle(
            iconTheme: const IconThemeData(color: Colors.white, size: 28),
            playPauseIconSize: 48,
            activeColor: colorScheme.primary,
            inactiveColor: Colors.white,
            durationLabelTextStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            sliderActiveTrackColor: colorScheme.primary,
            sliderInactiveTrackColor: Colors.white30,
            sliderThumbColor: Colors.white,
            sliderOverlayColor: Colors.white24,
            progressColor: colorScheme.primary,
            progressBackgroundColor: Colors.white24,
            controlSpacing: 16,
            sectionSpacing: 24,
            progressBarHeight: 56,
          ),
          progressBuilder: (context, progress, style) {
            return FullScreenVideoProgressSlider(
              progress: progress,
              currentPosition: state.currentPosition,
              totalDuration: state.totalDuration,
              onSeek: _handleSeek,
              style: style,
            );
          },
        ),
      ],
    );
  }

  void _showMediaInfo(MediaEntity media) {
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
            onPressed: _popWithResult,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(MediaEntity media) {
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: [
        PopupMenuItem(
          child: const Text('Info'),
          onTap: () => _showMediaInfo(media),
        ),
        PopupMenuItem(
          child: const Text('Favorite'),
          onTap: () => _toggleFavoriteAndRefreshTags(),
        ),
        // Add more menu items as needed
      ],
    );
  }

  Future<void> _toggleFavoriteAndRefreshTags() async {
    await _viewModel.toggleFavorite();
    await ref.read(tagsViewModelProvider.notifier).refreshFavorites();
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleTagChipTapped(TagEntity tag) async {
    try {
      final result = await _viewModel.toggleTagOnCurrentMedia(tag);
      if (!mounted) {
        return;
      }

      final message = switch (result.outcome) {
        TagMutationOutcome.added => 'Added "${tag.name}"',
        TagMutationOutcome.removed => 'Removed "${tag.name}"',
        TagMutationOutcome.unchanged => 'No changes to "${tag.name}"',
      };
      _showTagFeedback(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTagFeedback('Failed to update "${tag.name}": $error', isError: true);
    }
  }

  void _showTagFeedback(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final colorScheme = Theme.of(context).colorScheme;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleTagShortcut(TagEntity tag) async {
    await _handleTagChipTapped(tag);
  }

  bool _isPrimaryModifierPressed(Set<LogicalKeyboardKey> pressed) {
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  bool _isAltPressed(Set<LogicalKeyboardKey> pressed) {
    return pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
  }

  int? _digitLogicalKeyToIndex(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.digit1:
      case LogicalKeyboardKey.numpad1:
        return 0;
      case LogicalKeyboardKey.digit2:
      case LogicalKeyboardKey.numpad2:
        return 1;
      case LogicalKeyboardKey.digit3:
      case LogicalKeyboardKey.numpad3:
        return 2;
      case LogicalKeyboardKey.digit4:
      case LogicalKeyboardKey.numpad4:
        return 3;
      case LogicalKeyboardKey.digit5:
      case LogicalKeyboardKey.numpad5:
        return 4;
      case LogicalKeyboardKey.digit6:
      case LogicalKeyboardKey.numpad6:
        return 5;
      case LogicalKeyboardKey.digit7:
      case LogicalKeyboardKey.numpad7:
        return 6;
      case LogicalKeyboardKey.digit8:
      case LogicalKeyboardKey.numpad8:
        return 7;
      case LogicalKeyboardKey.digit9:
      case LogicalKeyboardKey.numpad9:
        return 8;
      case LogicalKeyboardKey.digit0:
      case LogicalKeyboardKey.numpad0:
        return 9;
      default:
        return null;
    }
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

  Widget _buildVideoContent(MediaEntity media) {
    final currentState = ref.watch(fullScreenViewModelProvider);
    final colorScheme = Theme.of(context).colorScheme;
    if (currentState is! FullScreenLoaded) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.onSurface),
      );
    }

    return FullScreenVideoPlayer(
      key: _videoPlayerKey,
      media: media,
      isPlaying: currentState.isPlaying,
      isMuted: currentState.isMuted,
      isLooping: currentState.isLooping,
      playbackSpeed: currentState.playbackSpeed,
      onPositionUpdate: _viewModel.updateVideoPosition,
      onDurationUpdate: _viewModel.updateVideoDuration,
      onPlayingStateUpdate: _viewModel.updatePlayingState,
    );
  }

  void _handleSeek(Duration position) {
    _videoPlayerKey.currentState?.seekTo(position);
    _viewModel.seekTo(position);
  }

  bool _isMobilePlatform() {
    return Platform.isAndroid || Platform.isIOS;
  }

  void _handleSwipeStart(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch || _swipePointerId != null) {
      return;
    }

    _swipePointerId = event.pointer;
    _swipeStartPosition = event.position;
    _swipeLatestPosition = event.position;
    _swipeStopwatch = Stopwatch()..start();
  }

  void _handleSwipeUpdate(PointerMoveEvent event) {
    if (event.pointer != _swipePointerId) {
      return;
    }

    _swipeLatestPosition = event.position;
  }

  void _handleSwipeEnd(PointerUpEvent event) {
    if (event.pointer != _swipePointerId) {
      return;
    }

    final start = _swipeStartPosition;
    final end = _swipeLatestPosition ?? event.position;
    final elapsedMs = _swipeStopwatch?.elapsedMilliseconds ?? 0;
    _resetSwipeTracking();

    if (start == null || elapsedMs == 0) {
      return;
    }

    final delta = end - start;
    final absDx = delta.dx.abs();
    final absDy = delta.dy.abs();
    final velocity = delta.distance / elapsedMs;
    const minSwipeDistance = 90.0;
    const minSwipeVelocity = 0.25;

    if (absDx > absDy &&
        absDx > minSwipeDistance &&
        velocity > minSwipeVelocity) {
      if (delta.dx < 0) {
        unawaited(_handleNextNavigation());
      } else {
        unawaited(_handlePreviousNavigation());
      }
      return;
    }

    if (delta.dy > minSwipeDistance &&
        absDy > absDx &&
        velocity > minSwipeVelocity) {
      _popWithResult();
    }
  }

  void _handleSwipeCancel(PointerCancelEvent event) {
    if (event.pointer != _swipePointerId) {
      return;
    }

    _resetSwipeTracking();
  }

  void _resetSwipeTracking() {
    _swipePointerId = null;
    _swipeStartPosition = null;
    _swipeLatestPosition = null;
    _swipeStopwatch?.stop();
    _swipeStopwatch = null;
  }

  Future<void> _promptDirectoryNavigation(
    DirectoryNavigationTarget target, {
    required bool forward,
  }) async {
    final directionLabel = forward ? 'next' : 'previous';
    final shouldNavigate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Continue to sibling directory?'),
            content: Text(
              'You have reached the ${forward ? 'end' : 'beginning'} of this directory. Go to the $directionLabel directory "${target.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Go'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldNavigate) {
      await _viewModel.navigateToDirectoryTarget(
        target,
        startAtEnd: !forward,
      );
    }
  }

  Future<void> _handleNextNavigation() async {
    final navigationResult = await _viewModel.nextMedia();
    if (!navigationResult.mediaAdvanced &&
        navigationResult.hasDirectoryOption &&
        navigationResult.directoryTarget != null) {
      await _handleSiblingDirectoryNavigation(
        navigationResult.directoryTarget!,
        forward: true,
      );
    }
  }

  Future<void> _handlePreviousNavigation() async {
    final navigationResult = await _viewModel.previousMedia();
    if (!navigationResult.mediaAdvanced &&
        navigationResult.hasDirectoryOption &&
        navigationResult.directoryTarget != null) {
      await _handleSiblingDirectoryNavigation(
        navigationResult.directoryTarget!,
        forward: false,
      );
    }
  }

  Future<void> _handleSiblingDirectoryNavigation(
    DirectoryNavigationTarget target, {
    required bool forward,
  }) async {
    final autoNavigate = ref.read(autoNavigateSiblingDirectoriesProvider);
    if (autoNavigate) {
      await _viewModel.navigateToDirectoryTarget(
        target,
        startAtEnd: !forward,
      );
      return;
    }

    await _promptDirectoryNavigation(
      target,
      forward: forward,
    );
  }

  void _popWithResult() {
    _videoPlayerKey.currentState?.stopPlayback();
    final currentDirectory = _viewModel.currentDirectory;
    if (currentDirectory == null) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(
      FullScreenExitResult(
        currentDirectory: currentDirectory,
        currentDirectoryIndex: _viewModel.currentDirectoryIndex,
        siblingDirectories: _viewModel.siblingDirectories,
      ),
    );
  }

  Future<void> _openTagEditor(FullScreenLoaded state) async {
    final result = await showDialog<TagUpdateResult>(
      context: context,
      builder: (context) => TagSelectionDialog<TagUpdateResult>(
        title: 'Edit Tags',
        assignmentTargetLabel: 'Assign tags to "${state.currentMedia.name}"',
        initialSelectedTagIds: state.currentMedia.tagIds,
        onConfirm: (selectedIds) =>
            _viewModel.setTagsForCurrentMedia(selectedIds),
        confirmLabel: 'Save Tags',
        cancelLabel: 'Close',
        cancelResult: null,
        showCreateButton: true,
        onCreateTag: (context) => TagCreationDialog.show(context),
        showDeleteButtons: false,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    final message = (result.addedCount == 0 && result.removedCount == 0)
        ? 'No tag changes applied'
        : 'Updated tags (${result.addedCount} added, ${result.removedCount} removed)';
    _showTagFeedback(message);
  }

  Widget _buildPermissionRevoked() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: PermissionIssuePanel(
        message: 'The permissions for this directory are no longer available.',
        helpText:
            'This can happen when security-scoped bookmarks expire or when directory permissions change.',
        footerText:
            'Return to the media grid and re-select the directory to restore full access.',
        recoverLabel: 'Try to Recover',
        recoverIcon: Icons.refresh,
        backLabel: 'Back to Grid',
        backIcon: Icons.arrow_back,
        accentColor: colorScheme.error,
        backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
        borderColor: colorScheme.error,
        onRecover: () async {
          final directory = _viewModel.currentDirectory;
          final success = await _viewModel.attemptPermissionRecovery(
            directory?.path ?? widget.directoryPath,
            bookmarkData: directory?.bookmarkData ?? widget.bookmarkData,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? 'Access recovered successfully!'
                      : 'Recovery failed. Please go back and re-select the directory.',
                ),
                backgroundColor:
                    success ? colorScheme.primary : colorScheme.error,
              ),
            );
          }
        },
        onBack: _popWithResult,
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isQuestionMark(event)) {
      unawaited(_showShortcutHelp());
      return KeyEventResult.handled;
    }

    final state = ref.read(fullScreenViewModelProvider);
    if (state is! FullScreenLoaded) return KeyEventResult.ignored;

    final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
    if (_isPrimaryModifierPressed(pressedKeys) && _isAltPressed(pressedKeys)) {
      final shortcutIndex = _digitLogicalKeyToIndex(event.logicalKey);
      if (shortcutIndex != null && shortcutIndex < state.shortcutTags.length) {
        unawaited(_handleTagShortcut(state.shortcutTags[shortcutIndex]));
        return KeyEventResult.handled;
      }
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        _popWithResult();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        unawaited(_handlePreviousNavigation());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        unawaited(_handleNextNavigation());
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        if (state.mediaList.isNotEmpty) {
          _viewModel.goToMedia(0);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        if (state.mediaList.isNotEmpty) {
          _viewModel.goToMedia(state.mediaList.length - 1);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        final newIndex = (state.currentIndex - 10).clamp(
          0,
          state.mediaList.length - 1,
        );
        _viewModel.goToMedia(newIndex);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        final newIndex = (state.currentIndex + 10).clamp(
          0,
          state.mediaList.length - 1,
        );
        _viewModel.goToMedia(newIndex);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
        if (state.currentMedia.type == MediaType.video) {
          _viewModel.togglePlayPause();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        if (state.currentMedia.type == MediaType.video) {
          _viewModel.toggleMute();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyL:
        if (state.currentMedia.type == MediaType.video) {
          _viewModel.toggleLoop();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        _toggleFavoriteAndRefreshTags();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyI:
        _showMediaInfo(state.currentMedia);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f11:
        // Toggle full-screen (though already full-screen, could toggle immersive mode)
        setState(() => _showControls = !_showControls);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }
}

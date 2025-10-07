import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/viewer_state_entity.dart';
import '../view_models/full_screen_view_model.dart';
import '../widgets/full_screen_favorite_toggle.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/full_screen_video_controls.dart';
import '../widgets/full_screen_video_player.dart';

/// Full-screen media viewer screen
class FullScreenViewerScreen extends ConsumerStatefulWidget {
  const FullScreenViewerScreen({
    super.key,
    required this.directoryPath,
    this.initialMediaId,
    this.bookmarkData,
    this.mediaList,
  });

  final String directoryPath;
  final String? initialMediaId;
  final String? bookmarkData;
  final List<MediaEntity>? mediaList;

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

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(fullScreenViewModelProvider.notifier);
    _initializeViewer();
  }

  Future<void> _initializeViewer() async {
    await _viewModel.initialize(
      widget.directoryPath,
      initialMediaId: widget.initialMediaId,
      bookmarkData: widget.bookmarkData,
      mediaList: widget.mediaList,
    );
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
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
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Platform.isMacOS
                            ? Icon(Icons.arrow_back, color: colorScheme.onSurface)
                            : Icon(Icons.close, color: colorScheme.onSurface),
                      ),
                      const Spacer(),
                      FullScreenFavoriteToggle(
                        isFavorite: state.isFavorite,
                        onToggle: _viewModel.toggleFavorite,
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
                    child: FullScreenVideoControls(
                      isPlaying: state.isPlaying,
                      isMuted: state.isMuted,
                      isLooping: state.isLooping,
                      currentPosition: state.currentPosition,
                      totalDuration: state.totalDuration,
                      onPlayPause: _viewModel.togglePlayPause,
                      onMute: _viewModel.toggleMute,
                      onLoop: _viewModel.toggleLoop,
                      onSeek: _handleSeek,
                    ),
                  ),
                ),

              // Navigation arrows
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: state.currentIndex > 0
                        ? _viewModel.previousMedia
                        : null,
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
                    onPressed: state.currentIndex < state.mediaList.length - 1
                        ? _viewModel.nextMedia
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurface,
                      size: 48,
                    ),
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

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      onDoubleTap: () =>
          Navigator.of(context).pop(), // Double-tap to exit full-screen
      onLongPress: () => _showMediaInfo(media), // Long-press to show media info
      onSecondaryTap: () => _showContextMenu(media), // Right-click context menu
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
            onPressed: () => Navigator.of(context).pop(),
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
          onTap: () => _viewModel.toggleFavorite(),
        ),
        // Add more menu items as needed
      ],
    );
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
      onPositionUpdate: _viewModel.updateVideoPosition,
      onDurationUpdate: _viewModel.updateVideoDuration,
      onPlayingStateUpdate: _viewModel.updatePlayingState,
    );
  }

  void _handleSeek(Duration position) {
    _videoPlayerKey.currentState?.seekTo(position);
    _viewModel.seekTo(position);
  }

  Widget _buildPermissionRevoked() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.error, width: 2),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Access to this directory has been revoked',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The permissions for this directory are no longer available.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This can happen when security-scoped bookmarks expire or when directory permissions change.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // Try to recover permissions using the view model
                final success = await _viewModel.attemptPermissionRecovery(
                  widget.directoryPath,
                  bookmarkData: widget.bookmarkData,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Access recovered successfully!' : 'Recovery failed. Please go back and re-select the directory.'),
                      backgroundColor: success ? colorScheme.primary : colorScheme.error,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try to Recover'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Grid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.secondary,
                foregroundColor: colorScheme.onSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Return to the media grid and re-select the directory to restore full access.',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final state = ref.read(fullScreenViewModelProvider);
    if (state is! FullScreenLoaded) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        if (state.currentIndex > 0) {
          _viewModel.previousMedia();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        if (state.currentIndex < state.mediaList.length - 1) {
          _viewModel.nextMedia();
        }
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
        _viewModel.toggleFavorite();
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../view_models/slideshow_view_model.dart';
import '../widgets/slideshow_controls.dart';
import '../widgets/slideshow_video_player.dart';

/// Full-screen slideshow screen for viewing favorite media items.
class SlideshowScreen extends ConsumerStatefulWidget {
  const SlideshowScreen({super.key, required this.mediaList});

  final List<MediaEntity> mediaList;

  @override
  ConsumerState<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends ConsumerState<SlideshowScreen> {
  late final FocusNode _focusNode;
  bool _areControlsVisible = true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Enable fullscreen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(slideshowViewModelProvider(widget.mediaList));
    final slideshowViewModel = ref.read(
      slideshowViewModelProvider(widget.mediaList).notifier,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main content area
            _buildSlideshowContent(viewModel, slideshowViewModel),

            // Controls overlay
            if (_areControlsVisible)
              _buildControlsOverlay(viewModel, slideshowViewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideshowContent(
    SlideshowState state,
    SlideshowViewModel viewModel,
  ) {
    final currentMedia = viewModel.currentMedia;

    if (currentMedia == null) {
      return const Center(
        child: Text(
          'No media to display',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleControlsVisibility,
      child: Container(
        color: Colors.black,
        child: Center(
          child: _buildMediaContent(currentMedia, viewModel),
        ),
      ),
    );
  }

  Widget _buildMediaContent(MediaEntity media, SlideshowViewModel viewModel) {
    if (media.type == MediaType.video) {
      return SlideshowVideoPlayer(
        media: media,
        isPlaying: viewModel.isPlaying,
        isMuted: viewModel.isMuted,
        isLooping: viewModel.isLooping,
        onProgress: viewModel.updateProgress,
        onCompleted: viewModel.nextItem,
      );
    }

    return SizedBox.expand(
      child: Image.file(
        File(media.path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.image, size: 64, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlsOverlay(
    SlideshowState state,
    SlideshowViewModel viewModel,
  ) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Progress indicator
              _buildProgressIndicator(state, viewModel),

              const SizedBox(height: 16),

              // Controls
              SlideshowControls(
                state: state,
                onPlayPause: _handlePlayPause,
                onNext: viewModel.nextItem,
                onPrevious: viewModel.previousItem,
                onToggleLoop: viewModel.toggleLoop,
                onToggleMute: viewModel.toggleMute,
                onToggleShuffle: viewModel.toggleShuffle,
                onDurationSelected: viewModel.setImageDisplayDuration,
                showProgressBar:
                    viewModel.currentMedia?.type == MediaType.video,
              ),

              const SizedBox(height: 16),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close slideshow',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(
    SlideshowState state,
    SlideshowViewModel viewModel,
  ) {
    final currentIndex = viewModel.currentIndex;
    final totalItems = viewModel.totalItems;

    return Column(
      children: [
        // Item counter
        Text(
          '${currentIndex + 1} / $totalItems',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 8),

        // Progress bar
        LinearProgressIndicator(
          value: totalItems > 0 ? (currentIndex + 1) / totalItems : 0,
          backgroundColor: Colors.white.withValues(alpha: 0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ],
    );
  }

  void _toggleControlsVisibility() {
    setState(() => _areControlsVisible = !_areControlsVisible);
  }

  void _handlePlayPause() {
    final viewModel = ref.read(
      slideshowViewModelProvider(widget.mediaList).notifier,
    );
    final state = ref.read(slideshowViewModelProvider(widget.mediaList));

    if (state is SlideshowPlaying) {
      viewModel.pauseSlideshow();
    } else if (state is SlideshowPaused) {
      viewModel.resumeSlideshow();
    } else {
      viewModel.startSlideshow();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final viewModel = ref.read(
      slideshowViewModelProvider(widget.mediaList).notifier,
    );

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.space:
        viewModel.nextItem();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        viewModel.previousItem();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyP:
        _handlePlayPause();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyL:
        viewModel.toggleLoop();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyM:
        viewModel.toggleMute();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyS:
        viewModel.toggleShuffle();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }
}

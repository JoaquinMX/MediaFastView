import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/core/config/app_config.dart';
import 'package:media_fast_view/shared/providers/slideshow_controls_hide_delay_provider.dart';

import '../../../media_library/domain/entities/media_entity.dart';

import '../view_models/slideshow_view_model.dart';
import '../widgets/slideshow_overlay.dart';
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
  Timer? _controlsHideTimer;
  Duration _controlsHideDelay = AppConfig.defaultSlideshowControlsHideDelay;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Enable fullscreen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _controlsHideDelay = ref.read(slideshowControlsHideDelayProvider);
    _restartControlsHideTimer();
  }

  @override
  void dispose() {
    _controlsHideTimer?.cancel();
    _focusNode.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(slideshowViewModelProvider(widget.mediaList));
    final slideshowViewModel = ref.read(
      slideshowViewModelProvider(widget.mediaList).notifier,
    );
    ref.listen<Duration>(slideshowControlsHideDelayProvider, (previous, next) {
      _controlsHideDelay = next;
      _restartControlsHideTimer();
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          cursor: _shouldHideMouse
              ? SystemMouseCursors.none
              : SystemMouseCursors.basic,
          onEnter: (_) => _handlePointerActivity(),
          onHover: (_) => _handlePointerActivity(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Main content area
              _buildSlideshowContent(state, slideshowViewModel),

              // Controls overlay
              if (_areControlsVisible)
                SlideshowOverlay(
                  state: state,
                  viewModel: slideshowViewModel,
                  onClose: () => Navigator.of(context).pop(),
                  onPlayPause: _handlePlayPause,
                ),
            ],
          ),
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
        child: Center(child: _buildMediaContent(currentMedia, viewModel)),
      ),
    );
  }

  Widget _buildMediaContent(MediaEntity media, SlideshowViewModel viewModel) {
    if (media.type == MediaType.video) {
      return SlideshowVideoPlayer(
        media: media,
        isPlaying: viewModel.isPlaying,
        isMuted: viewModel.isMuted,
        isVideoLooping: viewModel.isVideoLooping,
        playbackSpeed: viewModel.playbackSpeed,
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

  void _toggleControlsVisibility() {
    if (_areControlsVisible) {
      _controlsHideTimer?.cancel();
      setState(() => _areControlsVisible = false);
    } else {
      setState(() => _areControlsVisible = true);
      _restartControlsHideTimer();
    }
  }

  void _handlePointerActivity() {
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _restartControlsHideTimer();
  }

  bool get _shouldHideMouse =>
      !_areControlsVisible &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  void _restartControlsHideTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(_controlsHideDelay, () {
      if (mounted) {
        setState(() => _areControlsVisible = false);
      }
    });
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

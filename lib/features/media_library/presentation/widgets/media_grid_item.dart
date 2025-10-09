import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/thumbnail_caching_provider.dart';
import '../../../../shared/widgets/file_operation_button.dart';
import '../../../favorites/presentation/widgets/favorite_toggle_button.dart';
import '../../../tagging/presentation/widgets/tag_management_dialog.dart';
import '../../domain/entities/media_entity.dart';

/// Widget for displaying a media item in the grid.
class MediaGridItem extends StatefulWidget {
  const MediaGridItem({
    super.key,
    required this.media,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onOperationComplete,
    this.onFavoriteToggle,
  });

  final MediaEntity media;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onOperationComplete;
  final ValueChanged<bool>? onFavoriteToggle;

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem> {
  bool _isHovering = false;
  VideoPlayerController? _videoController;

  @override
  void dispose() {
    _disposeVideoController();
    super.dispose();
  }

  Future<void> _initializeVideoController() async {
    if (_videoController != null) return;
    _videoController = VideoPlayerController.file(File(widget.media.path));
    await _videoController!.initialize();
    _videoController!.setVolume(0.0); // Mute for preview
    _videoController!.setLooping(true);
    _videoController!.play();
    setState(() {});
  }

  Future<void> _disposeVideoController() async {
    if (_videoController != null) {
      await _videoController!.pause();
      await _videoController!.dispose();
      _videoController = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MediaGridItem: Building item for ${widget.media.name}, type: ${widget.media.type}, size: ${MediaQuery.of(context).size}');
    return Consumer(
      builder: (context, ref, child) {
        return MouseRegion(
          onEnter: (_) async {
            setState(() => _isHovering = true);
            if (widget.media.type == MediaType.video) {
              await _initializeVideoController();
            }
          },
          onExit: (_) async {
            setState(() => _isHovering = false);
            await _disposeVideoController();
          },
          child: GestureDetector(
            onTap: widget.onTap,
            onDoubleTap: widget.onDoubleTap,
            onLongPress: widget.onLongPress,
            onSecondaryTap: widget.onSecondaryTap,
            child: Card(
              elevation: _isHovering
                  ? UiSizing.elevationHigh
                  : UiSizing.elevationLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  UiSizing.borderRadiusMedium,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    _buildMediaContent(ref),
                    if (_isHovering) _buildHoverOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHoverOverlay() {
    return Positioned(
      top: UiPosition.overlayTop,
      right: UiPosition.overlayRight,
      child: Container(
        padding: UiSpacing.smallPadding,
        decoration: BoxDecoration(
          color: UiColors.blackOverlay,
          borderRadius: BorderRadius.circular(UiSizing.borderRadiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FavoriteToggleButton(
              media: widget.media,
              onToggle: widget.onFavoriteToggle,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.tag, color: Colors.white),
              onPressed: () =>
                  TagManagementDialog.show(context, media: widget.media),
              tooltip: 'Manage tags',
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            ),
            const SizedBox(width: 4),
            FileOperationButton(
              media: widget.media,
              onOperationComplete: widget.onOperationComplete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(WidgetRef ref) {
    switch (widget.media.type) {
      case MediaType.image:
        return _buildImageContent(ref);
      case MediaType.video:
        return _buildVideoContent();
      case MediaType.text:
        return _buildTextContent();
      case MediaType.audio:
        return _buildAudioContent();
      case MediaType.document:
        return _buildDocumentContent();
      case MediaType.directory:
        return _buildDirectoryContent(ref);
    }
  }

  Widget _buildImageContent(WidgetRef ref) {
    final isCachingEnabled = ref.watch(thumbnailCachingProvider);
    return Image.file(
      File(widget.media.path),
      fit: BoxFit.cover,
      cacheWidth: isCachingEnabled ? 200 : null,
      cacheHeight: isCachingEnabled ? 200 : null,
      errorBuilder: (context, error, stackTrace) {
        debugPrint('Image load failed for ${widget.media.name}: $error');
        return _buildErrorContent();
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame == null) {
          return _buildLoadingContent();
        }
        return child;
      },
    );
  }

  Widget _buildAudioContent() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          Icons.audiotrack,
          size: UiSizing.iconExtraLarge,
          color: UiColors.whiteOverlay,
        ),
      ),
    );
  }

  Widget _buildDocumentContent() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: Icon(
          Icons.picture_as_pdf,
          size: UiSizing.iconExtraLarge,
          color: UiColors.whiteOverlay,
        ),
      ),
    );
  }


  Widget _buildVideoContent() {
    if (_isHovering && _videoController != null && _videoController!.value.isInitialized) {
      return VideoPlayer(_videoController!);
    } else {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.video_file,
            size: UiSizing.iconExtraLarge,
            color: UiColors.whiteOverlay,
          ),
        ),
      );
    }
  }

  Widget _buildTextContent() {
    return Container(
      padding: UiSpacing.gridPadding,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: FutureBuilder<String>(
        future: _loadTextPreview(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorContent();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.media.name,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: UiContent.maxLinesSingle,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: UiSpacing.smallGap),
              Expanded(
                child: Text(
                  snapshot.data ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: UiContent.maxLinesBody,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDirectoryContent(WidgetRef ref) {
    final previewAsync = ref.watch(directoryPreviewProvider(widget.media.path));
    final isCachingEnabled = ref.watch(thumbnailCachingProvider);
    return previewAsync.when(
      data: (String? previewPath) {
        debugPrint(
          'Directory ${widget.media.name}: preview path: $previewPath',
        );
        return Column(
          children: [
            Expanded(
              flex: UiGrid.directoryPreviewFlex,
              child: previewPath != null
                  ? Image.file(
                      File(previewPath),
                      fit: BoxFit.cover,
                      cacheWidth: isCachingEnabled ? 200 : null,
                      cacheHeight: isCachingEnabled ? 200 : null,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint(
                          'Error loading preview image for ${widget.media.name}: $error',
                        );
                        return Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Center(
                            child: Icon(
                              Icons.folder,
                              size: UiSizing.iconExtraLarge,
                              color: UiColors.whiteOverlay,
                            ),
                          ),
                        );
                      },
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (frame == null) {
                          return _buildLoadingContent();
                        }
                        return child;
                      },
                    )
                  : Container(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.folder,
                          size: UiSizing.iconExtraLarge,
                          color: UiColors.whiteOverlay,
                        ),
                      ),
                    ),
            ),
            Expanded(
              flex: UiGrid.directoryNameFlex,
              child: Container(
                alignment: Alignment.center,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: UiSpacing.horizontalSmall,
                child: Text(
                  widget.media.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: UiContent.maxLinesSingle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        );
      },
      loading: () {
        debugPrint('Loading preview for ${widget.media.name}');
        return _buildLoadingContent();
      },
      error: (error, stack) {
        debugPrint('Error getting preview for ${widget.media.name}: $error');
        return _buildErrorContent();
      },
    );
  }

  Widget _buildLoadingContent() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorContent() {
    return Container(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Icon(Icons.error, color: UiColors.red, size: UiSizing.iconLarge),
      ),
    );
  }

  Future<String> _loadTextPreview() async {
    try {
      final file = File(widget.media.path);
      final content = await file.readAsString();
      // Return first N characters as preview
      return content.length > UiContent.textPreviewMaxLength
          ? '${content.substring(0, UiContent.textPreviewMaxLength)}...'
          : content;
    } catch (e) {
      throw Exception('Failed to load text file');
    }
  }
}

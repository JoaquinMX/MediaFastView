import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
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
    required this.onSelectionToggle,
    required this.isSelected,
    required this.isSelectionMode,
  });

  final MediaEntity media;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final VoidCallback? onOperationComplete;
  final ValueChanged<bool>? onFavoriteToggle;
  final VoidCallback onSelectionToggle;
  final bool isSelected;
  final bool isSelectionMode;

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem> {
  bool _isHovering = false;
  VideoPlayerController? _videoController;
  Future<String>? _textPreviewFuture;

  @override
  void initState() {
    super.initState();
    _initializeTextPreviewFuture();
  }

  @override
  void didUpdateWidget(covariant MediaGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.path != widget.media.path ||
        oldWidget.media.type != widget.media.type) {
      _initializeTextPreviewFuture();
    }
  }

  void _initializeTextPreviewFuture() {
    if (widget.media.type == MediaType.text) {
      _textPreviewFuture = _loadTextPreview();
    } else {
      _textPreviewFuture = null;
    }
  }

  void _ensureSelected() {
    if (!widget.isSelected) {
      widget.onSelectionToggle();
    }
  }

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
    return Consumer(
      builder: (context, ref, child) {
        return VisibilityDetector(
          key: Key('media-grid-${widget.media.id}'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 0) {
              _disposeVideoController();
              if (_isHovering) {
                setState(() => _isHovering = false);
              }
            }
          },
          child: MouseRegion(
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
              onLongPress: () {
                _ensureSelected();
                widget.onLongPress?.call();
              },
              onSecondaryTap: () {
                _ensureSelected();
                widget.onSecondaryTap?.call();
              },
              child: Card(
                elevation: _isHovering
                    ? UiSizing.elevationHigh
                    : UiSizing.elevationLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UiSizing.borderRadiusMedium,
                  ),
                  side: widget.isSelected
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: UiSizing.borderWidth,
                        )
                      : BorderSide.none,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      _buildMediaContent(ref),
                      if (_isHovering) _buildHoverOverlay(),
                      if (widget.isSelectionMode || widget.isSelected)
                        Positioned(
                          top: UiSpacing.extraSmallGap,
                          left: UiSpacing.extraSmallGap,
                          child: Semantics(
                            selected: widget.isSelected,
                            button: true,
                            label: widget.isSelected
                                ? 'Deselect media ${widget.media.name}'
                                : 'Select media ${widget.media.name}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: widget.onSelectionToggle,
                                borderRadius: BorderRadius.circular(
                                  UiSizing.borderRadiusSmall,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: widget.isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(
                                      UiSizing.borderRadiusSmall,
                                    ),
                                    border: Border.all(
                                      color: widget.isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                      width: UiSizing.borderWidth / 1.5,
                                    ),
                                  ),
                                  padding: EdgeInsets.all(
                                    UiSpacing.extraSmallGap / 2,
                                  ),
                                  child: Icon(
                                    widget.isSelected
                                        ? Icons.check
                                        : Icons.circle_outlined,
                                    size: UiSizing.iconExtraSmall,
                                    color: widget.isSelected
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onPrimary
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
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

  Widget _buildVideoContent() {
    if (_isHovering &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
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
        future: _textPreviewFuture,
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
                      frameBuilder:
                          (context, child, frame, wasSynchronouslyLoaded) {
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
        return _buildLoadingContent();
      },
      error: (error, stack) {
        if (kDebugMode) {
          debugPrint('Error getting preview for ${widget.media.name}: $error');
        }
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
      if (kDebugMode) {
        debugPrint('Failed to load text preview for ${widget.media.path}: $e');
      }
      throw Exception('Failed to load text file');
    }
  }
}

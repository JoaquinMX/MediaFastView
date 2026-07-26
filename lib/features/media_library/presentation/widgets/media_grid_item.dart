import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/widgets/file_operation_button.dart';
import '../../../../shared/widgets/move_copy_button.dart';
import '../../../favorites/presentation/widgets/favorite_toggle_button.dart';
import '../../../tagging/presentation/widgets/tag_management_dialog.dart';
import '../../../thumbnails/presentation/media_thumbnail.dart';
import '../../domain/entities/directory_media_counts.dart';
import '../../domain/entities/media_entity.dart';
import 'directory_thumbnail.dart';

/// Widget for displaying a media item in the grid.
class MediaGridItem extends StatefulWidget {
  const MediaGridItem({
    super.key,
    required this.media,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onFavoriteToggle,
    this.bookmarkData,
    required this.onSelectionToggle,
    required this.isSelected,
    required this.isSelectionMode,
    this.isHighlighted = false,
  });

  final MediaEntity media;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final ValueChanged<bool>? onFavoriteToggle;
  final String? bookmarkData;
  final VoidCallback onSelectionToggle;
  final bool isSelected;
  final bool isSelectionMode;

  /// Momentarily calls the item out after the user was brought here to find it
  /// ("go to directory"). Deliberately distinct from [isSelected], which means
  /// multi-select and is driven by the user rather than by navigation.
  final bool isHighlighted;

  @override
  State<MediaGridItem> createState() => _MediaGridItemState();
}

class _MediaGridItemState extends State<MediaGridItem> {
  bool _isHovering = false;
  VideoPlayerController? _videoController;
  String? _activeVideoBookmark;
  int _videoSession = 0;
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
      unawaited(_disposeVideoController());
      _initializeTextPreviewFuture();
      if (_isHovering && widget.media.type == MediaType.video) {
        unawaited(_initializeVideoController());
      }
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
    unawaited(_disposeVideoController());
    super.dispose();
  }

  Future<void> _initializeVideoController() async {
    if (_videoController != null || widget.media.type != MediaType.video) {
      return;
    }

    final session = ++_videoSession;
    final bookmark = widget.bookmarkData ?? widget.media.bookmarkData;
    String? acquiredBookmark;
    if (bookmark != null) {
      try {
        await BookmarkService.instance.startAccessingBookmark(bookmark);
        acquiredBookmark = bookmark;
      } catch (_) {
        // The player may still have access (for example, for an app-local file),
        // so initialization remains worth attempting.
      }
    }
    if (!mounted || session != _videoSession || !_isHovering) {
      if (acquiredBookmark != null) {
        await BookmarkService.instance.stopAccessingBookmark(acquiredBookmark);
      }
      return;
    }

    final controller = VideoPlayerController.file(File(widget.media.path));
    _videoController = controller;
    _activeVideoBookmark = acquiredBookmark;
    try {
      await controller.initialize();
      if (!mounted ||
          session != _videoSession ||
          controller != _videoController ||
          !_isHovering) {
        await _disposeVideoController();
        return;
      }
      await controller.setVolume(0.0);
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (controller == _videoController) {
        await _disposeVideoController();
      } else {
        await controller.dispose();
      }
    }
  }

  Future<void> _disposeVideoController() async {
    _videoSession += 1;
    final controller = _videoController;
    final bookmark = _activeVideoBookmark;
    _videoController = null;
    _activeVideoBookmark = null;
    try {
      if (controller != null) {
        try {
          await controller.pause();
        } finally {
          await controller.dispose();
        }
      }
    } finally {
      if (bookmark != null) {
        await BookmarkService.instance.stopAccessingBookmark(bookmark);
      }
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
              unawaited(_disposeVideoController());
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
                elevation: _isHovering || widget.isHighlighted
                    ? UiSizing.elevationHigh
                    : UiSizing.elevationLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    UiSizing.borderRadiusMedium,
                  ),
                  // Highlight wins over selection: it is transient, and it is
                  // the answer to the question the user just asked ("where is
                  // this file?").
                  side: widget.isHighlighted
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.tertiary,
                          width: UiSizing.borderWidth * 2,
                        )
                      : widget.isSelected
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
            MoveCopyButton(media: widget.media),
            const SizedBox(width: 4),
            FileOperationButton(media: widget.media),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(WidgetRef ref) {
    switch (widget.media.type) {
      case MediaType.image:
        return _buildImageContent();
      case MediaType.video:
        return _buildVideoContent();
      case MediaType.audio:
        return _buildAudioContent();
      case MediaType.text:
        return _buildTextContent();
      case MediaType.directory:
        return _buildDirectoryContent(ref);
    }
  }

  Widget _buildImageContent() {
    return MediaThumbnail(
      media: widget.media,
      bookmarkData: widget.bookmarkData,
      placeholderBuilder: (_) => _buildLoadingContent(),
      errorBuilder: (_) => _buildErrorContent(),
    );
  }

  Widget _buildVideoContent() {
    if (_isHovering &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return VideoPlayer(_videoController!);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        MediaThumbnail(
          media: widget.media,
          bookmarkData: widget.bookmarkData,
          placeholderBuilder: (_) => _buildVideoPlaceholder(),
          errorBuilder: (_) => _buildVideoPlaceholder(),
        ),
        Center(
          child: Icon(
            Icons.play_circle_fill,
            size: UiSizing.iconExtraLarge,
            color: UiColors.whiteOverlay,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPlaceholder() {
    return ColoredBox(
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

  Widget _buildAudioContent() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.audiotrack,
          size: UiSizing.iconExtraLarge,
          color: UiColors.whiteOverlay,
        ),
      ),
    );
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
    final showTaggedMediaCounts = ref.watch(
      showDirectoryTaggedMediaCountsProvider,
    );
    final directoryCountsAsync = ref.watch(directoryMediaCountsProvider);
    final directoryCounts =
        directoryCountsAsync.valueOrNull?[generateDirectoryId(
          widget.media.path,
        )] ??
        const DirectoryMediaCounts();
    return Column(
      children: [
        Expanded(
          flex: UiGrid.directoryPreviewFlex,
          child: DirectoryThumbnail(
            directoryPath: widget.media.path,
            bookmarkData: widget.bookmarkData,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => _buildLoadingContent(),
            emptyBuilder: (_) => _buildDirectoryPlaceholder(),
            errorBuilder: (_) => _buildErrorContent(),
          ),
        ),
        Expanded(
          flex: UiGrid.directoryNameFlex,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: UiSpacing.horizontalSmall,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.media.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: UiContent.maxLinesSingle,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                if (showTaggedMediaCounts) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${directoryCounts.taggedMediaCount} / '
                    '${directoryCounts.totalMediaCount} tagged',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: UiContent.maxLinesSingle,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectoryPlaceholder() {
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

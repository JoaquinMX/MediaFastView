import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../thumbnails/presentation/file_thumbnail.dart';
import '../../../thumbnails/presentation/media_thumbnail.dart';
import '../models/directory_preview.dart';
import '../providers/directory_cover_controller.dart';
import '../providers/directory_preview_providers.dart';

/// Renders the custom or automatic preview selected for a directory.
class DirectoryThumbnail extends ConsumerStatefulWidget {
  const DirectoryThumbnail({
    super.key,
    required this.directoryPath,
    required this.placeholderBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    this.bookmarkData,
    this.fit = BoxFit.cover,
  });

  final String directoryPath;
  final String? bookmarkData;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder emptyBuilder;
  final WidgetBuilder errorBuilder;

  @override
  ConsumerState<DirectoryThumbnail> createState() => _DirectoryThumbnailState();
}

class _DirectoryThumbnailState extends ConsumerState<DirectoryThumbnail> {
  bool _cleanupScheduled = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(directoryCoverControllerProvider(widget.directoryPath));
    final preview = ref.watch(directoryPreviewProvider(widget.directoryPath));
    return preview.when(
      data: (value) {
        _scheduleStaleCleanup(value?.hasStaleCustomCover ?? false);
        return switch (value) {
          DirectoryCustomPreview(:final media) => MediaThumbnail(
            media: media,
            bookmarkData: widget.bookmarkData,
            fit: widget.fit,
            placeholderBuilder: widget.placeholderBuilder,
            errorBuilder: widget.emptyBuilder,
          ),
          DirectoryImagePreview(:final sourcePath) => FileThumbnail(
            path: sourcePath,
            bookmarkData: widget.bookmarkData,
            fit: widget.fit,
            placeholderBuilder: widget.placeholderBuilder,
            errorBuilder: widget.emptyBuilder,
          ),
          DirectoryVideoPreview(:final thumbnailPath) => Image.file(
            File(thumbnailPath),
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => widget.emptyBuilder(context),
          ),
          DirectoryEmptyPreview() => widget.emptyBuilder(context),
          null => widget.emptyBuilder(context),
        };
      },
      loading: () => widget.placeholderBuilder(context),
      error: (_, __) => widget.errorBuilder(context),
    );
  }

  void _scheduleStaleCleanup(bool isStale) {
    if (!isStale || _cleanupScheduled) {
      return;
    }
    _cleanupScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
          .clearStaleCover();
    });
  }
}

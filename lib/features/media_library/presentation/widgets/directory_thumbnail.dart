import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../thumbnails/presentation/file_thumbnail.dart';
import '../models/directory_preview.dart';
import '../providers/directory_preview_providers.dart';

/// Renders the selected preview for a directory without generating video work.
class DirectoryThumbnail extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(directoryPreviewProvider(directoryPath));
    return preview.when(
      data: (value) => switch (value) {
        DirectoryImagePreview(:final sourcePath) => FileThumbnail(
          path: sourcePath,
          bookmarkData: bookmarkData,
          fit: fit,
          placeholderBuilder: placeholderBuilder,
          errorBuilder: emptyBuilder,
        ),
        DirectoryVideoPreview(:final thumbnailPath) => Image.file(
          File(thumbnailPath),
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => emptyBuilder(context),
        ),
        null => emptyBuilder(context),
      },
      loading: () => placeholderBuilder(context),
      error: (_, __) => errorBuilder(context),
    );
  }
}

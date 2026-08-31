import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/settings_providers.dart';
import 'package:media_fast_view/shared/utils/bookmark_resolver.dart';

typedef ThumbnailFallbackBuilder = Widget Function(BuildContext context);

/// Renders a lazily generated image or video thumbnail at a quantized size.
class MediaThumbnail extends ConsumerWidget {
  const MediaThumbnail({
    super.key,
    required this.media,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.bookmarkData,
    this.fit = BoxFit.cover,
    this.videoPositionFraction,
  });

  final MediaEntity media;
  final String? bookmarkData;
  final BoxFit fit;
  final double? videoPositionFraction;
  final ThumbnailFallbackBuilder placeholderBuilder;
  final ThumbnailFallbackBuilder errorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inheritedBookmark = bookmarkData ?? media.bookmarkData;
    if (Platform.isMacOS && inheritedBookmark == null) {
      final directories = ref.watch(thumbnailLibraryDirectoriesProvider);
      return directories.when(
        data: (roots) => _buildThumbnail(
          context,
          ref,
          resolveBookmarkForPath(media.path, roots),
        ),
        loading: () => placeholderBuilder(context),
        error: (_, __) => _buildThumbnail(context, ref, null),
      );
    }
    return _buildThumbnail(context, ref, inheritedBookmark);
  }

  Widget _buildThumbnail(
    BuildContext context,
    WidgetRef ref,
    String? effectiveBookmarkData,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final longestLogicalEdge = _longestFiniteEdge(constraints);
        final physicalPixels =
            longestLogicalEdge * MediaQuery.devicePixelRatioOf(context);
        final request = ThumbnailRequest.fromMedia(
          media,
          thumbnailSize: ThumbnailSize.forPhysicalPixels(physicalPixels),
          diskCacheEnabled: ref.watch(thumbnailDiskCacheEnabledProvider),
          bookmarkData: effectiveBookmarkData,
          videoPositionFraction: videoPositionFraction,
        );
        final thumbnail = ref.watch(thumbnailProvider(request));

        return thumbnail.when(
          data: (result) => _buildImage(context, result),
          loading: () => placeholderBuilder(context),
          error: (_, __) => errorBuilder(context),
        );
      },
    );
  }

  Widget _buildImage(BuildContext context, ThumbnailResult result) {
    Widget errorBuilderCallback(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) {
      return errorBuilder(context);
    }

    return switch (result.payload) {
      FileThumbnailPayload(:final path) => Image.file(
        File(path),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: errorBuilderCallback,
      ),
      MemoryThumbnailPayload(:final bytes) => Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: errorBuilderCallback,
      ),
    };
  }

  double _longestFiniteEdge(BoxConstraints constraints) {
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 512.0;
    final height = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : 512.0;
    return width > height ? width : height;
  }
}

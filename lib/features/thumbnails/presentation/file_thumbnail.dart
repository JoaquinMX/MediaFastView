import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_fast_view/features/thumbnails/presentation/media_thumbnail.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';

/// Adapts a path-only decorative image preview to [MediaThumbnail].
class FileThumbnail extends ConsumerWidget {
  const FileThumbnail({
    super.key,
    required this.path,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.bookmarkData,
    this.fit = BoxFit.cover,
  });

  final String path;
  final String? bookmarkData;
  final BoxFit fit;
  final ThumbnailFallbackBuilder placeholderBuilder;
  final ThumbnailFallbackBuilder errorBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(
          previewImageMediaProvider(
            PreviewImageMediaQuery(path: path, bookmarkData: bookmarkData),
          ),
        )
        .when(
          data: (media) => MediaThumbnail(
            media: media,
            bookmarkData: bookmarkData,
            fit: fit,
            placeholderBuilder: placeholderBuilder,
            errorBuilder: errorBuilder,
          ),
          loading: () => placeholderBuilder(context),
          error: (_, __) => errorBuilder(context),
        );
  }
}

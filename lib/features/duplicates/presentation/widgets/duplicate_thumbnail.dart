import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/settings_providers.dart';
import '../../../media_library/domain/entities/media_entity.dart';

/// A plain image thumbnail for a duplicate candidate.
///
/// Every candidate is an image, so this stays far simpler than `MediaGridItem`
/// (no hover, video, or selection chrome) while reusing the same
/// `thumbnailCachingProvider`-driven decode cap.
class DuplicateThumbnail extends ConsumerWidget {
  const DuplicateThumbnail({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
    this.cacheWidth = 400,
  });

  final MediaEntity media;
  final BoxFit fit;
  final int cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCachingEnabled = ref.watch(thumbnailCachingProvider);
    return Image.file(
      File(media.path),
      fit: fit,
      cacheWidth: isCachingEnabled ? cacheWidth : null,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

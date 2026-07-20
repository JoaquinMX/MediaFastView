import 'package:flutter/material.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../../../thumbnails/presentation/media_thumbnail.dart';

/// A thumbnail for a duplicate candidate using the shared cache pipeline.
class DuplicateThumbnail extends StatelessWidget {
  const DuplicateThumbnail({
    super.key,
    required this.media,
    this.fit = BoxFit.cover,
  });

  final MediaEntity media;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return MediaThumbnail(
      media: media,
      fit: fit,
      placeholderBuilder: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorBuilder: (context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

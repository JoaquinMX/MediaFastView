import 'dart:io';

import 'package:flutter/material.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../../../../shared/widgets/zoom_pan_viewer.dart';

/// Full-screen image viewer with zoom and pan capabilities
class FullScreenImageViewer extends StatelessWidget {
  const FullScreenImageViewer({
    super.key,
    required this.media,
    this.onToggleControls,
  });

  final MediaEntity media;
  final VoidCallback? onToggleControls;

  @override
  Widget build(BuildContext context) {
    return ZoomPanViewer(
      minScale: 1.0,
      maxScale: 4.0,
      onToggleControls: onToggleControls,
      child: Center(
        child: Image.file(
          File(media.path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text(
                'Failed to load image',
                style: TextStyle(color: Colors.white),
              ),
            );
          },
        ),
      ),
    );
  }
}

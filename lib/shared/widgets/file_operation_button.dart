import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/media_library/domain/entities/media_entity.dart';
import 'delete_media_action.dart';

/// Button for file operations like delete.
///
/// Hidden on platforms that don't support deleting source files (iOS). The
/// confirmation, gating, and feedback live in [confirmAndDeleteMedia] so every
/// delete surface behaves identically.
class FileOperationButton extends StatelessWidget {
  const FileOperationButton({
    super.key,
    required this.media,
  });

  final MediaEntity media;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => confirmAndDeleteMedia(context, media),
      tooltip: 'Delete',
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/file_transfer_result.dart';
import '../../features/media_library/domain/entities/media_entity.dart';
import 'move_copy_media_action.dart';

/// Moves or copies a media item into another folder.
///
/// Hidden on platforms that can't transfer source files (iOS). A popup rather
/// than two buttons because the grid item's hover overlay is already crowded.
class MoveCopyButton extends StatelessWidget {
  const MoveCopyButton({
    super.key,
    required this.media,
    this.onOperationComplete,
  });

  final MediaEntity media;
  final VoidCallback? onOperationComplete;

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<TransferMode>(
      icon: const Icon(Icons.drive_file_move_outline, color: Colors.white),
      tooltip: 'Move or copy',
      onSelected: (mode) => unawaited(
        pickDestinationAndTransferMedia(
          context,
          media,
          mode: mode,
          onTransferred: onOperationComplete,
        ),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: TransferMode.move,
          child: ListTile(
            leading: Icon(Icons.drive_file_move_outline),
            title: Text('Move to…'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: TransferMode.copy,
          child: ListTile(
            leading: Icon(Icons.file_copy_outlined),
            title: Text('Copy to…'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

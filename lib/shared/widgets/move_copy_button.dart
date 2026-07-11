import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/file_transfer_result.dart';
import '../../features/media_library/domain/entities/media_entity.dart';
import 'move_copy_media_action.dart';

/// Moves or copies a media item into another folder.
///
/// Hidden on platforms that can't transfer source files (iOS).
///
/// Deliberately an [IconButton] that opens the menu itself, rather than a
/// [PopupMenuButton]: this lives in the grid item's hover overlay, which is torn
/// down the moment the menu takes the pointer off the tile. `PopupMenuButton`
/// drops its `onSelected` callback when its own state is unmounted, so the menu
/// would appear and the choice would go nowhere.
class MoveCopyButton extends StatelessWidget {
  const MoveCopyButton({
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
      icon: const Icon(Icons.drive_file_move_outline, color: Colors.white),
      onPressed: () => unawaited(_showTransferMenu(context)),
      tooltip: 'Move or copy',
      iconSize: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }

  Future<void> _showTransferMenu(BuildContext context) async {
    // Captured while this button is still mounted: everything after the menu
    // closes has to run against a context that outlives the hover overlay.
    final rootContext = Navigator.of(context, rootNavigator: true).context;

    final mode = await showMenu<TransferMode>(
      context: context,
      position: _menuPosition(context),
      items: const [
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

    if (mode == null || !rootContext.mounted) {
      return;
    }

    await pickDestinationAndTransferMedia(rootContext, media, mode: mode);
  }

  /// Anchors the menu to the button.
  RelativeRect _menuPosition(BuildContext context) {
    final button = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;

    return RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
  }
}

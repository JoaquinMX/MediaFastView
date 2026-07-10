import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/media_library/presentation/view_models/file_operations_view_model.dart';
import '../providers/settings_providers.dart';
import 'confirmation_dialog.dart';

/// Shows the delete confirmation and moves [media] to the Trash.
///
/// Shared entry point for every surface that can delete a media item (grid,
/// full-screen viewer, slideshow, keyboard shortcut). Handles the platform gate
/// (macOS only), the "Delete From Source" setting gate, the confirmation
/// dialog, and success/error feedback.
///
/// Deliberately takes a [ProviderContainer] (captured from `context` up front)
/// rather than a `WidgetRef`: the trigger can be a short-lived widget such as a
/// grid item's hover overlay that is disposed the moment the confirmation
/// dialog opens, which would make its `ref` unusable after the await.
///
/// Returns `true` when the item was deleted. [onDeleted] runs after a
/// successful delete (e.g. to refresh a list or advance a viewer).
Future<bool> confirmAndDeleteMedia(
  BuildContext context,
  MediaEntity media, {
  VoidCallback? onDeleted,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  // Capture the app-lifetime container now, while `context` is valid, so all
  // provider access after an await is independent of the calling widget.
  final container = ProviderScope.containerOf(context, listen: false);

  // Platform gate: deleting originals is only possible on macOS. On iOS the
  // opened files are working copies, so deleting would not touch the original.
  if (!Platform.isMacOS) {
    await _showInfoDialog(
      context,
      title: 'Delete Not Supported',
      message:
          'Deleting files from the device is only supported on macOS. On iOS, '
          'opened files are working copies, so deleting them would not remove '
          'your original file.',
    );
    return false;
  }

  // Setting gate: deletion stays behind an explicit opt-in.
  final deleteFromSourceEnabled = container.read(deleteFromSourceProvider);
  if (!deleteFromSourceEnabled) {
    await _showInfoDialog(
      context,
      title: 'Delete From Source Disabled',
      message:
          'Deleting files from their original location is currently disabled. '
          'Enable "Delete From Source" in Settings > Data Management to allow '
          'files and directories to be removed from disk.',
    );
    return false;
  }

  final isDirectory = media.type == MediaType.directory;
  final itemType = isDirectory ? 'directory' : 'file';

  final confirmed = await ConfirmationDialog.show(
    context: context,
    title: 'Delete $itemType',
    content:
        'Move "${media.name}" to the Trash? '
        '${isDirectory ? 'This will move the directory and all its contents. ' : ''}'
        'You can restore it from the Trash.',
    confirmText: 'Delete',
    confirmColor: Colors.red,
  );

  if (confirmed != true) {
    return false;
  }

  final viewModel = container.read(fileOperationsViewModelProvider.notifier);
  // Keep the autoDispose provider alive across the async delete so the notifier
  // isn't disposed mid-operation (it sets state after awaiting).
  final subscription = container.listen(
    fileOperationsViewModelProvider,
    (_, __) {},
  );
  final FileOperationsState result;
  try {
    await viewModel.deleteMedia(
      media,
      deleteFromSource: deleteFromSourceEnabled,
    );
    result = container.read(fileOperationsViewModelProvider);
    viewModel.reset();
  } finally {
    subscription.close();
  }

  if (result is FileOperationsSuccess) {
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
    onDeleted?.call();
    return true;
  }
  if (result is FileOperationsError) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Error: ${result.message}'),
        backgroundColor: Colors.red,
      ),
    );
  }
  return false;
}

Future<void> _showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

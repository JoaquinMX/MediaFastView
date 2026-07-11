import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/batch_update_result.dart';
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

  final blocked = _deleteBlockedInfo(container);
  if (blocked != null) {
    await _showInfoDialog(
      context,
      title: blocked.title,
      message: blocked.message,
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
    await viewModel.deleteMedia(media, deleteFromSource: true);
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

/// Shows one confirmation and moves every item in [items] to the Trash,
/// reporting progress in a modal dialog and the outcome in a SnackBar.
///
/// Shares the platform and "Delete From Source" gates with
/// [confirmAndDeleteMedia]. Returns `null` when a gate blocked the operation or
/// the user cancelled; otherwise the per-item outcome. [onDeleted] runs when at
/// least one item was trashed.
Future<BatchUpdateResult?> confirmAndDeleteMediaBatch(
  BuildContext context,
  List<MediaEntity> items, {
  VoidCallback? onDeleted,
}) async {
  if (items.isEmpty) {
    return null;
  }

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final container = ProviderScope.containerOf(context, listen: false);

  final blocked = _deleteBlockedInfo(container);
  if (blocked != null) {
    await _showInfoDialog(
      context,
      title: blocked.title,
      message: blocked.message,
    );
    return null;
  }

  final confirmed = await ConfirmationDialog.show(
    context: context,
    title: 'Delete ${items.length} item${items.length == 1 ? '' : 's'}',
    content:
        'Move ${_describeSelection(items)} to the Trash? '
        'You can restore them from the Trash.',
    confirmText: 'Delete',
    confirmColor: Colors.red,
  );

  if (confirmed != true || !context.mounted) {
    return null;
  }

  final viewModel = container.read(fileOperationsViewModelProvider.notifier);
  final subscription = container.listen(
    fileOperationsViewModelProvider,
    (_, __) {},
  );
  final progress = ValueNotifier<_BulkDeleteProgress>(
    _BulkDeleteProgress(0, items.length),
  );

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BulkDeleteProgressDialog(progress: progress),
    ),
  );

  final BatchUpdateResult result;
  try {
    result = await viewModel.deleteMediaBatch(
      items,
      deleteFromSource: true,
      onProgress: (completed, total) =>
          progress.value = _BulkDeleteProgress(completed, total),
    );
    viewModel.reset();
  } finally {
    navigator.pop();
    progress.dispose();
    subscription.close();
  }

  final moved = result.successfulIds.length;
  final failed = result.failureReasons.length;

  if (moved == 0) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Failed to move ${failed == 1 ? 'the item' : '$failed items'} to '
          'Trash: ${result.failureReasons.values.first}',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return result;
  }

  messenger.showSnackBar(
    SnackBar(
      content: Text(
        'Moved $moved item${moved == 1 ? '' : 's'} to Trash'
        '${failed == 0 ? '' : ', $failed failed'}',
      ),
      backgroundColor: failed == 0 ? null : Colors.orange,
    ),
  );
  onDeleted?.call();
  return result;
}

/// The reason deleting is currently blocked, or `null` when it is allowed.
///
/// Shared by every delete surface. Synchronous on purpose: the caller only
/// awaits when it has an explanation to show, which keeps the happy path free
/// of async gaps that would invalidate its `context`.
({String title, String message})? _deleteBlockedInfo(
  ProviderContainer container,
) {
  // Platform gate: deleting originals is only possible on macOS. On iOS the
  // opened files are working copies, so deleting would not touch the original.
  if (!Platform.isMacOS) {
    return (
      title: 'Delete Not Supported',
      message:
          'Deleting files from the device is only supported on macOS. On iOS, '
          'opened files are working copies, so deleting them would not remove '
          'your original file.',
    );
  }

  // Setting gate: deletion stays behind an explicit opt-in.
  if (!container.read(deleteFromSourceProvider)) {
    return (
      title: 'Delete From Source Disabled',
      message:
          'Deleting files from their original location is currently disabled. '
          'Enable "Delete From Source" in Settings > Data Management to allow '
          'files and directories to be removed from disk.',
    );
  }

  return null;
}

String _describeSelection(List<MediaEntity> items) {
  final directories = items
      .where((item) => item.type == MediaType.directory)
      .length;
  final files = items.length - directories;

  if (directories == 0) {
    return '$files file${files == 1 ? '' : 's'}';
  }
  final folderText = '$directories folder${directories == 1 ? '' : 's'} '
      '(with everything inside)';
  if (files == 0) {
    return folderText;
  }
  return '$files file${files == 1 ? '' : 's'} and $folderText';
}

class _BulkDeleteProgress {
  const _BulkDeleteProgress(this.completed, this.total);

  final int completed;
  final int total;
}

/// Blocking progress dialog for a bulk delete. Intentionally offers no Cancel:
/// the native Trash call has no cancellation hook, so the button could not
/// honour it.
class _BulkDeleteProgressDialog extends StatelessWidget {
  const _BulkDeleteProgressDialog({required this.progress});

  final ValueListenable<_BulkDeleteProgress> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Moving to Trash'),
      content: ValueListenableBuilder<_BulkDeleteProgress>(
        valueListenable: progress,
        builder: (context, value, _) {
          final total = value.total;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Deleting ${value.completed} of $total…'),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: total == 0 ? null : value.completed / total,
              ),
            ],
          );
        },
      ),
    );
  }
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

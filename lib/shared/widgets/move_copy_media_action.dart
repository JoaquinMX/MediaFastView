import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/file_transfer_result.dart';
import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/media_library/presentation/view_models/file_operations_view_model.dart';
import '../../features/media_library/presentation/widgets/destination_picker_dialog.dart';
import 'info_dialog.dart';
import 'transfer_conflict_dialog.dart';

/// The outcome of a batch transfer, for the summary message.
class TransferSummary {
  const TransferSummary({
    required this.transferred,
    required this.renamed,
    required this.skipped,
    required this.failed,
  });

  final int transferred;
  final int renamed;
  final int skipped;
  final int failed;

  bool get didAnything => transferred > 0;
}

/// Picks a destination and moves or copies [media] into it.
///
/// Shared entry point for every transfer surface (grid hover, context menu,
/// full-screen viewer, whole directory).
///
/// Like [confirmAndDeleteMedia], this captures the [ProviderContainer] from
/// `context` up front rather than taking a `WidgetRef`: the trigger is often a
/// short-lived widget — a grid item's hover overlay — that is disposed the
/// moment the picker opens, which would leave its `ref` unusable across the
/// awaits that follow.
///
/// Returns the item at its new location, or null if nothing happened.
Future<MediaEntity?> pickDestinationAndTransferMedia(
  BuildContext context,
  MediaEntity media, {
  required TransferMode mode,
  VoidCallback? onTransferred,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  if (!await _ensureSupported(context, mode) || !context.mounted) {
    return null;
  }

  final isMove = mode == TransferMode.move;
  final isDirectory = media.type == MediaType.directory;

  final destination = await DestinationPickerDialog.show(
    context,
    title: '${isMove ? 'Move' : 'Copy'} "${media.name}" to…',
    confirmLabel: isMove ? 'Move Here' : 'Copy Here',
    disabledPath: _parentOf(media.path),
    forbiddenSubtreePath: isDirectory ? media.path : null,
  );
  if (destination == null || !context.mounted) {
    return null;
  }

  MediaEntity? result;
  await _runTransfer(
    context: context,
    container: container,
    media: media,
    destination: destination,
    mode: mode,
    remaining: 0,
    onSuccess: (state) => result = state.media,
    onError: (message) => messenger.showSnackBar(
      SnackBar(content: Text('Error: $message'), backgroundColor: Colors.red),
    ),
  );

  if (result != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${isMove ? 'Moved' : 'Copied'} to ${destination.name}',
        ),
      ),
    );
    onTransferred?.call();
  }
  return result;
}

/// Picks one destination and transfers every item in [items] into it.
Future<TransferSummary?> pickDestinationAndTransferMediaBatch(
  BuildContext context,
  List<MediaEntity> items, {
  required TransferMode mode,
  VoidCallback? onTransferred,
}) async {
  if (items.isEmpty) {
    return null;
  }

  final messenger = ScaffoldMessenger.of(context);
  final container = ProviderScope.containerOf(context, listen: false);

  if (!await _ensureSupported(context, mode)) {
    return null;
  }

  final isMove = mode == TransferMode.move;
  final directories = items.where((i) => i.type == MediaType.directory);

  if (!context.mounted) return null;
  final destination = await DestinationPickerDialog.show(
    context,
    title: '${isMove ? 'Move' : 'Copy'} ${items.length} items to…',
    confirmLabel: isMove ? 'Move Here' : 'Copy Here',
    // With several sources there is no single "current" folder to rule out, but
    // none of the selected folders may swallow the transfer.
    forbiddenSubtreePath: directories.length == 1
        ? directories.first.path
        : null,
  );
  if (destination == null || !context.mounted) {
    return null;
  }

  final progress = ValueNotifier<_BatchProgress>(
    _BatchProgress(0, items.length),
  );
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferProgressDialog(mode: mode, progress: progress),
    ),
  );

  var transferred = 0;
  var renamed = 0;
  var skipped = 0;
  var failed = 0;
  ConflictResolution? applyToAll;
  var cancelled = false;

  try {
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      progress.value = _BatchProgress(index, items.length, item.name);

      var strategy = ConflictStrategy.fail;
      if (applyToAll == ConflictResolution.keepBoth) {
        strategy = ConflictStrategy.keepBoth;
      } else if (applyToAll == ConflictResolution.skip) {
        // Probe with `fail` so a non-conflicting item still transfers; only an
        // actual collision is skipped.
        strategy = ConflictStrategy.fail;
      }

      var resolved = false;
      while (!resolved) {
        resolved = true;
        await _runTransfer(
          context: context,
          container: container,
          media: item,
          destination: destination,
          mode: mode,
          remaining: items.length - index - 1,
          strategy: strategy,
          onSuccess: (state) {
            transferred++;
            if (state.transfer.renamed) renamed++;
          },
          onError: (_) => failed++,
          onConflict: (conflict) async {
            if (applyToAll == ConflictResolution.skip) {
              skipped++;
              return;
            }

            if (!context.mounted) {
              skipped++;
              return;
            }
            final choice = await TransferConflictDialog.show(
              context,
              destinationPath: conflict.destinationPath,
              suggestedPath: conflict.suggestedPath,
              remaining: items.length - index - 1,
            );

            final resolution = choice?.resolution ?? ConflictResolution.cancel;
            if (choice?.applyToAll ?? false) {
              applyToAll = resolution;
            }

            switch (resolution) {
              case ConflictResolution.keepBoth:
                strategy = ConflictStrategy.keepBoth;
                resolved = false; // retry this item, renaming it
              case ConflictResolution.skip:
                skipped++;
              case ConflictResolution.cancel:
                cancelled = true;
            }
          },
        );
      }

      if (cancelled) break;
    }
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    // The dialog's listener is only detached when its route finishes
    // disposing, which happens after this frame — disposing the notifier now
    // would make that detach throw.
    WidgetsBinding.instance.addPostFrameCallback((_) => progress.dispose());
  }

  final summary = TransferSummary(
    transferred: transferred,
    renamed: renamed,
    skipped: skipped,
    failed: failed,
  );

  messenger.showSnackBar(
    SnackBar(content: Text(_describeSummary(summary, mode: mode))),
  );
  if (summary.didAnything) {
    onTransferred?.call();
  }
  return summary;
}

/// Runs one transfer through the view model, keeping the autoDispose notifier
/// alive across the await so it isn't disposed mid-operation.
Future<void> _runTransfer({
  required BuildContext context,
  required ProviderContainer container,
  required MediaEntity media,
  required DestinationPickerResult destination,
  required TransferMode mode,
  required int remaining,
  ConflictStrategy strategy = ConflictStrategy.fail,
  required void Function(FileOperationsTransferSuccess) onSuccess,
  required void Function(String message) onError,
  Future<void> Function(FileOperationsConflict)? onConflict,
}) async {
  final viewModel = container.read(fileOperationsViewModelProvider.notifier);
  final subscription = container.listen(
    fileOperationsViewModelProvider,
    (_, __) {},
  );

  final FileOperationsState result;
  try {
    await viewModel.transferMedia(
      media,
      destinationDirectoryPath: destination.path,
      destinationBookmarkData: destination.bookmarkData,
      mode: mode,
      conflictStrategy: strategy,
    );
    result = container.read(fileOperationsViewModelProvider);
    viewModel.reset();
  } finally {
    subscription.close();
  }

  switch (result) {
    case FileOperationsTransferSuccess():
      onSuccess(result);
    case FileOperationsConflict():
      if (onConflict != null) {
        await onConflict(result);
      } else if (context.mounted) {
        await _resolveSingleConflict(
          context: context,
          container: container,
          media: media,
          destination: destination,
          mode: mode,
          conflict: result,
          onSuccess: onSuccess,
          onError: onError,
        );
      }
    case FileOperationsError():
      onError(result.message);
    default:
      break;
  }
}

/// The single-item conflict flow: ask, and retry with a rename if asked to.
Future<void> _resolveSingleConflict({
  required BuildContext context,
  required ProviderContainer container,
  required MediaEntity media,
  required DestinationPickerResult destination,
  required TransferMode mode,
  required FileOperationsConflict conflict,
  required void Function(FileOperationsTransferSuccess) onSuccess,
  required void Function(String message) onError,
}) async {
  if (!context.mounted) return;

  final choice = await TransferConflictDialog.show(
    context,
    destinationPath: conflict.destinationPath,
    suggestedPath: conflict.suggestedPath,
  );

  if (choice?.resolution != ConflictResolution.keepBoth || !context.mounted) {
    return;
  }

  await _runTransfer(
    context: context,
    container: container,
    media: media,
    destination: destination,
    mode: mode,
    remaining: 0,
    strategy: ConflictStrategy.keepBoth,
    onSuccess: onSuccess,
    onError: onError,
  );
}

/// Transfers are macOS-only, for the same reason deletes are: on iOS the opened
/// files are working copies, so moving one would not touch the original.
Future<bool> _ensureSupported(BuildContext context, TransferMode mode) async {
  if (Platform.isMacOS) {
    return true;
  }

  await showInfoDialog(
    context,
    title: '${mode == TransferMode.move ? 'Move' : 'Copy'} Not Supported',
    message:
        'Moving and copying files is only supported on macOS. On iOS, opened '
        'files are working copies, so changing them would not affect your '
        'original files.',
  );
  return false;
}

String? _parentOf(String path) {
  final separator = path.lastIndexOf(Platform.pathSeparator);
  return separator <= 0 ? null : path.substring(0, separator);
}

String _describeSummary(TransferSummary summary, {required TransferMode mode}) {
  final verb = mode == TransferMode.move ? 'Moved' : 'Copied';
  final parts = <String>['$verb ${summary.transferred}'];
  if (summary.renamed > 0) parts.add('renamed ${summary.renamed}');
  if (summary.skipped > 0) parts.add('skipped ${summary.skipped}');
  if (summary.failed > 0) parts.add('failed ${summary.failed}');
  return parts.join(' · ');
}

class _BatchProgress {
  const _BatchProgress(this.completed, this.total, [this.currentName]);

  final int completed;
  final int total;
  final String? currentName;
}

/// Blocking progress dialog for a bulk transfer. Offers no Cancel: the native
/// call has no cancellation hook, so the button could not honour it. The
/// conflict prompt stacks on top of this, and its Cancel does end the batch.
class _TransferProgressDialog extends StatelessWidget {
  const _TransferProgressDialog({required this.mode, required this.progress});

  final TransferMode mode;
  final ValueListenable<_BatchProgress> progress;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(mode == TransferMode.move ? 'Moving' : 'Copying'),
      content: ValueListenableBuilder<_BatchProgress>(
        valueListenable: progress,
        builder: (context, value, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${value.completed} of ${value.total}…'),
              if (value.currentName != null) ...[
                const SizedBox(height: 4),
                Text(
                  value.currentName!,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: value.total == 0 ? null : value.completed / value.total,
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/media_library/domain/entities/media_entity.dart';
import '../../features/media_library/presentation/view_models/file_operations_view_model.dart';
import 'confirmation_dialog.dart';
import 'file_operation_progress_dialog.dart';

/// Button for file operations like delete
class FileOperationButton extends ConsumerWidget {
  const FileOperationButton({
    super.key,
    required this.media,
    this.onOperationComplete,
  });

  final MediaEntity media;
  final VoidCallback? onOperationComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileOperationsViewModel = ref.read(
      fileOperationsViewModelProvider.notifier,
    );

    // Show progress dialog when operation is in progress
    ref.listen<FileOperationsState>(fileOperationsViewModelProvider, (
      previous,
      next,
    ) {
      if (next is FileOperationsLoading) {
        FileOperationProgressDialog.show(
          context: context,
          title: 'Deleting...',
          message: 'Deleting ${media.name}...',
        );
      } else if (next is FileOperationsSuccess) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.message)));
        onOperationComplete?.call();
        fileOperationsViewModel.reset();
      } else if (next is FileOperationsError) {
        Navigator.of(context).pop(); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${next.message}'),
            backgroundColor: Colors.red,
          ),
        );
        fileOperationsViewModel.reset();
      }
    });

    return IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () =>
          _showDeleteConfirmation(context, fileOperationsViewModel),
      tooltip: 'Delete',
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    FileOperationsViewModel viewModel,
  ) {
    final isDirectory = media.type == MediaType.directory;
    final itemType = isDirectory ? 'directory' : 'file';

    ConfirmationDialog.show(
      context: context,
      title: 'Delete $itemType',
      content:
          'Are you sure you want to delete "${media.name}"? '
          '${isDirectory ? 'This will delete the directory and all its contents.' : ''} '
          'This action cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
      onConfirm: () {
        if (isDirectory) {
          viewModel.deleteDirectory(media.path);
        } else {
          viewModel.deleteFile(media.path);
        }
      },
    );
  }
}

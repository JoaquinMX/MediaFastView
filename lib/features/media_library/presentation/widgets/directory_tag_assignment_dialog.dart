import 'package:flutter/material.dart';

import '../../../../shared/widgets/tag_selection_dialog.dart';
import '../../domain/entities/directory_entity.dart';

class DirectoryTagAssignmentDialog {
  const DirectoryTagAssignmentDialog._();

  static Future<void> show(
    BuildContext context, {
    required DirectoryEntity directory,
    required Future<void> Function(List<String> tagIds) onTagsAssigned,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TagSelectionDialog<void>(
        title: 'Assign Tags to "${directory.name}"',
        description: 'Select tags to assign to this directory.',
        initialSelectedTagIds: directory.tagIds,
        onConfirm: (selected) async {
          await onTagsAssigned(selected);
          return null;
        },
        confirmLabel: 'Save',
        cancelLabel: 'Cancel',
        emptyStateBuilder: (context) => _buildEmptyState(context),
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('No tags available', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create tags first to assign them to directories',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

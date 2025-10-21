import 'package:flutter/material.dart';

import '../../../../shared/widgets/tag_selection_dialog.dart';

class BulkTagAssignmentDialog {
  const BulkTagAssignmentDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String description,
    List<String> initialTagIds = const <String>[],
    required Future<void> Function(List<String> tagIds) onTagsAssigned,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => TagSelectionDialog<bool>(
        title: title,
        description: description,
        initialSelectedTagIds: initialTagIds,
        onConfirm: (selected) async {
          await onTagsAssigned(selected);
          return true;
        },
        confirmLabel: 'Apply Tags',
        cancelLabel: 'Cancel',
        cancelResult: false,
        emptyStateBuilder: (context) => _buildEmptyState(context),
      ),
    );
    return result ?? false;
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
            'Create tags first to assign them to selected items.',
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

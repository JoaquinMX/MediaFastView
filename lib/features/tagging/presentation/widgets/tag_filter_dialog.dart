import 'package:flutter/material.dart';

import '../../../../shared/widgets/tag_selection_dialog.dart';

class TagFilterDialog {
  const TagFilterDialog._();

  static Future<void> show(
    BuildContext context, {
    required List<String> selectedTagIds,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TagSelectionDialog<void>(
        title: 'Filter by Tags',
        description:
            'Select tags to filter by. Selecting none shows all items.',
        initialSelectedTagIds: selectedTagIds,
        onSelectionChanged: onSelectionChanged,
        onConfirm: (selection) async {
          onSelectionChanged(selection);
          return null;
        },
        confirmLabel: 'Apply',
        cancelLabel: 'Cancel',
        showAllOption: true,
        allOptionLabel: 'All',
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
        ],
      ),
    );
  }
}

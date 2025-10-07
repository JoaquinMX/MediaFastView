import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/presentation/states/tag_state.dart';
import '../../../tagging/presentation/view_models/tag_management_view_model.dart';
import '../../../tagging/presentation/widgets/tag_chip.dart';
import '../../domain/entities/directory_entity.dart';

/// A dialog for assigning tags to a directory.
/// Allows users to select/deselect tags for a specific directory.
class DirectoryTagAssignmentDialog extends ConsumerStatefulWidget {
  const DirectoryTagAssignmentDialog({
    super.key,
    required this.directory,
    required this.onTagsAssigned,
  });

  final DirectoryEntity directory;
  final ValueChanged<List<String>> onTagsAssigned;

  static Future<void> show(
    BuildContext context, {
    required DirectoryEntity directory,
    required ValueChanged<List<String>> onTagsAssigned,
  }) {
    return showDialog(
      context: context,
      builder: (context) => DirectoryTagAssignmentDialog(
        directory: directory,
        onTagsAssigned: onTagsAssigned,
      ),
    );
  }

  @override
  ConsumerState<DirectoryTagAssignmentDialog> createState() =>
      _DirectoryTagAssignmentDialogState();
}

class _DirectoryTagAssignmentDialogState
    extends ConsumerState<DirectoryTagAssignmentDialog> {
  late List<String> _tempSelectedTagIds;

  @override
  void initState() {
    super.initState();
    _tempSelectedTagIds = List<String>.from(widget.directory.tagIds);
  }

  @override
  Widget build(BuildContext context) {
    final tagState = ref.watch(tagViewModelProvider);

    return AlertDialog(
      title: Text('Assign Tags to "${widget.directory.name}"'),
      content: SizedBox(
        width: double.maxFinite,
        child: switch (tagState) {
          TagLoaded(:final tags) => _buildContent(context, tags),
          TagLoading() => const Center(child: CircularProgressIndicator()),
          TagError(:final message) => Center(
            child: Text(
              'Error: $message',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          TagEmpty() => _buildEmptyState(context),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onTagsAssigned(_tempSelectedTagIds);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, List<TagEntity> tags) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select tags to assign to this directory.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map(
                (tag) => TagChip(
                  tag: tag,
                  selected: _tempSelectedTagIds.contains(tag.id),
                  onTap: () => _toggleTagSelection(tag.id),
                ),
              ).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.tag,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('No tags available', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Create tags first to assign them to directories',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _toggleTagSelection(String tagId) {
    setState(() {
      if (_tempSelectedTagIds.contains(tagId)) {
        _tempSelectedTagIds.remove(tagId);
      } else {
        _tempSelectedTagIds.add(tagId);
      }
    });
  }
}
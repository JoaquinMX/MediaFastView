import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag_entity.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_chip.dart';

/// A dialog for filtering tags when there are too many to display in chips.
/// Allows users to select/deselect tags for filtering.
class TagFilterDialog extends ConsumerStatefulWidget {
  const TagFilterDialog({
    super.key,
    required this.selectedTagIds,
    required this.onSelectionChanged,
  });

  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;

  static Future<void> show(
    BuildContext context, {
    required List<String> selectedTagIds,
    required ValueChanged<List<String>> onSelectionChanged,
  }) {
    return showDialog(
      context: context,
      builder: (context) => TagFilterDialog(
        selectedTagIds: selectedTagIds,
        onSelectionChanged: onSelectionChanged,
      ),
    );
  }

  @override
  ConsumerState<TagFilterDialog> createState() => _TagFilterDialogState();
}

class _TagFilterDialogState extends ConsumerState<TagFilterDialog> {
  late List<String> _tempSelectedTagIds;

  @override
  void initState() {
    super.initState();
    _tempSelectedTagIds = List<String>.from(widget.selectedTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final tagState = ref.watch(tagViewModelProvider);

    return AlertDialog(
      title: const Text('Filter by Tags'),
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
            widget.onSelectionChanged(_tempSelectedTagIds);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
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
          'Select tags to filter by. Selecting none shows all items.',
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
              children: [
                // "All" option
                TagChip(
                  tag: TagEntity(
                    id: 'all',
                    name: 'All',
                    color: 0xFF9E9E9E, // Grey color
                    createdAt: DateTime.now(),
                  ),
                  selected: _tempSelectedTagIds.isEmpty,
                  onTap: _toggleAllSelection,
                ),
                // Individual tags
                ...tags.map(
                  (tag) => TagChip(
                    tag: tag,
                    selected: _tempSelectedTagIds.contains(tag.id),
                    onTap: () => _toggleTagSelection(tag.id),
                  ),
                ),
              ],
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

  void _toggleAllSelection() {
    setState(() {
      _tempSelectedTagIds.clear();
    });
  }
}
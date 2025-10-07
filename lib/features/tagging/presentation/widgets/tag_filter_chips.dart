import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag_entity.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_chip.dart';
import 'tag_filter_dialog.dart';

/// A widget that displays filterable tag chips for multi-select filtering.
/// Allows users to select/deselect tags to filter content.
class TagFilterChips extends ConsumerWidget {
  const TagFilterChips({
    super.key,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.maxChipsToShow,
    this.showAllButton = true,
  });

  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final int? maxChipsToShow;
  final bool showAllButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagState = ref.watch(tagViewModelProvider);

    return switch (tagState) {
      TagLoaded(:final tags) => _buildFilterChips(context, tags),
      TagLoading() => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      ),
      TagError(:final message) => SizedBox(
        height: 40,
        child: Center(
          child: Text(
            'Error loading tags: $message',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      ),
      TagEmpty() => const SizedBox.shrink(),
    };
  }

  Widget _buildFilterChips(BuildContext context, List<TagEntity> allTags) {
    final displayTags =
        maxChipsToShow != null && allTags.length > maxChipsToShow!
        ? allTags.take(maxChipsToShow!).toList()
        : allTags;

    final showMoreButton =
        maxChipsToShow != null && allTags.length > maxChipsToShow!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showAllButton) ...[
            _buildAllFilterChip(context),
            const SizedBox(width: 8),
          ],
          ...displayTags.map(
            (tag) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TagChip(
                tag: tag,
                selected: selectedTagIds.contains(tag.id),
                compact: true,
                onTap: () => _toggleTagSelection(tag.id),
              ),
            ),
          ),
          if (showMoreButton) ...[
            const SizedBox(width: 8),
            _buildMoreButton(context, allTags.length - maxChipsToShow!),
          ],
        ],
      ),
    );
  }

  Widget _buildAllFilterChip(BuildContext context) {
    final isAllSelected = selectedTagIds.isEmpty;

    return TagChip(
      tag: TagEntity(
        id: 'all',
        name: 'All',
        color: 0xFF9E9E9E, // Grey color
        createdAt:
            DateTime.now(), // Not used for display, just for construction
      ),
      selected: isAllSelected,
      compact: true,
      onTap: _selectAll,
    );
  }

  Widget _buildMoreButton(BuildContext context, int remainingCount) {
    return ActionChip(
      label: Text('+$remainingCount'),
      onPressed: () => _showAllTagsDialog(context),
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _toggleTagSelection(String tagId) {
    final newSelection = List<String>.from(selectedTagIds);
    if (newSelection.contains(tagId)) {
      newSelection.remove(tagId);
    } else {
      newSelection.add(tagId);
    }
    onSelectionChanged(newSelection);
  }

  void _selectAll() {
    onSelectionChanged([]);
  }

  void _showAllTagsDialog(BuildContext context) {
    TagFilterDialog.show(
      context,
      selectedTagIds: selectedTagIds,
      onSelectionChanged: onSelectionChanged,
    );
  }
}

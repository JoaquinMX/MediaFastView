import 'package:flutter/material.dart';

import '../../domain/entities/tag_entity.dart';
import 'tag_chip.dart';

/// Shared horizontal strip for displaying selectable tag chips.
///
/// This widget encapsulates the selection handling and layout for the
/// horizontally scrolling chip rows that appear across the app (e.g. media
/// library filters, directory filters). It keeps the tag chip visuals
/// consistent and centralises overflow behaviours.
class SelectableTagChipStrip extends StatelessWidget {
  const SelectableTagChipStrip({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.maxChipsToShow,
    this.showAllChip = true,
    this.allChipLabel = 'All',
    this.allChipColor = const Color(0xFF9E9E9E),
    this.onOverflowPressed,
  });

  /// Full list of tags available for selection.
  final List<TagEntity> tags;

  /// Currently selected tag identifiers.
  final List<String> selectedTagIds;

  /// Callback invoked when the selection changes.
  final ValueChanged<List<String>> onSelectionChanged;

  /// Maximum number of chips to render inline before showing an overflow chip.
  final int? maxChipsToShow;

  /// Whether to render the "All" chip that clears the selection.
  final bool showAllChip;

  /// Label used for the "All" chip.
  final String allChipLabel;

  /// Background colour used for the "All" chip when not selected.
  final Color allChipColor;

  /// Callback invoked when the overflow chip is tapped.
  final VoidCallback? onOverflowPressed;

  @override
  Widget build(BuildContext context) {
    final displayTags = _tagsToDisplay();
    final showOverflowChip =
        maxChipsToShow != null && tags.length > maxChipsToShow!;
    final remainingCount =
        showOverflowChip ? tags.length - maxChipsToShow! : 0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showAllChip) ...[
            _buildAllChip(),
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
          if (showOverflowChip && remainingCount > 0) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: Text('+$remainingCount'),
              onPressed: onOverflowPressed,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<TagEntity> _tagsToDisplay() {
    if (maxChipsToShow != null && tags.length > maxChipsToShow!) {
      return tags.take(maxChipsToShow!).toList();
    }
    return tags;
  }

  Widget _buildAllChip() {
    final isAllSelected = selectedTagIds.isEmpty;
    return TagChip(
      tag: TagEntity(
        id: '__all__',
        name: allChipLabel,
        color: allChipColor.value,
        createdAt: DateTime.now(),
      ),
      selected: isAllSelected,
      compact: true,
      onTap: () => onSelectionChanged(const []),
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
}

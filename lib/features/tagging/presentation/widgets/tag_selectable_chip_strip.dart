import 'package:flutter/material.dart';

import '../../domain/entities/tag_entity.dart';
import 'tag_chip.dart';

/// Signature for displaying an overflow dialog when not all chips fit inline.
typedef TagOverflowDialogBuilder = Future<void> Function(
  BuildContext context,
  List<String> selectedTagIds,
  ValueChanged<List<String>> onSelectionChanged,
);

/// Callback invoked whenever an individual tag chip is toggled.
typedef TagSelectionToggleCallback = void Function(
  TagEntity tag,
  bool isSelected,
  List<String> previousSelection,
  List<String> updatedSelection,
);

/// Callback invoked when the "All" chip is tapped.
typedef AllChipSelectionCallback = void Function(List<String> previousSelection);

/// Controls how individual chips are rendered.
enum TagChipVariant { colored, filter }

/// Horizontal chip strip that keeps tag selection behaviour consistent across
/// different screens. Handles the "All" chip, inline overflow affordance and
/// selection wiring so each caller only needs to respond to the new list of
/// selected tag ids.
class TagSelectableChipStrip extends StatelessWidget {
  const TagSelectableChipStrip({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.maxChipsToShow,
    this.showAllChip = true,
    this.allChipLabel = 'All',
    this.chipVariant = TagChipVariant.filter,
    this.chipPadding = const EdgeInsets.only(right: 8),
    this.onShowOverflowDialog,
    this.onTagSelectionToggle,
    this.onAllChipSelected,
  });

  final List<TagEntity> tags;
  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final int? maxChipsToShow;
  final bool showAllChip;
  final String allChipLabel;
  final TagChipVariant chipVariant;
  final EdgeInsetsGeometry chipPadding;
  final TagOverflowDialogBuilder? onShowOverflowDialog;
  final TagSelectionToggleCallback? onTagSelectionToggle;
  final AllChipSelectionCallback? onAllChipSelected;

  @override
  Widget build(BuildContext context) {
    final displayTags = _displayTags();
    final showOverflowChip = maxChipsToShow != null && tags.length > maxChipsToShow!;

    if (!showAllChip && displayTags.isEmpty && !showOverflowChip) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (showAllChip)
            Padding(
              padding: chipPadding,
              child: _buildAllChip(context),
            ),
          ...displayTags.map(
            (tag) => Padding(
              padding: chipPadding,
              child: _buildTagChip(context, tag),
            ),
          ),
          if (showOverflowChip)
            Padding(
              padding: chipPadding,
              child: _buildOverflowChip(
                context,
                tags.length - displayTags.length,
              ),
            ),
        ],
      ),
    );
  }

  List<TagEntity> _displayTags() {
    if (maxChipsToShow != null && tags.length > maxChipsToShow!) {
      return tags.take(maxChipsToShow!).toList(growable: false);
    }
    return tags;
  }

  Widget _buildAllChip(BuildContext context) {
    final isAllSelected = selectedTagIds.isEmpty;

    return switch (chipVariant) {
      TagChipVariant.colored => TagChip(
          tag: TagEntity(
            id: '__tag_filter_all__',
            name: allChipLabel,
            color: 0xFF9E9E9E,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
          selected: isAllSelected,
          compact: true,
          onTap: () => _handleAllSelected(),
        ),
      TagChipVariant.filter => FilterChip(
          label: Text(allChipLabel),
          selected: isAllSelected,
          onSelected: (_) => _handleAllSelected(),
        ),
    };
  }

  Widget _buildTagChip(BuildContext context, TagEntity tag) {
    final isSelected = selectedTagIds.contains(tag.id);

    return switch (chipVariant) {
      TagChipVariant.colored => TagChip(
          tag: tag,
          selected: isSelected,
          compact: true,
          onTap: () => _handleTagToggled(tag, !isSelected),
        ),
      TagChipVariant.filter => FilterChip(
          label: Text(tag.name),
          selected: isSelected,
          onSelected: (selected) => _handleTagToggled(tag, selected),
        ),
    };
  }

  Widget _buildOverflowChip(BuildContext context, int remainingCount) {
    return ActionChip(
      label: Text('+$remainingCount'),
      onPressed: onShowOverflowDialog == null
          ? null
          : () => onShowOverflowDialog!(
                context,
                selectedTagIds,
                onSelectionChanged,
              ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  void _handleAllSelected() {
    final previousSelection = List<String>.from(selectedTagIds);
    onAllChipSelected?.call(previousSelection);
    onSelectionChanged(const []);
  }

  void _handleTagToggled(TagEntity tag, bool isSelected) {
    final previousSelection = List<String>.from(selectedTagIds);
    final updatedSelection = List<String>.from(selectedTagIds);

    if (isSelected) {
      if (!updatedSelection.contains(tag.id)) {
        updatedSelection.add(tag.id);
      }
    } else {
      updatedSelection.remove(tag.id);
    }

    onTagSelectionToggle?.call(tag, isSelected, previousSelection, updatedSelection);
    onSelectionChanged(updatedSelection);
  }
}

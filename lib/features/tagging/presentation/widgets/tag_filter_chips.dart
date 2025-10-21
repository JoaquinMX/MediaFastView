import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag_entity.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'tag_filter_dialog.dart';
import 'tag_selectable_chip_strip.dart';

/// A widget that displays filterable tag chips for multi-select filtering.
/// Allows users to select/deselect tags to filter content.
class TagFilterChips extends ConsumerWidget {
  const TagFilterChips({
    super.key,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.maxChipsToShow,
    this.showAllButton = true,
    this.chipVariant = TagChipVariant.filter,
    this.chipPadding = const EdgeInsets.only(right: 8),
    this.onTagSelectionToggle,
    this.onAllChipSelected,
  });

  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final int? maxChipsToShow;
  final bool showAllButton;
  final TagChipVariant chipVariant;
  final EdgeInsetsGeometry chipPadding;
  final TagSelectionToggleCallback? onTagSelectionToggle;
  final AllChipSelectionCallback? onAllChipSelected;

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
    return TagSelectableChipStrip(
      tags: allTags,
      selectedTagIds: selectedTagIds,
      onSelectionChanged: onSelectionChanged,
      maxChipsToShow: maxChipsToShow,
      showAllChip: showAllButton,
      chipVariant: chipVariant,
      chipPadding: chipPadding,
      onTagSelectionToggle: onTagSelectionToggle,
      onAllChipSelected: onAllChipSelected,
      onShowOverflowDialog: (context, selection, callback) => TagFilterDialog.show(
        context,
        selectedTagIds: selection,
        onSelectionChanged: callback,
      ),
    );
  }
}

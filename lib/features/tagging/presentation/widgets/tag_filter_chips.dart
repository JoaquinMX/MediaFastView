import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tag_entity.dart';
import '../states/tag_state.dart';
import '../view_models/tag_management_view_model.dart';
import 'selectable_tag_chip_strip.dart';
import 'tag_filter_dialog.dart';

/// A widget that displays filterable tag chips for multi-select filtering.
/// Allows users to select/deselect tags to filter content.
class TagFilterChips extends ConsumerWidget {
  const TagFilterChips({
    super.key,
    required this.selectedTagIds,
    required this.onSelectionChanged,
    this.onTagTapped,
    this.maxChipsToShow,
    this.showAllButton = true,
  });

  final List<String> selectedTagIds;
  final ValueChanged<List<String>> onSelectionChanged;
  final Future<void> Function(TagEntity tag, bool isSelected)? onTagTapped;
  final int? maxChipsToShow;
  final bool showAllButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagState = ref.watch(tagViewModelProvider);

    return switch (tagState) {
      TagLoaded(:final tags) => SelectableTagChipStrip(
          tags: tags,
          selectedTagIds: selectedTagIds,
          onSelectionChanged: onSelectionChanged,
          onTagTapped: onTagTapped,
          maxChipsToShow: maxChipsToShow,
          showAllChip: showAllButton && onTagTapped == null,
          onOverflowPressed: _shouldShowOverflow(tags.length)
              ? () => _showAllTagsDialog(context)
              : null,
        ),
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

  bool _shouldShowOverflow(int tagCount) =>
      maxChipsToShow != null && tagCount > maxChipsToShow!;

  void _showAllTagsDialog(BuildContext context) {
    TagFilterDialog.show(
      context,
      selectedTagIds: selectedTagIds,
      onSelectionChanged: onSelectionChanged,
    );
  }
}

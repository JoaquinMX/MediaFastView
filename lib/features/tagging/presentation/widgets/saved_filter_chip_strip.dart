import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../domain/entities/saved_filter_entity.dart';

/// What the chip's context menu asked for.
enum SavedFilterAction { update, rename, delete }

/// The saved filters, as a row of chips at the top of the Tags tab.
///
/// One tap to switch between saved views — the whole point of the feature, and
/// the reason this is not buried in a menu. Right-click or long-press a chip for
/// update / rename / delete.
class SavedFilterChipStrip extends StatelessWidget {
  const SavedFilterChipStrip({
    super.key,
    required this.filters,
    required this.appliedFilterId,
    required this.onApply,
    required this.onClear,
    required this.onAction,
  });

  final List<SavedFilterEntity> filters;
  final String? appliedFilterId;
  final ValueChanged<SavedFilterEntity> onApply;

  /// Tapping the applied chip again un-applies it.
  final VoidCallback onClear;

  final void Function(SavedFilterEntity filter, SavedFilterAction action)
      onAction;

  @override
  Widget build(BuildContext context) {
    if (filters.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isApplied = filter.id == appliedFilterId;

          return GestureDetector(
            onLongPress: () => _showMenu(context, filter),
            onSecondaryTapDown: (details) =>
                _showMenu(context, filter, at: details.globalPosition),
            child: FilterChip(
              key: ValueKey<String>('saved_filter_${filter.id}'),
              avatar: const Icon(Icons.bookmark_outline, size: 18),
              label: Text(filter.name),
              selected: isApplied,
              onSelected: (_) => isApplied ? onClear() : onApply(filter),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    SavedFilterEntity filter, {
    Offset? at,
  }) async {
    final position = at == null
        ? UiPosition.contextMenu
        : RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy);

    final action = await showMenu<SavedFilterAction>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem(
          value: SavedFilterAction.update,
          child: Text('Update from current filter'),
        ),
        const PopupMenuItem(
          value: SavedFilterAction.rename,
          child: Text('Rename…'),
        ),
        const PopupMenuItem(
          value: SavedFilterAction.delete,
          child: Text('Delete'),
        ),
      ],
    );

    if (action != null) {
      onAction(filter, action);
    }
  }
}

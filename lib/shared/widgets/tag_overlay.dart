import 'package:flutter/material.dart';

import '../../features/tagging/domain/entities/tag_entity.dart';
import '../../features/tagging/presentation/widgets/tag_chip.dart';

/// Overlay widget that renders tag chips with a semi-transparent backdrop.
///
/// The overlay mirrors the appearance used by the full-screen viewer and can
/// be composed into other displays (e.g., slideshows) to surface available
/// tags alongside media controls.
class TagOverlay extends StatelessWidget {
  const TagOverlay({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    this.onTagTapped,
    this.emptyLabel = 'No tags available',
    this.compact = true,
  });

  final List<TagEntity> tags;
  final Set<String> selectedTagIds;
  final ValueChanged<TagEntity>? onTagTapped;
  final String emptyLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildChips(theme, colorScheme)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChips(ThemeData theme, ColorScheme colorScheme) {
    if (tags.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            emptyLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }

    final chipWidgets = <Widget>[];
    for (final tag in tags) {
      chipWidgets.add(
        TagChip(
          key: ValueKey('tag_overlay_${tag.id}'),
          tag: tag,
          selected: selectedTagIds.contains(tag.id),
          compact: compact,
          onTap: onTagTapped != null ? () => onTagTapped!(tag) : null,
        ),
      );
      chipWidgets.add(const SizedBox(width: 8));
    }

    if (chipWidgets.isNotEmpty) {
      chipWidgets.removeLast();
    }

    return chipWidgets;
  }
}


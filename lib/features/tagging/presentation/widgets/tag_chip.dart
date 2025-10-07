import 'package:flutter/material.dart';

import '../../domain/entities/tag_entity.dart';

/// A chip widget for displaying tags with customizable appearance.
/// Shows the tag name with its associated color and provides optional actions.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.tag,
    this.onTap,
    this.onLongPress,
    this.onDeleted,
    this.selected = false,
    this.showDeleteIcon = false,
    this.compact = false,
  });

  final TagEntity tag;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDeleted;
  final bool selected;
  final bool showDeleteIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(tag.color);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Chip(
        label: Text(
          tag.name,
          style: TextStyle(
            color: selected ? Colors.white : _getContrastColor(color),
            fontSize: compact ? 12 : 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        backgroundColor: selected
            ? color.withValues(alpha: 0.9)
            : color.withValues(alpha: 0.1),
        side: BorderSide(
          color: selected ? color : color.withValues(alpha: 0.3),
          width: selected ? 2 : 1,
        ),
        deleteIcon: showDeleteIcon ? const Icon(Icons.close, size: 16) : null,
        onDeleted: showDeleteIcon ? onDeleted : null,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 2 : 4,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  /// Determines the best contrast color (black or white) for the given background color.
  Color _getContrastColor(Color backgroundColor) {
    final luminance = backgroundColor.computeLuminance();

    // Return white for dark backgrounds, black for light backgrounds.
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }
}

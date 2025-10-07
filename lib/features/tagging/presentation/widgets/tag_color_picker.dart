import 'package:flutter/material.dart';

/// A color picker widget for selecting tag colors.
/// Displays a grid of predefined colors that users can select from.
class TagColorPicker extends StatefulWidget {
  const TagColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.colors,
  });

  final int selectedColor;
  final ValueChanged<int> onColorSelected;
  final List<int>? colors;

  @override
  State<TagColorPicker> createState() => _TagColorPickerState();
}

class _TagColorPickerState extends State<TagColorPicker> {
  // Default color palette for tags
  static const List<int> _defaultColors = [
    0xFF2196F3, // Blue
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF00BCD4, // Cyan
    0xFF8BC34A, // Light Green
    0xFFFF5722, // Deep Orange
    0xFF3F51B5, // Indigo
    0xFF009688, // Teal
    0xFF795548, // Brown
    0xFF607D8B, // Blue Grey
    0xFFFFC107, // Amber
    0xFFCDDC39, // Lime
    0xFFF44336, // Red
    0xFF673AB7, // Deep Purple
  ];

  late final List<int> _colors;

  @override
  void initState() {
    super.initState();
    _colors = widget.colors ?? _defaultColors;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose Color', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _colors.map((color) {
            final isSelected = color == widget.selectedColor;
            return _ColorOption(
              color: color,
              isSelected: isSelected,
              onTap: () => widget.onColorSelected(color),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// A single color option in the color picker grid.
class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final int color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: _getContrastColor(Color(color)),
                size: 20,
              )
            : null,
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

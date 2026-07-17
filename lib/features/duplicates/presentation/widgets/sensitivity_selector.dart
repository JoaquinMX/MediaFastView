import 'package:flutter/material.dart';

import '../../domain/entities/duplicate_sensitivity.dart';

/// Segmented control for the match sensitivity, with the active level's helper
/// text beneath it. Changing it re-clusters cached hashes, so it is cheap.
class SensitivitySelector extends StatelessWidget {
  const SensitivitySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DuplicateSensitivity value;
  final ValueChanged<DuplicateSensitivity> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Match sensitivity', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<DuplicateSensitivity>(
          segments: [
            for (final level in DuplicateSensitivity.values)
              ButtonSegment<DuplicateSensitivity>(
                value: level,
                label: Text(level.label),
              ),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: 6),
        Text(
          value.helperText,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

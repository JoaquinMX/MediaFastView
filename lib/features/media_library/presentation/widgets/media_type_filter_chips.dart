import 'package:flutter/material.dart';

import '../../domain/entities/media_entity.dart';

class MediaTypeFilterChips extends StatelessWidget {
  const MediaTypeFilterChips({
    super.key,
    required this.selectedTypes,
    required this.onSelectionChanged,
  });

  final Set<MediaType> selectedTypes;
  final ValueChanged<Set<MediaType>> onSelectionChanged;

  static const List<_MediaTypeFilterOption> _filterOptions = <_MediaTypeFilterOption>[
    _MediaTypeFilterOption(
      type: MediaType.video,
      label: 'Videos',
      icon: Icons.videocam_outlined,
    ),
    _MediaTypeFilterOption(
      type: MediaType.image,
      label: 'Images',
      icon: Icons.photo_outlined,
    ),
    _MediaTypeFilterOption(
      type: MediaType.directory,
      label: 'Directories',
      icon: Icons.folder_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ActionChip(
          label: const Text('All'),
          avatar: const Icon(Icons.select_all),
          onPressed: () => onSelectionChanged(<MediaType>{}),
        ),
        ..._filterOptions.map((option) {
          final isSelected = selectedTypes.contains(option.type);
          return FilterChip(
            label: Text(option.label),
            avatar: Icon(option.icon, size: 18),
            selected: isSelected,
            onSelected: (selected) => _onChipToggled(option.type, selected),
          );
        }),
      ],
    );
  }

  void _onChipToggled(MediaType type, bool selected) {
    final updatedSelection = Set<MediaType>.from(selectedTypes);
    if (selected) {
      updatedSelection.add(type);
    } else {
      updatedSelection.remove(type);
    }

    if (updatedSelection.isEmpty) {
      onSelectionChanged(<MediaType>{});
      return;
    }

    onSelectionChanged(updatedSelection);
  }
}

class _MediaTypeFilterOption {
  const _MediaTypeFilterOption({
    required this.type,
    required this.label,
    required this.icon,
  });

  final MediaType type;
  final String label;
  final IconData icon;
}

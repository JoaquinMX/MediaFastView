import 'package:flutter/material.dart';

import '../view_models/library_sort_option.dart';

/// Popup menu button for selecting library sort options.
class LibrarySortMenuButton extends StatelessWidget {
  const LibrarySortMenuButton({
    super.key,
    required this.selectedOption,
    required this.onSelected,
    this.enabled = true,
  });

  final LibrarySortOption selectedOption;
  final ValueChanged<LibrarySortOption> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<LibrarySortOption>(
      enabled: enabled,
      tooltip: 'Sort',
      initialValue: selectedOption,
      icon: const Icon(Icons.sort),
      onSelected: onSelected,
      itemBuilder: (context) {
        return LibrarySortOption.values
            .map(
              (option) => PopupMenuItem<LibrarySortOption>(
                value: option,
                child: Row(
                  children: [
                    Icon(option.icon),
                    const SizedBox(width: 8),
                    Text(option.label),
                  ],
                ),
              ),
            )
            .toList();
      },
    );
  }
}

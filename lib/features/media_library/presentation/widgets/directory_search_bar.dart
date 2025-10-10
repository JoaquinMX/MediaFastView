import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/directory_grid_view_model.dart';

/// Search bar widget for filtering directories.
class DirectorySearchBar extends ConsumerWidget {
  const DirectorySearchBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(directoryViewModelProvider);
    final viewModel = ref.read(directoryViewModelProvider.notifier);

    final searchQuery = switch (state) {
      DirectoryLoaded(:final searchQuery) => searchQuery,
      DirectoryPermissionRevoked(:final searchQuery) => searchQuery,
      DirectoryBookmarkInvalid(:final searchQuery) => searchQuery,
      _ => '',
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search directories...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: viewModel.searchDirectories,
        controller: TextEditingController(text: searchQuery)
          ..selection = TextSelection.collapsed(offset: searchQuery.length),
      ),
    );
  }
}

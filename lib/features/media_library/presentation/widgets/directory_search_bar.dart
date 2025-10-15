import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/directory_grid_view_model.dart';

/// Search bar widget for filtering directories.
class DirectorySearchBar extends ConsumerStatefulWidget {
  const DirectorySearchBar({super.key});

  @override
  ConsumerState<DirectorySearchBar> createState() => _DirectorySearchBarState();
}

class _DirectorySearchBarState extends ConsumerState<DirectorySearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _extractSearchQuery(ref.read(directoryViewModelProvider)),
    );
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _extractSearchQuery(DirectoryState state) {
    return switch (state) {
      DirectoryLoaded(:final searchQuery) => searchQuery,
      DirectoryPermissionRevoked(:final searchQuery) => searchQuery,
      DirectoryBookmarkInvalid(:final searchQuery) => searchQuery,
      _ => '',
    };
  }

  void _refocusGrid(BuildContext context) {
    final parentScope = FocusScope.of(context).parent;
    parentScope?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directoryViewModelProvider);
    final viewModel = ref.read(directoryViewModelProvider.notifier);

    final searchQuery = _extractSearchQuery(state);
    if (_controller.text != searchQuery) {
      _controller.value = TextEditingValue(
        text: searchQuery,
        selection: TextSelection.collapsed(offset: searchQuery.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final hasQuery = value.text.isNotEmpty;
          return TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Search directories...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        viewModel.searchDirectories('');
                        _refocusGrid(context);
                      },
                    )
                  : null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            onChanged: viewModel.searchDirectories,
            onSubmitted: (_) => _refocusGrid(context),
          );
        },
      ),
    );
  }
}

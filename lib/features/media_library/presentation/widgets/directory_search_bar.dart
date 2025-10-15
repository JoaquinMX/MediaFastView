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
  bool _isUpdatingText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    // Rebuild to reflect suffix icon visibility changes.
    setState(() {});
  }

  void _updateControllerText(String text) {
    if (_controller.text == text) {
      return;
    }
    _isUpdatingText = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _handleSubmitted(String value, DirectoryViewModel viewModel) {
    viewModel.searchDirectories(value);
    final parentFocus = Focus.of(context).parent;
    if (parentFocus != null) {
      parentFocus.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  void _clearSearch(DirectoryViewModel viewModel) {
    if (_controller.text.isEmpty) {
      return;
    }
    _isUpdatingText = true;
    _controller.clear();
    viewModel.searchDirectories('');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(directoryViewModelProvider);
    final viewModel = ref.read(directoryViewModelProvider.notifier);

    final searchQuery = switch (state) {
      DirectoryLoaded(:final searchQuery) => searchQuery,
      DirectoryPermissionRevoked(:final searchQuery) => searchQuery,
      DirectoryBookmarkInvalid(:final searchQuery) => searchQuery,
      _ => '',
    };

    _updateControllerText(searchQuery);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Search directories...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () => _clearSearch(viewModel),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        textInputAction: TextInputAction.search,
        onChanged: (value) {
          if (_isUpdatingText) {
            _isUpdatingText = false;
            return;
          }
          viewModel.searchDirectories(value);
        },
        onSubmitted: (value) => _handleSubmitted(value, viewModel),
      ),
    );
  }
}

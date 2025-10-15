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
  late final FocusNode _focusNode;
  late final ProviderSubscription<DirectoryState> _directorySubscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _extractSearchQuery(ref.read(directoryViewModelProvider)),
    );
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    _focusNode = FocusNode();

    _directorySubscription =
        ref.listen<DirectoryState>(directoryViewModelProvider, (previous, next) {
      final nextQuery = _extractSearchQuery(next);
      if (nextQuery == _controller.text) {
        return;
      }

      if (_focusNode.hasPrimaryFocus) {
        return;
      }

      _controller.value = TextEditingValue(
        text: nextQuery,
        selection: TextSelection.collapsed(offset: nextQuery.length),
      );
    });
  }

  @override
  void dispose() {
    _directorySubscription.close();
    _focusNode.dispose();
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
    ref.watch(directoryViewModelProvider);
    final viewModel = ref.read(directoryViewModelProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          final hasQuery = value.text.isNotEmpty;
          return TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search directories...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasQuery
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(end: 4),
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            _controller.clear();
                            viewModel.searchDirectories('');
                            _refocusGrid(context);
                          },
                          child: const SizedBox(
                            height: 40,
                            width: 40,
                            child: Icon(Icons.clear),
                          ),
                        ),
                      ),
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

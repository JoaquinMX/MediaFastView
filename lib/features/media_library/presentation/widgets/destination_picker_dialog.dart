import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/logging_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/directory_entity.dart';

/// A folder the user picked as a transfer destination.
class DestinationPickerResult {
  const DestinationPickerResult({
    required this.path,
    required this.name,
    this.bookmarkData,
  });

  final String path;
  final String name;

  /// The bookmark that grants sandboxed access to [path]. Note this is not
  /// necessarily the folder's *own* bookmark — for a subfolder it is the
  /// enclosing library root's, which covers everything beneath it.
  final String? bookmarkData;
}

/// Picks a destination folder for a move or copy.
///
/// Browses the tracked library roots and their subfolders — which keeps the
/// choice inside a bookmark the app already holds — and offers "Choose Folder…"
/// for anywhere else, since the native panel grants access to whatever the user
/// selects.
class DestinationPickerDialog extends ConsumerStatefulWidget {
  const DestinationPickerDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    this.initialPath,
    this.disabledPath,
    this.forbiddenSubtreePath,
  });

  final String title;
  final String confirmLabel;

  /// Where to open the browser, if it is inside a tracked root.
  final String? initialPath;

  /// The item's current folder. Confirming there would be a no-op.
  final String? disabledPath;

  /// A folder being moved: it cannot be dropped inside itself.
  final String? forbiddenSubtreePath;

  static Future<DestinationPickerResult?> show(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? initialPath,
    String? disabledPath,
    String? forbiddenSubtreePath,
  }) {
    return showDialog<DestinationPickerResult>(
      context: context,
      builder: (_) => DestinationPickerDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialPath: initialPath,
        disabledPath: disabledPath,
        forbiddenSubtreePath: forbiddenSubtreePath,
      ),
    );
  }

  @override
  ConsumerState<DestinationPickerDialog> createState() =>
      _DestinationPickerDialogState();
}

class _DestinationPickerDialogState
    extends ConsumerState<DestinationPickerDialog> {
  /// The root whose bookmark covers [_currentPath]; null while showing the root
  /// list itself.
  DirectoryEntity? _activeRoot;
  String? _currentPath;
  bool _choosingExternally = false;

  @override
  Widget build(BuildContext context) {
    final rootsAsync = ref.watch(trackedDirectoriesProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBreadcrumb(context),
            const Divider(height: 1),
            Expanded(
              child: _currentPath == null
                  ? _buildRootList(rootsAsync)
                  : _buildSubdirectoryList(),
            ),
            const Divider(height: 1),
            _buildChooseFolderTile(context),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        _buildConfirmButton(context),
      ],
    );
  }

  Widget _buildBreadcrumb(BuildContext context) {
    final root = _activeRoot;
    final current = _currentPath;

    if (root == null || current == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Text('Choose a folder'),
      );
    }

    final relative = p.relative(current, from: root.path);
    final segments = relative == '.' ? <String>[] : p.split(relative);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _goUp,
          ),
          Expanded(
            child: Text(
              [root.name, ...segments].join(' / '),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRootList(AsyncValue<List<DirectoryEntity>> rootsAsync) {
    return rootsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Could not load folders: $error')),
      data: (roots) {
        if (roots.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No folders in your library yet. Use "Choose Folder…" to pick '
                'one.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: roots.length,
          itemBuilder: (context, index) {
            final root = roots[index];
            return _buildFolderTile(
              path: root.path,
              name: root.name,
              onTap: () => setState(() {
                _activeRoot = root;
                _currentPath = root.path;
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildSubdirectoryList() {
    final root = _activeRoot!;
    final current = _currentPath!;
    final childrenAsync = ref.watch(
      subdirectoriesProvider(
        SubdirectoryQuery(path: current, bookmarkData: root.bookmarkData),
      ),
    );

    return childrenAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('Could not read that folder: $error')),
      data: (children) {
        if (children.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No subfolders here.'),
            ),
          );
        }

        return ListView.builder(
          itemCount: children.length,
          itemBuilder: (context, index) {
            final child = children[index];
            return _buildFolderTile(
              path: child,
              name: p.basename(child),
              onTap: () => setState(() => _currentPath = child),
            );
          },
        );
      },
    );
  }

  Widget _buildFolderTile({
    required String path,
    required String name,
    required VoidCallback onTap,
  }) {
    // A folder cannot be moved inside itself, so its own subtree is off limits
    // as a destination.
    final forbidden = _isForbidden(path);

    return ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(name, overflow: TextOverflow.ellipsis),
      enabled: !forbidden,
      subtitle: forbidden ? const Text("You can't move a folder into itself") : null,
      onTap: forbidden ? null : onTap,
    );
  }

  Widget _buildChooseFolderTile(BuildContext context) {
    return ListTile(
      leading: _choosingExternally
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.folder_open),
      title: const Text('Choose Folder…'),
      subtitle: const Text('Pick any folder on this Mac'),
      onTap: _choosingExternally ? null : _chooseExternalFolder,
    );
  }

  Widget _buildConfirmButton(BuildContext context) {
    final current = _currentPath;
    final blockedReason = current == null
        ? 'Pick a folder first'
        : _confirmBlockedReason(current);

    final button = FilledButton(
      onPressed: blockedReason != null
          ? null
          : () => Navigator.of(context).pop(
              DestinationPickerResult(
                path: current!,
                name: p.basename(current),
                bookmarkData: _activeRoot?.bookmarkData,
              ),
            ),
      child: Text(widget.confirmLabel),
    );

    return blockedReason == null
        ? button
        : Tooltip(message: blockedReason, child: button);
  }

  String? _confirmBlockedReason(String path) {
    if (widget.disabledPath != null &&
        p.equals(path, widget.disabledPath!)) {
      return 'The item is already in this folder';
    }
    if (_isForbidden(path)) {
      return "You can't move a folder into itself";
    }
    return null;
  }

  bool _isForbidden(String path) {
    final forbidden = widget.forbiddenSubtreePath;
    if (forbidden == null) {
      return false;
    }
    return p.equals(path, forbidden) || p.isWithin(forbidden, path);
  }

  void _goUp() {
    final root = _activeRoot;
    final current = _currentPath;
    if (root == null || current == null) {
      return;
    }

    if (p.equals(current, root.path)) {
      // Back out of the root entirely, to the list of library roots.
      setState(() {
        _activeRoot = null;
        _currentPath = null;
      });
      return;
    }
    setState(() => _currentPath = p.dirname(current));
  }

  /// Opens the native folder panel. Selecting a folder there is what grants the
  /// sandbox access to it, and the bookmark it hands back is exactly what the
  /// transfer needs — so this works for destinations outside the library.
  Future<void> _chooseExternalFolder() async {
    setState(() => _choosingExternally = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final selection = await ref
          .read(bookmarkServiceProvider)
          .selectDirectoryAndCreateBookmark(
            initialDirectoryPath: _currentPath,
          );

      final path = selection['directoryPath'] as String?;
      final bookmarkData = selection['bookmarkData'] as String?;
      if (path == null) {
        return;
      }

      if (_isForbidden(path)) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("You can't move a folder into itself"),
          ),
        );
        return;
      }

      navigator.pop(
        DestinationPickerResult(
          path: path,
          name: p.basename(path),
          bookmarkData: bookmarkData,
        ),
      );
    } catch (e) {
      // The panel throws on cancel too, so this is not necessarily a failure.
      LoggingService.instance.debug('Folder selection ended without a pick: $e');
    } finally {
      if (mounted) {
        setState(() => _choosingExternally = false);
      }
    }
  }
}

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/directory_access_grant.dart';
import '../../../../core/services/directory_browser_service.dart';

/// Lets users select several directories beneath one system-granted parent.
final class DirectoryMultiSelectBrowserDialog extends StatefulWidget {
  const DirectoryMultiSelectBrowserDialog({
    required this.rootGrant,
    required this.listChildren,
    required this.createGrants,
    super.key,
  });

  final DirectoryAccessGrant rootGrant;
  final Future<List<BrowsableDirectory>> Function(
    DirectoryAccessGrant rootGrant,
    String directoryPath,
  )
  listChildren;
  final Future<List<DirectoryAccessGrant>> Function(
    DirectoryAccessGrant rootGrant,
    Iterable<String> selectedPaths,
  )
  createGrants;

  @override
  State<DirectoryMultiSelectBrowserDialog> createState() =>
      _DirectoryMultiSelectBrowserDialogState();
}

class _DirectoryMultiSelectBrowserDialogState
    extends State<DirectoryMultiSelectBrowserDialog> {
  final LinkedHashSet<String> _selectedPaths = LinkedHashSet<String>();
  late String _currentPath;
  List<BrowsableDirectory> _children = const <BrowsableDirectory>[];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  String get _rootPath => p.normalize(widget.rootGrant.path);

  bool get _isAtRoot => p.equals(_currentPath, _rootPath);

  bool get _allVisibleChildrenSelected =>
      _children.isNotEmpty &&
      _children.every(
        (directory) => _selectedPaths.contains(p.normalize(directory.path)),
      );

  @override
  void initState() {
    super.initState();
    _currentPath = _rootPath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChildren(_rootPath);
    });
  }

  Future<void> _loadChildren(String directoryPath) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final children = await widget.listChildren(
        widget.rootGrant,
        directoryPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _currentPath = p.normalize(directoryPath);
        _children = children;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to open this folder: $error';
      });
    }
  }

  void _togglePath(String directoryPath) {
    final normalizedPath = p.normalize(directoryPath);
    setState(() {
      if (!_selectedPaths.remove(normalizedPath)) {
        _selectedPaths.add(normalizedPath);
      }
    });
  }

  void _toggleVisibleChildren() {
    setState(() {
      if (_allVisibleChildrenSelected) {
        for (final child in _children) {
          _selectedPaths.remove(p.normalize(child.path));
        }
      } else {
        for (final child in _children) {
          _selectedPaths.add(p.normalize(child.path));
        }
      }
    });
  }

  Future<void> _goBack() async {
    if (_isAtRoot) {
      return;
    }
    await _loadChildren(p.dirname(_currentPath));
  }

  Future<void> _useSelectedFolders() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final grants = await widget.createGrants(
        widget.rootGrant,
        _selectedPaths,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(grants);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = 'Unable to save folder access: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoading || _isSaving;
    final rootName = p.basename(_rootPath);
    final relativePath = p.relative(_currentPath, from: _rootPath);
    final locationLabel = relativePath == '.'
        ? rootName
        : p.join(rootName, relativePath);

    return AlertDialog(
      title: const Text('Choose Folders'),
      content: SizedBox(
        width: 440,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select this folder or any folders below it. Use the arrow to '
              'open a folder without selecting it.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  tooltip: 'Go to parent folder',
                  onPressed: _isAtRoot || isBusy ? null : _goBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    locationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: _children.isEmpty || isBusy
                      ? null
                      : _toggleVisibleChildren,
                  child: Text(
                    _allVisibleChildrenSelected
                        ? 'Clear visible'
                        : 'Select all',
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _selectedPaths.contains(_currentPath),
              onChanged: isBusy ? null : (_) => _togglePath(_currentPath),
              title: const Text('Include this folder'),
              subtitle: Text(
                p.basename(_currentPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(height: 1),
            Expanded(child: _buildDirectoryList(isBusy)),
            if (_errorMessage case final errorMessage?) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '${_selectedPaths.length} '
              'folder${_selectedPaths.length == 1 ? '' : 's'} selected',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedPaths.isEmpty || isBusy
              ? null
              : _useSelectedFolders,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Use selected folders'),
        ),
      ],
    );
  }

  Widget _buildDirectoryList(bool isBusy) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_children.isEmpty) {
      return const Center(child: Text('No subfolders here.'));
    }

    return ListView.builder(
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];
        final childPath = p.normalize(child.path);
        final isSelected = _selectedPaths.contains(childPath);
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Checkbox(
            value: isSelected,
            onChanged: isBusy ? null : (_) => _togglePath(childPath),
          ),
          title: Text(child.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: isBusy ? null : () => _togglePath(childPath),
          trailing: IconButton(
            tooltip: 'Open ${child.name}',
            onPressed: isBusy ? null : () => _loadChildren(childPath),
            icon: const Icon(Icons.chevron_right),
          ),
        );
      },
    );
  }
}

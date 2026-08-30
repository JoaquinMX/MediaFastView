import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/directory_access_grant.dart';
import '../../../../core/services/directory_browser_service.dart';
import '../view_models/directory_grid_view_model.dart';
import 'directory_multi_select_browser_dialog.dart';

/// Stages one or more picker results for a batch directory addition.
final class AddDirectoriesDialog extends StatefulWidget {
  const AddDirectoriesDialog({
    required this.description,
    required this.pickDirectories,
    required this.addDirectories,
    this.pickParentDirectory,
    this.listChildDirectories,
    this.createChildGrants,
    super.key,
  }) : assert(
         (pickParentDirectory == null &&
                 listChildDirectories == null &&
                 createChildGrants == null) ||
             (pickParentDirectory != null &&
                 listChildDirectories != null &&
                 createChildGrants != null),
         'Parent browsing callbacks must be provided together.',
       );

  final String description;
  final Future<List<DirectoryAccessGrant>> Function() pickDirectories;
  final Future<DirectoryAccessGrant?> Function()? pickParentDirectory;
  final Future<List<BrowsableDirectory>> Function(
    DirectoryAccessGrant rootGrant,
    String directoryPath,
  )?
  listChildDirectories;
  final Future<List<DirectoryAccessGrant>> Function(
    DirectoryAccessGrant rootGrant,
    Iterable<String> selectedPaths,
  )?
  createChildGrants;
  final Future<DirectoryAddBatchResult> Function(
    Iterable<DirectoryAccessGrant> grants,
  )
  addDirectories;

  @override
  State<AddDirectoriesDialog> createState() => _AddDirectoriesDialogState();
}

class _AddDirectoriesDialogState extends State<AddDirectoriesDialog> {
  final LinkedHashMap<String, DirectoryAccessGrant> _selectedGrantsByPath =
      LinkedHashMap<String, DirectoryAccessGrant>();
  bool _isBrowsing = false;
  bool _isAdding = false;

  bool get _supportsParentBrowsing => widget.pickParentDirectory != null;

  void _stageGrants(Iterable<DirectoryAccessGrant> grants) {
    for (final grant in grants) {
      if (grant.path.isEmpty) {
        continue;
      }
      _selectedGrantsByPath[p.normalize(grant.path)] = grant;
    }
  }

  Future<void> _browse() async {
    setState(() {
      _isBrowsing = true;
    });

    try {
      final selectedGrants = await widget.pickDirectories();
      if (!mounted) {
        return;
      }
      setState(() {
        _stageGrants(selectedGrants);
        _isBrowsing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBrowsing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select directory: $error')),
      );
    }
  }

  Future<void> _browseParent() async {
    setState(() {
      _isBrowsing = true;
    });

    try {
      final parentGrant = await widget.pickParentDirectory!();
      if (!mounted) {
        return;
      }
      setState(() {
        _isBrowsing = false;
      });
      if (parentGrant == null) {
        return;
      }

      final selectedGrants = await showDialog<List<DirectoryAccessGrant>>(
        context: context,
        builder: (context) => DirectoryMultiSelectBrowserDialog(
          rootGrant: parentGrant,
          listChildren: widget.listChildDirectories!,
          createGrants: widget.createChildGrants!,
        ),
      );
      if (!mounted || selectedGrants == null) {
        return;
      }
      setState(() {
        _stageGrants(selectedGrants);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isBrowsing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to browse parent folder: $error')),
      );
    }
  }

  Future<void> _addSelected() async {
    setState(() {
      _isAdding = true;
    });

    try {
      final result = await widget.addDirectories(
        _selectedGrantsByPath.values.toList(growable: false),
      );
      if (!mounted) {
        return;
      }

      final successfulCount = result.successfulPaths.length;
      final failureCount = result.failureReasonsByPath.length;
      final message = switch ((successfulCount, failureCount)) {
        (0, 0) => 'No directories were added',
        (0, _) =>
          'No directories were added: '
              '${result.failureReasonsByPath.values.first}',
        (_, 0) =>
          'Added $successfulCount '
              'director${successfulCount == 1 ? 'y' : 'ies'}',
        _ =>
          'Added $successfulCount '
              'director${successfulCount == 1 ? 'y' : 'ies'}; '
              '$failureCount failed',
      };
      final messenger = ScaffoldMessenger.of(context);

      if (failureCount == 0 && successfulCount > 0) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          for (final successfulPath in result.successfulPaths) {
            _selectedGrantsByPath.remove(p.normalize(successfulPath));
          }
          _isAdding = false;
        });
      }
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isAdding = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add directories: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isBrowsing || _isAdding;
    final selectedGrants = _selectedGrantsByPath.values.toList(growable: false);

    return AlertDialog(
      scrollable: true,
      title: const Text('Add Directories'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            if (_supportsParentBrowsing) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _browseParent,
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Choose from a parent folder'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Best when the folders you want are in the same location.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : _browse,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('Add an individual folder'),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Use this for folders in different locations.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
            ],
            if (selectedGrants.isEmpty)
              const Text('No directories selected yet.')
            else ...[
              Text(
                '${selectedGrants.length} '
                'director${selectedGrants.length == 1 ? 'y' : 'ies'} selected',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List<Widget>.generate(selectedGrants.length, (
                      index,
                    ) {
                      final path = selectedGrants[index].path;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder),
                        title: Text(
                          p.basename(path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Remove ${p.basename(path)}',
                          onPressed: isBusy
                              ? null
                              : () {
                                  setState(() {
                                    _selectedGrantsByPath.remove(
                                      p.normalize(path),
                                    );
                                  });
                                },
                          icon: const Icon(Icons.close),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_supportsParentBrowsing)
          OutlinedButton.icon(
            onPressed: isBusy ? null : _browse,
            icon: const Icon(Icons.folder_open),
            label: Text(selectedGrants.isEmpty ? 'Browse' : 'Add another'),
          ),
        ElevatedButton(
          onPressed: selectedGrants.isEmpty || isBusy ? null : _addSelected,
          child: const Text('Add selected'),
        ),
      ],
    );
  }
}

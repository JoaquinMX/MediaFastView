import 'package:flutter/material.dart';

import '../../../media_library/domain/entities/directory_entity.dart';
import '../../domain/entities/sidecar_import_preparation.dart';

/// Prompts for moved library-root mappings before a portable backup is loaded.
Future<Map<String, String?>?> showSidecarRootMappingDialog(
  BuildContext context,
  SidecarImportPreparation preparation,
) {
  if (preparation.unmatchedRoots.isEmpty) {
    return Future<Map<String, String?>?>.value(<String, String?>{
      ...preparation.automaticRootMappings,
    });
  }
  return showDialog<Map<String, String?>>(
    context: context,
    builder: (context) => _SidecarRootMappingDialog(preparation: preparation),
  );
}

class _SidecarRootMappingDialog extends StatefulWidget {
  const _SidecarRootMappingDialog({required this.preparation});

  final SidecarImportPreparation preparation;

  @override
  State<_SidecarRootMappingDialog> createState() =>
      _SidecarRootMappingDialogState();
}

class _SidecarRootMappingDialogState extends State<_SidecarRootMappingDialog> {
  static const String _skipValue = '__skip__';

  late final Map<String, String?> _selectedRootIds = <String, String?>{
    for (final root in widget.preparation.unmatchedRoots)
      root.originalPath: null,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Map Library Folders'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Some folders have moved since this backup was created. '
                'Choose the current library folder for each saved folder, or '
                'skip it.',
              ),
              const SizedBox(height: 20),
              for (final savedRoot in widget.preparation.unmatchedRoots) ...[
                Text(
                  savedRoot.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  savedRoot.originalPath,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'sidecar-root-mapping-${savedRoot.originalPath}',
                  ),
                  initialValue:
                      _selectedRootIds[savedRoot.originalPath] ?? _skipValue,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Current library folder',
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: _skipValue,
                      child: Text('Skip this folder'),
                    ),
                    for (final currentRoot in _availableRoots(
                      savedRoot.originalPath,
                    ))
                      DropdownMenuItem<String>(
                        value: currentRoot.id,
                        child: Text(
                          '${currentRoot.name} — ${currentRoot.path}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRootIds[savedRoot.originalPath] =
                          value == _skipValue ? null : value;
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(<String, String?>{
              ...widget.preparation.automaticRootMappings,
              ..._selectedRootIds,
            });
          },
          child: const Text('Load'),
        ),
      ],
    );
  }

  Iterable<DirectoryEntity> _availableRoots(String savedPath) {
    final usedRootIds = <String>{
      ...widget.preparation.automaticRootMappings.values,
      for (final entry in _selectedRootIds.entries)
        if (entry.key != savedPath && entry.value != null) entry.value!,
    };
    return widget.preparation.currentRoots.where(
      (root) => !usedRootIds.contains(root.id),
    );
  }
}

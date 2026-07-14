import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/profile_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../domain/profile_validation.dart';

/// Chooses which profiles track a directory.
///
/// This is how a folder is shared: ticking another profile makes it appear there
/// with no folder picker and no rescan, because it is the same row underneath —
/// same bookmark, same scan cache.
class DirectoryProfileDialog extends ConsumerStatefulWidget {
  const DirectoryProfileDialog({super.key, required this.directory});

  final DirectoryEntity directory;

  static Future<void> show(BuildContext context, DirectoryEntity directory) {
    return showDialog<void>(
      context: context,
      builder: (_) => DirectoryProfileDialog(directory: directory),
    );
  }

  @override
  ConsumerState<DirectoryProfileDialog> createState() =>
      _DirectoryProfileDialogState();
}

class _DirectoryProfileDialogState
    extends ConsumerState<DirectoryProfileDialog> {
  late Set<String> _selected = widget.directory.profileIds.toSet();

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider);

    return AlertDialog(
      title: Text('Profiles for "${widget.directory.name}"'),
      content: SizedBox(
        width: 420,
        child: profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load profiles: $error'),
          data: (list) => ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final profile in list)
                CheckboxListTile(
                  value: _selected.contains(profile.id),
                  title: Text(profile.name),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selected.add(profile.id);
                    } else {
                      _selected.remove(profile.id);
                    }
                  }),
                ),
              if (_selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'A folder must belong to at least one profile. To take it '
                    'out of the library entirely, remove it from the Library '
                    'tab instead.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    try {
      await ref.read(setDirectoryProfilesUseCaseProvider)(
        widget.directory.path,
        _selected,
      );
    } on ProfileValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    // The active profile may have just lost — or gained — this folder.
    ref.invalidate(trackedDirectoriesProvider);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

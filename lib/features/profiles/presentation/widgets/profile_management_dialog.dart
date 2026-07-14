import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/active_profile_provider.dart';
import '../../../../shared/providers/profile_providers.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/profile_validation.dart';

/// Create, rename and delete profiles.
///
/// Reached from "Manage profiles…" at the bottom of the app-bar switcher.
class ProfileManagementDialog extends ConsumerWidget {
  const ProfileManagementDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ProfileManagementDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return AlertDialog(
      title: const Text('Profiles'),
      content: SizedBox(
        width: 420,
        child: profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Could not load profiles: $error'),
          data: (list) => ListView(
            shrinkWrap: true,
            children: <Widget>[
              for (final profile in list)
                ListTile(
                  leading: Icon(
                    profile.id == activeId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(profile.name),
                  onTap: () => ref
                      .read(activeProfileIdProvider.notifier)
                      .switchTo(profile.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Rename',
                        onPressed: () => _rename(context, ref, profile),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete',
                        // The app always needs a profile to be scoped to, so the
                        // last one cannot go.
                        onPressed: list.length <= 1
                            ? null
                            : () => _delete(context, ref, profile),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _create(context, ref),
          child: const Text('New profile'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final name = await _promptForName(context, title: 'New profile');
    if (name == null) {
      return;
    }

    await _runGuarded(context, () async {
      await ref.read(createProfileUseCaseProvider)(name);
      ref.invalidate(profilesProvider);
    });
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    ProfileEntity profile,
  ) async {
    final name = await _promptForName(
      context,
      title: 'Rename profile',
      initial: profile.name,
    );
    if (name == null) {
      return;
    }

    await _runGuarded(context, () async {
      await ref.read(renameProfileUseCaseProvider)(profile.id, name);
      ref.invalidate(profilesProvider);
    });
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProfileEntity profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${profile.name}"?'),
        content: const Text(
          'Its tags, favorites and saved filters will be deleted. Folders it '
          'shares with another profile stay in the library; folders only it '
          'tracks are removed from the library.\n\n'
          'No files are deleted from disk.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _runGuarded(context, () async {
      final report = await ref.read(deleteProfileUseCaseProvider)(profile.id);

      // Deleting the active profile leaves nothing scoped, so move first, then
      // refresh the list the switcher reads.
      if (ref.read(activeProfileIdProvider) == profile.id) {
        final remaining = await ref.read(getProfilesUseCaseProvider)();
        await ref
            .read(activeProfileIdProvider.notifier)
            .switchTo(remaining.first.id);
      }
      ref.invalidate(profilesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted "${profile.name}". '
              '${report.directoriesDropped} folder(s) removed from the library, '
              '${report.directoriesKept} kept.',
            ),
          ),
        );
      }
    });
  }

  /// Surfaces a validation failure instead of letting it die in the console.
  Future<void> _runGuarded(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ProfileValidationException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<String?> _promptForName(
    BuildContext context, {
    required String title,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

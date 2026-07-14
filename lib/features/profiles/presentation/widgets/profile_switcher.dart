import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/active_profile_provider.dart';
import '../../../../shared/providers/profile_providers.dart';
import 'profile_management_dialog.dart';

/// The app-bar profile selector.
///
/// Sits in the `title` slot of the Library and Tags app bars — the two tabs whose
/// contents a profile actually scopes. Deliberately absent from the selection app
/// bars: switching profile mid-selection would strand a selection of items the
/// new profile cannot see.
class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({super.key, required this.fallbackTitle});

  /// Shown while the profile list is still loading, so the app bar does not pop
  /// in. It is the title the screen had before profiles existed.
  final String fallbackTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final activeId = ref.watch(activeProfileIdProvider);

    return profiles.when(
      loading: () => Text(fallbackTitle),
      error: (_, __) => Text(fallbackTitle),
      data: (list) {
        final active =
            list.firstWhereOrNull((profile) => profile.id == activeId);
        if (active == null) {
          return Text(fallbackTitle);
        }

        return PopupMenuButton<_SwitcherAction>(
          tooltip: 'Switch profile',
          position: PopupMenuPosition.under,
          onSelected: (action) => _onSelected(context, ref, action),
          itemBuilder: (context) => <PopupMenuEntry<_SwitcherAction>>[
            for (final profile in list)
              CheckedPopupMenuItem<_SwitcherAction>(
                value: _Switch(profile.id),
                checked: profile.id == activeId,
                child: Text(profile.name),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem<_SwitcherAction>(
              value: _Manage(),
              child: Text('Manage profiles…'),
            ),
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  active.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onSelected(
    BuildContext context,
    WidgetRef ref,
    _SwitcherAction action,
  ) async {
    switch (action) {
      case _Switch(:final profileId):
        await ref
            .read(activeProfileIdProvider.notifier)
            .switchTo(profileId);
      case _Manage():
        await ProfileManagementDialog.show(context);
    }
  }
}

sealed class _SwitcherAction {
  const _SwitcherAction();
}

class _Switch extends _SwitcherAction {
  const _Switch(this.profileId);

  final String profileId;
}

class _Manage extends _SwitcherAction {
  const _Manage();
}

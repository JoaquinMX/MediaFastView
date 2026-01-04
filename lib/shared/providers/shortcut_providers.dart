import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShortcutAction {
  const ShortcutAction({
    required this.keys,
    required this.description,
    this.contexts = const <String>[],
  });

  final List<String> keys;
  final String description;
  final List<String> contexts;
}

class ShortcutCategory {
  const ShortcutCategory({
    required this.title,
    required this.actions,
  });

  final String title;
  final List<ShortcutAction> actions;
}

const String _fullScreenContext = 'Full-screen viewer';
const String _mediaGridContext = 'Media grids';

final shortcutCategoriesProvider = Provider<List<ShortcutCategory>>((ref) {
  return const <ShortcutCategory>[
    ShortcutCategory(
      title: 'Navigation',
      actions: <ShortcutAction>[
        ShortcutAction(
          keys: <String>['?', 'Shift + /'],
          description: 'Open the keyboard shortcut guide.',
          contexts: <String>[_fullScreenContext, _mediaGridContext],
        ),
        ShortcutAction(
          keys: <String>['Escape'],
          description: 'Exit the viewer or clear the current selection.',
          contexts: <String>[_fullScreenContext, _mediaGridContext],
        ),
        ShortcutAction(
          keys: <String>['Arrow Left', 'Arrow Right'],
          description: 'Navigate between media items.',
          contexts: <String>[_fullScreenContext],
        ),
        ShortcutAction(
          keys: <String>['Arrow Left', 'Arrow Right'],
          description:
              'Move between sibling directories when multiple are available.',
          contexts: <String>[_mediaGridContext],
        ),
        ShortcutAction(
          keys: <String>['Home', 'End'],
          description: 'Jump to the first or last media item.',
          contexts: <String>[_fullScreenContext],
        ),
        ShortcutAction(
          keys: <String>['Page Up', 'Page Down'],
          description: 'Move ten items backward or forward.',
          contexts: <String>[_fullScreenContext],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'Tagging & info',
      actions: <ShortcutAction>[
        ShortcutAction(
          keys: <String>['Ctrl/Cmd + Alt + 1–0'],
          description:
              'Assign or remove the corresponding shortcut tag to the item.',
          contexts: <String>[_fullScreenContext],
        ),
        ShortcutAction(
          keys: <String>['F'],
          description: 'Toggle favorite for the current media item.',
          contexts: <String>[_fullScreenContext],
        ),
        ShortcutAction(
          keys: <String>['I'],
          description: 'Show details for the current media item.',
          contexts: <String>[_fullScreenContext],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'Playback',
      actions: <ShortcutAction>[
        ShortcutAction(
          keys: <String>['Space'],
          description: 'Play or pause the current video.',
          contexts: <String>[_fullScreenContext],
        ),
        ShortcutAction(
          keys: <String>['M'],
          description: 'Mute or unmute video audio.',
          contexts: <String>[_fullScreenContext],
        ),
        ShortcutAction(
          keys: <String>['L'],
          description: 'Toggle looping for the current video.',
          contexts: <String>[_fullScreenContext],
        ),
      ],
    ),
    ShortcutCategory(
      title: 'Selection',
      actions: <ShortcutAction>[
        ShortcutAction(
          keys: <String>['Cmd + A'],
          description: 'Select all visible media items (macOS).',
          contexts: <String>[_mediaGridContext],
        ),
      ],
    ),
  ];
});

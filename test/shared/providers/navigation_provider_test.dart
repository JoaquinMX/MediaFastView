import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/shared/providers/navigation_provider.dart';

void main() {
  group('selectedTabProvider', () {
    test('opens on the Library tab', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedTabProvider), AppTab.library);
    });

    test('can be moved to another tab from outside the navigation bar', () {
      // The whole point of lifting this out of _MainNavigationState: "go to
      // directory" runs from a route pushed over the shell and has to land the
      // user on Library.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedTabProvider.notifier).state = AppTab.tags;
      expect(container.read(selectedTabProvider), AppTab.tags);

      container.read(selectedTabProvider.notifier).state = AppTab.library;
      expect(container.read(selectedTabProvider), AppTab.library);
    });
  });

  group('AppTab', () {
    test('is ordered to match the IndexedStack and BottomNavigationBar', () {
      // MainNavigation indexes the stack with `tab.index` and maps taps back
      // with `AppTab.values[index]`, so this order is load-bearing: reordering
      // the enum would silently send the user to the wrong screen.
      expect(AppTab.values, [AppTab.library, AppTab.tags, AppTab.settings]);
      expect(AppTab.library.index, 0);
      expect(AppTab.tags.index, 1);
      expect(AppTab.settings.index, 2);
    });
  });
}

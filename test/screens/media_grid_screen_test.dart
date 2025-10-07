import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/media_library/presentation/screens/media_grid_screen.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import '../mocks.mocks.dart';

void main() {
  late MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
  });

  group('MediaGridScreen', () {
    const testDirectoryPath = '/test/directory';
    const testDirectoryName = 'Test Directory';

    testWidgets('renders with correct title and app bar actions', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: const MaterialApp(
            home: MediaGridScreen(
              directoryPath: testDirectoryPath,
              directoryName: testDirectoryName,
            ),
          ),
        ),
      );

      expect(find.text(testDirectoryName), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.tag), findsOneWidget);
      expect(find.byIcon(Icons.view_module), findsOneWidget);
    });

    testWidgets('builds without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: const MaterialApp(
            home: MediaGridScreen(
              directoryPath: testDirectoryPath,
              directoryName: testDirectoryName,
            ),
          ),
        ),
      );

      // Just verify the widget builds without crashing
      expect(find.byType(MediaGridScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('has proper UI structure', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: const MaterialApp(
            home: MediaGridScreen(
              directoryPath: testDirectoryPath,
              directoryName: testDirectoryName,
            ),
          ),
        ),
      );

      // Verify basic UI structure
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Container), findsWidgets);
    });
  });
}

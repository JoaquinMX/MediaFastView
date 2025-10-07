import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/main.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import '../mocks.mocks.dart';

void main() {
  late MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();

    // Mock SharedPreferences methods
    when(mockSharedPreferences.getString(any)).thenReturn(null);
    when(mockSharedPreferences.getBool(any)).thenReturn(null);
    when(mockSharedPreferences.getInt(any)).thenReturn(null);
    when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);
  });

  group('Media Loading Integration Tests', () {
    testWidgets('app starts and shows main interface with mocked SharedPreferences', (
      WidgetTester tester,
    ) async {
      // Build the app with mocked SharedPreferences
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: const MyApp(),
        ),
      );

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify that the app has loaded and shows expected UI elements
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('app handles SharedPreferences operations during startup', (
      WidgetTester tester,
    ) async {
      // Setup mock to return some stored data
      when(mockSharedPreferences.getString('directories')).thenReturn('[]');

      // Build the app with mocked SharedPreferences
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: const MyApp(),
        ),
      );

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify that SharedPreferences methods were called during initialization
      verify(mockSharedPreferences.getString('directories')).called(1);

      // Verify the app interface is functional
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('app maintains navigation structure', (
      WidgetTester tester,
    ) async {
      // Build the app with mocked providers
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify navigation elements are present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}

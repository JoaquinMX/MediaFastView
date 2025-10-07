// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/main.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'mocks.mocks.dart';

void main() {
  late MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
  });

  testWidgets('App starts smoke test with mocked providers', (WidgetTester tester) async {
    // Build our app with mocked providers to avoid real SharedPreferences initialization
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
        ],
        child: const MyApp(),
      ),
    );

    // Trigger a frame
    await tester.pump();

    // Verify that our app shows the main navigation elements
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('App handles async initialization properly', (WidgetTester tester) async {
    // Mock async operations that might happen during app initialization
    when(mockSharedPreferences.getString(any)).thenReturn(null);
    when(mockSharedPreferences.getBool(any)).thenReturn(null);
    when(mockSharedPreferences.getInt(any)).thenReturn(null);

    // Build our app with mocked providers
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
        ],
        child: const MyApp(),
      ),
    );

    // Wait for any async operations to complete
    await tester.pumpAndSettle();

    // Verify the app is still functional after async operations
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}

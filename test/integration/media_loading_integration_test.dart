import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/main.dart';

void main() {
  group('Media Loading Integration Tests', () {
    testWidgets('app starts and shows main interface', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify that the app has loaded and shows expected UI elements
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
    });

    testWidgets('app loads without persisted state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // Verify the app interface is functional
      expect(find.byType(BottomNavigationBar), findsOneWidget);
    });

    testWidgets('app maintains navigation structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: MyApp()));

      await tester.pumpAndSettle();

      // Verify navigation elements are present
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}

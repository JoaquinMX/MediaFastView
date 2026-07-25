import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/shared/widgets/confirmation_dialog.dart';

Future<List<bool?>> _openConfirmationDialog(
  WidgetTester tester, {
  bool confirmButtonAutofocus = false,
}) async {
  final results = <bool?>[];

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              results.add(
                await ConfirmationDialog.show(
                  context: context,
                  title: 'Delete file',
                  content: 'Move this file to the Trash?',
                  confirmText: 'Delete',
                  confirmButtonAutofocus: confirmButtonAutofocus,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  group('ConfirmationDialog', () {
    testWidgets('Enter activates an autofocused confirmation button', (
      tester,
    ) async {
      final results = await _openConfirmationDialog(
        tester,
        confirmButtonAutofocus: true,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(results, <bool?>[true]);
      expect(find.byType(ConfirmationDialog), findsNothing);
    });

    testWidgets('does not autofocus confirmation by default', (tester) async {
      await _openConfirmationDialog(tester);

      final confirmButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Delete'),
      );

      expect(confirmButton.autofocus, isFalse);
    });

    testWidgets('Cancel still returns false', (tester) async {
      final results = await _openConfirmationDialog(
        tester,
        confirmButtonAutofocus: true,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(results, <bool?>[false]);
    });
  });
}

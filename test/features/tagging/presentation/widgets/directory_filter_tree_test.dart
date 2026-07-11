import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_tree_node.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/directory_filter_tree.dart';

DirectoryTreeNode _node(
  String path,
  String name, {
  List<DirectoryTreeNode> children = const [],
  int directMediaCount = 0,
}) {
  return DirectoryTreeNode(
    path: path,
    name: name,
    children: children,
    directMediaCount: directMediaCount,
    totalMediaCount: children.fold<int>(
      directMediaCount,
      (total, child) => total + child.totalMediaCount,
    ),
  );
}

/// /Photos holds one loose file, plus 2024/ (which holds Trips/) and Archive/.
DirectoryTreeNode _photos() {
  return _node(
    '/Photos',
    'Photos',
    directMediaCount: 1,
    children: [
      _node(
        '/Photos/2024',
        '2024',
        directMediaCount: 2,
        children: [
          _node('/Photos/2024/Trips', 'Trips', directMediaCount: 3),
        ],
      ),
      _node('/Photos/Archive', 'Archive', directMediaCount: 4),
    ],
  );
}

DirectoryTreeNode _downloads() =>
    _node('/Downloads', 'Downloads', directMediaCount: 5);

void main() {
  Future<List<String>> pumpTree(
    WidgetTester tester, {
    required List<DirectoryTreeNode> nodes,
    Set<String> selectedPaths = const <String>{},
  }) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DirectoryFilterTree(
            nodes: nodes,
            selectedPaths: selectedPaths,
            onToggle: toggled.add,
          ),
        ),
      ),
    );
    return toggled;
  }

  Checkbox checkboxFor(WidgetTester tester, String name) {
    return tester.widget<Checkbox>(
      find.descendant(
        of: find.ancestor(
          of: find.text(name),
          matching: find.byType(Row),
        ).first,
        matching: find.byType(Checkbox),
      ),
    );
  }

  group('DirectoryFilterTree', () {
    testWidgets('collapses roots when there is more than one to choose between',
        (tester) async {
      await pumpTree(tester, nodes: [_photos(), _downloads()]);

      expect(find.text('Photos'), findsOneWidget);
      expect(find.text('Downloads'), findsOneWidget);
      expect(find.text('2024'), findsNothing);
    });

    testWidgets('expands a lone root, since there is nothing to choose between',
        (tester) async {
      await pumpTree(tester, nodes: [_photos()]);

      expect(find.text('2024'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      // Still one level at a time: Trips lives under the collapsed 2024.
      expect(find.text('Trips'), findsNothing);
    });

    testWidgets('expanding a directory reveals its sub-directories',
        (tester) async {
      await pumpTree(tester, nodes: [_photos(), _downloads()]);

      await tester.tap(find.byTooltip('Expand Photos'));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget);
      expect(find.text('Trips'), findsNothing);

      await tester.tap(find.byTooltip('Expand 2024'));
      await tester.pumpAndSettle();
      expect(find.text('Trips'), findsOneWidget);
    });

    testWidgets('collapsing hides sub-directories again', (tester) async {
      await pumpTree(tester, nodes: [_photos()]);
      expect(find.text('2024'), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse Photos'));
      await tester.pumpAndSettle();

      expect(find.text('2024'), findsNothing);
    });

    testWidgets('shows the rolled-up media count for each directory',
        (tester) async {
      await pumpTree(tester, nodes: [_photos()]);

      expect(find.text('10'), findsOneWidget); // 1 + (2 + 3) + 4
      expect(find.text('5'), findsOneWidget); // 2024: 2 + Trips' 3
      expect(find.text('4'), findsOneWidget); // Archive
    });

    testWidgets('a directory with nothing selected under it is unchecked',
        (tester) async {
      await pumpTree(tester, nodes: [_photos()]);

      expect(checkboxFor(tester, 'Photos').value, isFalse);
    });

    testWidgets('a fully selected subtree reads as checked', (tester) async {
      await pumpTree(
        tester,
        nodes: [_photos()],
        selectedPaths: const {
          '/Photos',
          '/Photos/2024',
          '/Photos/2024/Trips',
          '/Photos/Archive',
        },
      );

      expect(checkboxFor(tester, 'Photos').value, isTrue);
      expect(checkboxFor(tester, '2024').value, isTrue);
    });

    testWidgets('a partially selected subtree reads as indeterminate',
        (tester) async {
      // Archive is missing, so Photos is only partially in.
      await pumpTree(
        tester,
        nodes: [_photos()],
        selectedPaths: const {
          '/Photos',
          '/Photos/2024',
          '/Photos/2024/Trips',
        },
      );

      expect(checkboxFor(tester, 'Photos').value, isNull);
      // 2024 is complete in its own right, so it stays fully checked.
      expect(checkboxFor(tester, '2024').value, isTrue);
      expect(checkboxFor(tester, 'Archive').value, isFalse);
    });

    testWidgets('reports the path of the directory whose checkbox was hit',
        (tester) async {
      final toggled = await pumpTree(tester, nodes: [_photos()]);

      await tester.tap(find.byType(Checkbox).at(1)); // 2024
      await tester.pumpAndSettle();

      expect(toggled, ['/Photos/2024']);
    });

    testWidgets('checking a directory also opens it, to show what is inside',
        (tester) async {
      await pumpTree(tester, nodes: [_photos(), _downloads()]);
      expect(find.text('2024'), findsNothing);

      await tester.tap(find.byType(Checkbox).first); // Photos
      await tester.pumpAndSettle();

      expect(find.text('2024'), findsOneWidget);
    });
  });
}

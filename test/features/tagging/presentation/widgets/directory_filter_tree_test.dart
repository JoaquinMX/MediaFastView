import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_tree_node.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
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
        children: [_node('/Photos/2024/Trips', 'Trips', directMediaCount: 3)],
      ),
      _node('/Photos/Archive', 'Archive', directMediaCount: 4),
    ],
  );
}

DirectoryTreeNode _downloads() =>
    _node('/Downloads', 'Downloads', directMediaCount: 5);

DirectoryTreeNode _music() => _node('/Music', 'Music', directMediaCount: 2);

void main() {
  Future<List<String>> pumpTree(
    WidgetTester tester, {
    required List<DirectoryTreeNode> nodes,
    Set<String> selectedPaths = const <String>{},
    double width = 800,
  }) async {
    final toggled = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: DirectoryFilterTree(
              nodes: nodes,
              selectedPaths: selectedPaths,
              onToggle: toggled.add,
            ),
          ),
        ),
      ),
    );
    return toggled;
  }

  /// Which column a row sits in. Rows in the same column share a left edge,
  /// because every block starts at depth 0.
  double columnOf(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dx;

  bool isRightOf(WidgetTester tester, String name, String other) =>
      columnOf(tester, name) > columnOf(tester, other);

  bool isBelow(WidgetTester tester, String name, String other) =>
      tester.getTopLeft(find.text(name)).dy >
      tester.getTopLeft(find.text(other)).dy;

  Checkbox checkboxFor(WidgetTester tester, String name) {
    return tester.widget<Checkbox>(
      find.descendant(
        of: find
            .ancestor(of: find.text(name), matching: find.byType(Row))
            .first,
        matching: find.byType(Checkbox),
      ),
    );
  }

  group('DirectoryFilterTree', () {
    testWidgets(
      'collapses roots when there is more than one to choose between',
      (tester) async {
        await pumpTree(tester, nodes: [_photos(), _downloads()]);

        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Downloads'), findsOneWidget);
        expect(find.text('2024'), findsNothing);
      },
    );

    testWidgets(
      'expands a lone root, since there is nothing to choose between',
      (tester) async {
        await pumpTree(tester, nodes: [_photos()]);

        expect(find.text('2024'), findsOneWidget);
        expect(find.text('Archive'), findsOneWidget);
        // Still one level at a time: Trips lives under the collapsed 2024.
        expect(find.text('Trips'), findsNothing);
      },
    );

    testWidgets('expanding a directory reveals its sub-directories', (
      tester,
    ) async {
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

    testWidgets('shows the rolled-up media count for each directory', (
      tester,
    ) async {
      await pumpTree(tester, nodes: [_photos()]);

      expect(find.text('10'), findsOneWidget); // 1 + (2 + 3) + 4
      expect(find.text('5'), findsOneWidget); // 2024: 2 + Trips' 3
      expect(find.text('4'), findsOneWidget); // Archive
    });

    testWidgets('a directory with nothing selected under it is unchecked', (
      tester,
    ) async {
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

    testWidgets('a partially selected subtree reads as indeterminate', (
      tester,
    ) async {
      // Archive is missing, so Photos is only partially in.
      await pumpTree(
        tester,
        nodes: [_photos()],
        selectedPaths: const {'/Photos', '/Photos/2024', '/Photos/2024/Trips'},
      );

      expect(checkboxFor(tester, 'Photos').value, isNull);
      // 2024 is complete in its own right, so it stays fully checked.
      expect(checkboxFor(tester, '2024').value, isTrue);
      expect(checkboxFor(tester, 'Archive').value, isFalse);
    });

    testWidgets('reports the path of the directory whose checkbox was hit', (
      tester,
    ) async {
      final toggled = await pumpTree(tester, nodes: [_photos()]);

      await tester.tap(find.byType(Checkbox).at(1)); // 2024
      await tester.pumpAndSettle();

      expect(toggled, ['/Photos/2024']);
    });

    testWidgets('checking a directory also opens it, to show what is inside', (
      tester,
    ) async {
      await pumpTree(tester, nodes: [_photos(), _downloads()]);
      expect(find.text('2024'), findsNothing);

      await tester.tap(find.byType(Checkbox).first); // Photos
      await tester.pumpAndSettle();

      expect(find.text('2024'), findsOneWidget);
    });

    testWidgets('aligns leaf rows with rows that carry an expand chevron', (
      tester,
    ) async {
      // Downloads has no children and so no chevron; Photos does. Their
      // checkboxes still have to line up, or the tree looks ragged.
      await pumpTree(tester, nodes: [_photos(), _downloads()], width: 300);

      final photos = tester.getTopLeft(
        find.descendant(
          of: find
              .ancestor(of: find.text('Photos'), matching: find.byType(Row))
              .first,
          matching: find.byType(Checkbox),
        ),
      );
      final downloads = tester.getTopLeft(
        find.descendant(
          of: find
              .ancestor(of: find.text('Downloads'), matching: find.byType(Row))
              .first,
          matching: find.byType(Checkbox),
        ),
      );

      expect(photos.dx, downloads.dx);
    });

    testWidgets(
      'filter row arrows browse its popup without toggling the checkbox',
      (tester) async {
        const catalog = DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[
            DirectoryVideoPreview(
              sourcePath: '/Photos/one.mp4',
              thumbnailPath: '/cache/one.jpg',
            ),
            DirectoryVideoPreview(
              sourcePath: '/Photos/two.mp4',
              thumbnailPath: '/cache/two.jpg',
            ),
          ],
        );
        final toggled = <String>[];
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              directoryPreviewCatalogProvider.overrideWith(
                (ref, query) => catalog,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 360,
                  child: DirectoryFilterTree(
                    nodes: <DirectoryTreeNode>[_photos()],
                    selectedPaths: const <String>{},
                    onToggle: toggled.add,
                  ),
                ),
              ),
            ),
          ),
        );

        // Focus the Checkbox first, then open the pointer popup. This is the
        // path where Left/Right must not turn into a checkbox interaction.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        final mouse = TestPointer(1, PointerDeviceKind.mouse);
        await tester.sendEventToBinding(
          mouse.addPointer(location: const Offset(0, 0)),
        );
        await tester.sendEventToBinding(
          mouse.hover(tester.getCenter(find.text('Photos'))),
        );
        await tester.pump();

        expect(
          find.byKey(DirectoryPreviewCarousel.carouselKey),
          findsOneWidget,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(
          find.byKey(DirectoryPreviewCarousel.previewKey(1)),
          findsOneWidget,
        );
        expect(toggled, isEmpty);
      },
    );
  });

  group('DirectoryFilterTree columns', () {
    testWidgets('lays several roots out side by side when there is room', (
      tester,
    ) async {
      await pumpTree(tester, nodes: [_photos(), _downloads()], width: 800);

      expect(isRightOf(tester, 'Downloads', 'Photos'), isTrue);
      expect(isBelow(tester, 'Downloads', 'Photos'), isFalse);
    });

    testWidgets('stacks the roots when the card is too narrow to split', (
      tester,
    ) async {
      await pumpTree(tester, nodes: [_photos(), _downloads()], width: 300);

      expect(isBelow(tester, 'Downloads', 'Photos'), isTrue);
      expect(isRightOf(tester, 'Downloads', 'Photos'), isFalse);
    });

    testWidgets(
      'promotes a lone expanded root to a header and columns its children',
      (tester) async {
        // A single root would otherwise spend the whole card on one column.
        await pumpTree(tester, nodes: [_photos()], width: 800);

        // Photos heads the card, with 2024 and Archive side by side beneath it.
        expect(isBelow(tester, '2024', 'Photos'), isTrue);
        expect(isBelow(tester, 'Archive', 'Photos'), isTrue);
        expect(isRightOf(tester, 'Archive', '2024'), isTrue);
        expect(isBelow(tester, 'Archive', '2024'), isFalse);
      },
    );

    testWidgets('keeps a subtree whole inside its column', (tester) async {
      await pumpTree(tester, nodes: [_photos()], width: 800);

      await tester.tap(find.byTooltip('Expand 2024'));
      await tester.pumpAndSettle();

      // Trips must stay under 2024 — it can never be flowed into Archive's
      // column, or its indentation would be read against the wrong parent.
      expect(isBelow(tester, 'Trips', '2024'), isTrue);
      expect(isRightOf(tester, 'Trips', '2024'), isTrue);
      expect(columnOf(tester, 'Trips'), lessThan(columnOf(tester, 'Archive')));
    });

    testWidgets('keeps the roots side by side when a later root is expanded', (
      tester,
    ) async {
      // Regression: a short leading block used to hold its column open — it
      // never reached its share of the height — so the tall expanded block
      // joined it and both roots stacked into a single column.
      await pumpTree(tester, nodes: [_downloads(), _photos()], width: 800);

      await tester.tap(find.byTooltip('Expand Photos'));
      await tester.pumpAndSettle();

      expect(isRightOf(tester, 'Photos', 'Downloads'), isTrue);
      expect(isBelow(tester, 'Photos', 'Downloads'), isFalse);
      // Photos' children belong to Photos' column, not Downloads'.
      expect(isRightOf(tester, '2024', 'Downloads'), isTrue);
    });

    testWidgets(
      'keeps the roots side by side when the first root is expanded',
      (tester) async {
        await pumpTree(tester, nodes: [_photos(), _downloads()], width: 800);

        await tester.tap(find.byTooltip('Expand Photos'));
        await tester.pumpAndSettle();

        expect(isRightOf(tester, 'Downloads', 'Photos'), isTrue);
        expect(isBelow(tester, 'Downloads', 'Photos'), isFalse);
      },
    );

    testWidgets('never strands a column empty, wherever the tall block sits', (
      tester,
    ) async {
      // Three roots into two columns, with the height concentrated in the block
      // that trails the list — the case that used to drag everything into one
      // column. Every column must still come out with a block in it.
      await pumpTree(
        tester,
        nodes: [_downloads(), _music(), _photos()],
        width: 620,
      );
      await tester.tap(find.byTooltip('Expand Photos'));
      await tester.pumpAndSettle();

      expect(columnOf(tester, 'Downloads'), columnOf(tester, 'Music'));
      expect(isRightOf(tester, 'Photos', 'Downloads'), isTrue);
      expect(isBelow(tester, 'Music', 'Downloads'), isTrue);
    });

    testWidgets(
      'collapsing the promoted root folds the columns back to a row',
      (tester) async {
        await pumpTree(tester, nodes: [_photos()], width: 800);
        expect(find.text('Archive'), findsOneWidget);

        await tester.tap(find.byTooltip('Collapse Photos'));
        await tester.pumpAndSettle();

        expect(find.text('2024'), findsNothing);
        expect(find.text('Archive'), findsNothing);
        expect(find.text('Photos'), findsOneWidget);
      },
    );
  });
}

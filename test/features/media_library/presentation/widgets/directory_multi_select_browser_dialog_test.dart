import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/directory_access_grant.dart';
import 'package:media_fast_view/core/services/directory_browser_service.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_multi_select_browser_dialog.dart';

void main() {
  testWidgets('keeps selections while navigating through a parent tree', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const rootGrant = DirectoryAccessGrant(
      path: '/photos',
      bookmarkData: 'root-bookmark',
    );
    List<String>? submittedPaths;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<List<DirectoryAccessGrant>>(
                  context: context,
                  builder: (context) => DirectoryMultiSelectBrowserDialog(
                    rootGrant: rootGrant,
                    listChildren: (_, directoryPath) async {
                      return switch (directoryPath) {
                        '/photos' => const <BrowsableDirectory>[
                          BrowsableDirectory(
                            path: '/photos/Family',
                            name: 'Family',
                          ),
                        ],
                        '/photos/Family' => const <BrowsableDirectory>[
                          BrowsableDirectory(
                            path: '/photos/Family/2026',
                            name: '2026',
                          ),
                        ],
                        _ => const <BrowsableDirectory>[],
                      };
                    },
                    createGrants: (_, selectedPaths) async {
                      submittedPaths = selectedPaths.toList();
                      return selectedPaths
                          .map((path) => DirectoryAccessGrant(path: path))
                          .toList();
                    },
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
    await tester.tap(find.byTooltip('Open Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include this folder'));
    await tester.tap(find.byTooltip('Open 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include this folder'));
    await tester.pumpAndSettle();

    expect(find.text('2 folders selected'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Use selected folders'));
    await tester.pumpAndSettle();

    expect(submittedPaths, <String>['/photos/Family', '/photos/Family/2026']);
  });
}

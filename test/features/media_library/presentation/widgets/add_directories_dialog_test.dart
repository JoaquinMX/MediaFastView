import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/directory_access_grant.dart';
import 'package:media_fast_view/core/services/directory_browser_service.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/add_directories_dialog.dart';

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required Future<List<DirectoryAccessGrant>> Function() pickDirectories,
    required Future<DirectoryAddBatchResult> Function(
      Iterable<DirectoryAccessGrant> grants,
    )
    addDirectories,
    Future<DirectoryAccessGrant?> Function()? pickParentDirectory,
    Future<List<BrowsableDirectory>> Function(
      DirectoryAccessGrant rootGrant,
      String directoryPath,
    )?
    listChildDirectories,
    Future<List<DirectoryAccessGrant>> Function(
      DirectoryAccessGrant rootGrant,
      Iterable<String> selectedPaths,
    )?
    createChildGrants,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => AddDirectoriesDialog(
                      description: 'Select directories one at a time.',
                      pickDirectories: pickDirectories,
                      pickParentDirectory: pickParentDirectory,
                      listChildDirectories: listChildDirectories,
                      createChildGrants: createChildGrants,
                      addDirectories: addDirectories,
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('stages multiple single-directory selections', (tester) async {
    final selections = Queue<List<DirectoryAccessGrant>>.from([
      const [DirectoryAccessGrant(path: '/photos/first')],
      const [DirectoryAccessGrant(path: '/photos/second')],
    ]);

    await pumpDialog(
      tester,
      pickDirectories: () async => selections.removeFirst(),
      addDirectories: (_) async => (
        successfulPaths: const <String>[],
        failureReasonsByPath: const <String, String>{},
      ),
    );

    expect(find.text('No directories selected yet.'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Add selected'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('1 directory selected'), findsOneWidget);

    await tester.tap(find.text('Add another'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('2 directories selected'), findsOneWidget);
  });

  testWidgets('stages a native multi-directory selection in one browse', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      pickDirectories: () async => const <DirectoryAccessGrant>[
        DirectoryAccessGrant(path: '/photos/first', bookmarkData: 'first'),
        DirectoryAccessGrant(path: '/photos/second', bookmarkData: 'second'),
      ],
      addDirectories: (_) async => (
        successfulPaths: const <String>[],
        failureReasonsByPath: const <String, String>{},
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('2 directories selected'), findsOneWidget);
  });

  testWidgets('deduplicates staged paths and removes a selection', (
    tester,
  ) async {
    final selections = Queue<List<DirectoryAccessGrant>>.from([
      const [DirectoryAccessGrant(path: '/photos/first')],
      const [DirectoryAccessGrant(path: '/photos/first')],
    ]);

    await pumpDialog(
      tester,
      pickDirectories: () async => selections.removeFirst(),
      addDirectories: (_) async => (
        successfulPaths: const <String>[],
        failureReasonsByPath: const <String, String>{},
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another'));
    await tester.pumpAndSettle();
    expect(find.text('1 directory selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove first'));
    await tester.pumpAndSettle();
    expect(find.text('No directories selected yet.'), findsOneWidget);
  });

  testWidgets('adds all staged paths in one batch', (tester) async {
    final selections = Queue<List<DirectoryAccessGrant>>.from([
      const [DirectoryAccessGrant(path: '/photos/first')],
      const [DirectoryAccessGrant(path: '/photos/second')],
    ]);
    List<DirectoryAccessGrant>? submittedGrants;

    await pumpDialog(
      tester,
      pickDirectories: () async => selections.removeFirst(),
      addDirectories: (grants) async {
        submittedGrants = grants.toList();
        return (
          successfulPaths: submittedGrants!.map((grant) => grant.path).toList(),
          failureReasonsByPath: const <String, String>{},
        );
      },
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add another'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected'));
    await tester.pumpAndSettle();

    expect(submittedGrants?.map((grant) => grant.path), <String>[
      '/photos/first',
      '/photos/second',
    ]);
    expect(find.byType(AddDirectoriesDialog), findsNothing);
    expect(find.text('Added 2 directories'), findsOneWidget);
  });

  testWidgets('keeps failed grants staged after a partial batch', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      pickDirectories: () async => const <DirectoryAccessGrant>[
        DirectoryAccessGrant(path: '/photos/first'),
        DirectoryAccessGrant(path: '/photos/second'),
      ],
      addDirectories: (_) async => (
        successfulPaths: const <String>['/photos/first'],
        failureReasonsByPath: const <String, String>{
          '/photos/second': 'Access denied',
        },
      ),
    );

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add selected'));
    await tester.pumpAndSettle();

    expect(find.byType(AddDirectoriesDialog), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('1 directory selected'), findsOneWidget);
    expect(find.text('Added 1 directory; 1 failed'), findsOneWidget);
  });

  testWidgets('fits a compact mobile viewport with several selections', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selections = Queue<List<DirectoryAccessGrant>>.from(
      List<List<DirectoryAccessGrant>>.generate(
        6,
        (index) => [DirectoryAccessGrant(path: '/photos/directory_$index')],
      ),
    );

    await pumpDialog(
      tester,
      pickDirectories: () async => selections.removeFirst(),
      addDirectories: (_) async => (
        successfulPaths: const <String>[],
        failureReasonsByPath: const <String, String>{},
      ),
    );

    for (var index = 0; index < 6; index++) {
      await tester.tap(find.text(index == 0 ? 'Browse' : 'Add another'));
      await tester.pumpAndSettle();
    }

    expect(find.text('6 directories selected'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stages several folders selected beneath one parent', (
    tester,
  ) async {
    const parentGrant = DirectoryAccessGrant(
      path: '/photos',
      bookmarkData: 'parent-bookmark',
    );
    Iterable<String>? selectedChildPaths;

    await pumpDialog(
      tester,
      pickDirectories: () async => const <DirectoryAccessGrant>[],
      pickParentDirectory: () async => parentGrant,
      listChildDirectories: (_, directoryPath) async => const [
        BrowsableDirectory(path: '/photos/first', name: 'first'),
        BrowsableDirectory(path: '/photos/second', name: 'second'),
      ],
      createChildGrants: (_, selectedPaths) async {
        selectedChildPaths = selectedPaths.toList();
        return selectedPaths
            .map(
              (path) => DirectoryAccessGrant(
                path: path,
                bookmarkData: 'bookmark:$path',
              ),
            )
            .toList();
      },
      addDirectories: (_) async => (
        successfulPaths: const <String>[],
        failureReasonsByPath: const <String, String>{},
      ),
    );

    await tester.tap(find.text('Choose from a parent folder'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Folders'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('2 folders selected'), findsOneWidget);

    await tester.tap(find.text('Use selected folders'));
    await tester.pumpAndSettle();

    expect(selectedChildPaths, <String>['/photos/first', '/photos/second']);
    expect(find.text('2 directories selected'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
  });
}

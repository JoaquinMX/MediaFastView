import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_cover_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_cover_picker_dialog.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_grid_item.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';

void main() {
  testWidgets('opens the cover picker directly from a root directory card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          directoryCoverProvider.overrideWith((ref, path) => null),
          directoryCoverCandidatesProvider.overrideWith(
            (ref, query) => const [],
          ),
          directoryPreviewCatalogProvider.overrideWith(
            (ref, query) =>
                const DirectoryPreviewCatalog(previews: <DirectoryPreview>[]),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 320,
              child: DirectoryGridItem(
                directory: DirectoryEntity(
                  id: 'root',
                  path: '/library/root',
                  name: 'Root',
                  thumbnailPath: null,
                  tagIds: const [],
                  lastModified: DateTime(2025),
                ),
                onTap: () {},
                onDelete: () {},
                onAssignTags: (_) async {},
                onSelectionToggle: () {},
                isSelected: false,
                isSelectionMode: false,
                showTaggedMediaCounts: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DirectoryGridItem),
        matching: find.byType(PopupMenuButton),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Choose directory cover'));
    await tester.pumpAndSettle();

    expect(find.byType(DirectoryCoverPickerDialog), findsOneWidget);
    expect(find.text('No cover'), findsOneWidget);
  });

  testWidgets('opens a root card carousel after pointer dwell', (tester) async {
    const catalog = DirectoryPreviewCatalog(
      previews: <DirectoryPreview>[
        DirectoryVideoPreview(
          sourcePath: '/library/root/one.mp4',
          thumbnailPath: '/cache/one.jpg',
        ),
        DirectoryVideoPreview(
          sourcePath: '/library/root/two.mp4',
          thumbnailPath: '/cache/two.jpg',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          directoryCoverProvider.overrideWith((ref, path) => null),
          directoryPreviewCatalogProvider.overrideWith((ref, query) => catalog),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 320,
              child: DirectoryGridItem(
                directory: DirectoryEntity(
                  id: 'root',
                  path: '/library/root',
                  name: 'Root',
                  thumbnailPath: null,
                  tagIds: const [],
                  lastModified: DateTime(2025),
                ),
                onTap: () {},
                onDelete: () {},
                onAssignTags: (_) async {},
                onSelectionToggle: () {},
                isSelected: false,
                isSelectionMode: false,
                showTaggedMediaCounts: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.addPointer(location: const Offset(0, 0)),
    );
    await tester.sendEventToBinding(
      mouse.hover(tester.getCenter(find.byType(DirectoryGridItem))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);
  });

  testWidgets(
    'root card arrows and carousel buttons do not activate the card or selection',
    (tester) async {
      const catalog = DirectoryPreviewCatalog(
        previews: <DirectoryPreview>[
          DirectoryVideoPreview(
            sourcePath: '/library/root/one.mp4',
            thumbnailPath: '/cache/one.jpg',
          ),
          DirectoryVideoPreview(
            sourcePath: '/library/root/two.mp4',
            thumbnailPath: '/cache/two.jpg',
          ),
        ],
      );
      var openCount = 0;
      var selectionCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            directoryCoverProvider.overrideWith((ref, path) => null),
            directoryPreviewCatalogProvider.overrideWith(
              (ref, query) => catalog,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: 320,
                child: DirectoryGridItem(
                  directory: DirectoryEntity(
                    id: 'root',
                    path: '/library/root',
                    name: 'Root',
                    thumbnailPath: null,
                    tagIds: const [],
                    lastModified: DateTime(2025),
                  ),
                  onTap: () => openCount += 1,
                  onDelete: () {},
                  onAssignTags: (_) async {},
                  onSelectionToggle: () => selectionCount += 1,
                  isSelected: false,
                  isSelectionMode: true,
                  showTaggedMediaCounts: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Focusing the card opens its first preview as before. The setup focus is
      // not part of the isolation assertion.
      Focus.of(tester.element(find.byType(InkWell).first)).requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      openCount = 0;
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(openCount, 0);
      expect(selectionCount, 0);

      await tester.tap(find.byKey(DirectoryPreviewCarousel.previousButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
      expect(openCount, 0);

      // A focused selection control is also protected from directional keys.
      await tester.tap(find.byIcon(Icons.circle_outlined));
      await tester.pump();
      selectionCount = 0;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(openCount, 0);
      expect(selectionCount, 0);
    },
  );

  testWidgets('on iOS, a preview tap opens while a scrub stays isolated', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      const catalog = DirectoryPreviewCatalog(
        previews: <DirectoryPreview>[
          DirectoryVideoPreview(
            sourcePath: '/library/root/one.mp4',
            thumbnailPath: '/cache/one.jpg',
          ),
          DirectoryVideoPreview(
            sourcePath: '/library/root/two.mp4',
            thumbnailPath: '/cache/two.jpg',
          ),
        ],
      );
      var openCount = 0;
      var selectionCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            directoryCoverProvider.overrideWith((ref, path) => null),
            directoryPreviewCatalogProvider.overrideWith(
              (ref, query) => catalog,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: 320,
                child: DirectoryGridItem(
                  directory: DirectoryEntity(
                    id: 'root',
                    path: '/library/root',
                    name: 'Root',
                    thumbnailPath: null,
                    tagIds: const [],
                    lastModified: DateTime(2025),
                  ),
                  onTap: () => openCount += 1,
                  onDelete: () {},
                  onAssignTags: (_) async {},
                  onSelectionToggle: () => selectionCount += 1,
                  isSelected: false,
                  isSelectionMode: false,
                  showTaggedMediaCounts: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(DirectoryPreviewCarousel.interactionKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(openCount, 1);

      openCount = 0;
      final rect = tester.getRect(
        find.byKey(DirectoryPreviewCarousel.interactionKey),
      );
      final gesture = await tester.startGesture(
        Offset(rect.left + 8, rect.center.dy),
      );
      await tester.pump();
      await gesture.moveTo(Offset(rect.right - 8, rect.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(openCount, 0);
      expect(selectionCount, 0);

      await tester.longPress(
        find.byKey(DirectoryPreviewCarousel.interactionKey),
      );
      await tester.pump();
      expect(openCount, 0);
      expect(selectionCount, 0);

      await tester.tap(find.text('Root'));
      await tester.pump();
      expect(openCount, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

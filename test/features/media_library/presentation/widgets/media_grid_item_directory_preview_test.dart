import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_media_counts.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/media_grid_item.dart';
import 'package:media_fast_view/shared/providers/active_profile_provider.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/providers/settings_providers.dart';
import 'package:visibility_detector/visibility_detector.dart';

MediaEntity _nestedDirectory() {
  return MediaEntity(
    id: 'nested-directory',
    path: '/library/root/nested',
    name: 'nested',
    type: MediaType.directory,
    size: 0,
    lastModified: DateTime(2025),
    tagIds: const <String>[],
    directoryId: 'root',
  );
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('opens a nested directory card carousel after pointer dwell', (
    tester,
  ) async {
    const catalog = DirectoryPreviewCatalog(
      previews: <DirectoryPreview>[
        DirectoryVideoPreview(
          sourcePath: '/library/root/nested/one.mp4',
          thumbnailPath: '/cache/one.jpg',
        ),
        DirectoryVideoPreview(
          sourcePath: '/library/root/nested/two.mp4',
          thumbnailPath: '/cache/two.jpg',
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          directoryPreviewCatalogProvider.overrideWith((ref, query) => catalog),
          activeProfileIdProvider.overrideWith(
            () => ActiveProfileIdNotifier('profile-1'),
          ),
          showDirectoryTaggedMediaCountsProvider.overrideWithValue(false),
          directoryMediaCountsProvider.overrideWith(
            (ref) => const <String, DirectoryMediaCounts>{},
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: MediaGridItem(
                media: _nestedDirectory(),
                onTap: () {},
                onSelectionToggle: () {},
                isSelected: false,
                isSelectionMode: false,
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
      mouse.hover(tester.getCenter(find.byType(MediaGridItem))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);
  });

  testWidgets(
    'nested desktop preview background opens the folder while navigation stays isolated',
    (tester) async {
      const catalog = DirectoryPreviewCatalog(
        previews: <DirectoryPreview>[
          DirectoryVideoPreview(
            sourcePath: '/library/root/nested/one.mp4',
            thumbnailPath: '/cache/one.jpg',
          ),
          DirectoryVideoPreview(
            sourcePath: '/library/root/nested/two.mp4',
            thumbnailPath: '/cache/two.jpg',
          ),
        ],
      );
      var openCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            directoryPreviewCatalogProvider.overrideWith(
              (ref, query) => catalog,
            ),
            activeProfileIdProvider.overrideWith(
              () => ActiveProfileIdNotifier('profile-1'),
            ),
            showDirectoryTaggedMediaCountsProvider.overrideWithValue(false),
            directoryMediaCountsProvider.overrideWith(
              (ref) => const <String, DirectoryMediaCounts>{},
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 250,
                child: MediaGridItem(
                  media: _nestedDirectory(),
                  onTap: () => openCount += 1,
                  onSelectionToggle: () {},
                  isSelected: false,
                  isSelectionMode: false,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(DirectoryPreviewCarousel.interactionKey));
      await tester.pump();
      expect(openCount, 1);

      await tester.tap(find.text('nested'));
      await tester.pump();
      expect(openCount, 2);

      tester
          .widget<Focus>(
            find
                .ancestor(
                  of: find.byKey(const Key('media-grid-nested-directory')),
                  matching: find.byType(Focus),
                )
                .first,
          )
          .focusNode!
          .requestFocus();
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

      await tester.tap(find.byKey(DirectoryPreviewCarousel.previousButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
      expect(openCount, 0);
    },
  );

  testWidgets(
    'on iOS, a nested preview tap opens while a scrub stays isolated',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        const catalog = DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[
            DirectoryVideoPreview(
              sourcePath: '/library/root/nested/one.mp4',
              thumbnailPath: '/cache/one.jpg',
            ),
            DirectoryVideoPreview(
              sourcePath: '/library/root/nested/two.mp4',
              thumbnailPath: '/cache/two.jpg',
            ),
          ],
        );
        var openCount = 0;
        var selectionCount = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              directoryPreviewCatalogProvider.overrideWith(
                (ref, query) => catalog,
              ),
              activeProfileIdProvider.overrideWith(
                () => ActiveProfileIdNotifier('profile-1'),
              ),
              showDirectoryTaggedMediaCountsProvider.overrideWithValue(false),
              directoryMediaCountsProvider.overrideWith(
                (ref) => const <String, DirectoryMediaCounts>{},
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 250,
                  child: MediaGridItem(
                    media: _nestedDirectory(),
                    onTap: () => openCount += 1,
                    onSelectionToggle: () => selectionCount += 1,
                    isSelected: false,
                    isSelectionMode: false,
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
        await gesture.moveTo(Offset(rect.right - 8, rect.center.dy));
        await tester.pump();
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 180));
        expect(openCount, 0);
        expect(selectionCount, 0);

        await tester.tap(find.text('nested'));
        await tester.pump();
        expect(openCount, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

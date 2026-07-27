import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/directory_hover_preview.dart';

const DirectoryPreviewCatalog _catalog = DirectoryPreviewCatalog(
  previews: <DirectoryPreview>[
    DirectoryVideoPreview(
      sourcePath: '/library/folder/one.mp4',
      thumbnailPath: '/cache/one.jpg',
    ),
    DirectoryVideoPreview(
      sourcePath: '/library/folder/two.mp4',
      thumbnailPath: '/cache/two.jpg',
    ),
  ],
);

Widget _subject({
  required GlobalKey<DirectoryHoverPreviewState> previewKey,
  FocusNode? focusNode,
  DirectoryPreviewCatalog catalog = _catalog,
  bool catalogFails = false,
}) {
  return ProviderScope(
    key: ValueKey<String>(
      catalogFails
          ? 'directory-preview-error-scope'
          : 'directory-preview-scope',
    ),
    overrides: <Override>[
      if (catalogFails)
        directoryPreviewCatalogProvider.overrideWith((ref, query) async {
          throw StateError('Preview lookup failed');
        })
      else
        directoryPreviewCatalogProvider.overrideWith((ref, query) => catalog),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: DirectoryHoverPreview(
            key: previewKey,
            directoryPath: '/library/folder',
            child: Focus(
              focusNode: focusNode,
              child: const SizedBox(
                width: 120,
                height: 48,
                child: Center(child: Text('Folder trigger')),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _moveMouse(
  WidgetTester tester,
  TestPointer mouse,
  Offset location,
) async {
  await tester.sendEventToBinding(mouse.hover(location));
  await tester.pump();
}

void main() {
  testWidgets('keeps the interactive popup open while the pointer transfers', (
    tester,
  ) async {
    final previewKey = GlobalKey<DirectoryHoverPreviewState>();
    await tester.pumpWidget(_subject(previewKey: previewKey));

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.addPointer(location: const Offset(0, 0)),
    );
    await _moveMouse(
      tester,
      mouse,
      tester.getCenter(find.text('Folder trigger')),
    );

    expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);

    final triggerCenter = tester.getCenter(find.text('Folder trigger'));
    final triggerTop = tester.getTopLeft(find.text('Folder trigger')).dy;
    await _moveMouse(tester, mouse, Offset(triggerCenter.dx, triggerTop - 6));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);

    await _moveMouse(
      tester,
      mouse,
      tester.getCenter(find.byKey(DirectoryPreviewCarousel.carouselKey)),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsOneWidget);

    await _moveMouse(tester, mouse, const Offset(1, 599));
    await tester.pump(const Duration(milliseconds: 181));

    expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsNothing);
  });

  testWidgets('closes the popup on Escape and trigger activation', (
    tester,
  ) async {
    final previewKey = GlobalKey<DirectoryHoverPreviewState>();
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      _subject(previewKey: previewKey, focusNode: focusNode),
    );
    focusNode.requestFocus();
    await tester.pump();

    previewKey.currentState!.showOverlay();
    await tester.pump();
    expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsNothing);

    previewKey.currentState!.showOverlay();
    await tester.pump();
    await tester.tap(find.text('Folder trigger'));
    await tester.pump();
    expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsNothing);
  });

  testWidgets(
    'routes directional keys and buttons without dismissing the Tags popup',
    (tester) async {
      final previewKey = GlobalKey<DirectoryHoverPreviewState>();
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      await tester.pumpWidget(
        _subject(previewKey: previewKey, focusNode: focusNode),
      );
      focusNode.requestFocus();
      await tester.pump();
      previewKey.currentState!.showOverlay();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsOneWidget);

      await tester.tap(find.byKey(DirectoryPreviewCarousel.previousButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
      expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows explicit empty and error popup states', (tester) async {
    final emptyKey = GlobalKey<DirectoryHoverPreviewState>();
    await tester.pumpWidget(
      _subject(
        previewKey: emptyKey,
        catalog: const DirectoryPreviewCatalog(previews: <DirectoryPreview>[]),
      ),
    );
    emptyKey.currentState!.showOverlay();
    await tester.pump();
    expect(find.text('No previews available'), findsOneWidget);

    final errorKey = GlobalKey<DirectoryHoverPreviewState>();
    await tester.pumpWidget(_subject(previewKey: errorKey, catalogFails: true));
    errorKey.currentState!.showOverlay();
    await tester.pumpAndSettle();
    expect(find.text('Preview unavailable'), findsOneWidget);
  });
}

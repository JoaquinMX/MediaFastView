import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';

const Duration _dwell = Duration(milliseconds: 250);
const Duration _advance = Duration(milliseconds: 2500);
const Duration _fade = Duration(milliseconds: 180);

DirectoryPreviewCatalog _catalog(int count) {
  return DirectoryPreviewCatalog(
    previews: List<DirectoryPreview>.generate(
      count,
      (index) => DirectoryVideoPreview(
        sourcePath: '/library/folder/$index.mp4',
        thumbnailPath: '/cache/$index.jpg',
      ),
      growable: false,
    ),
  );
}

Widget _subject({
  required DirectoryPreviewCatalog catalog,
  bool isPointerHovering = false,
  bool isFocused = false,
  bool reduceAnimations = false,
  DirectoryPreviewCarouselController? controller,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceAnimations),
      child: Scaffold(
        body: SizedBox(
          width: 160,
          height: 120,
          child: DirectoryPreviewCarousel(
            key: const ValueKey<String>('carousel'),
            catalog: catalog,
            fit: BoxFit.cover,
            isPointerHovering: isPointerHovering,
            isFocused: isFocused,
            controller: controller,
            hoverDwell: _dwell,
            autoAdvanceInterval: _advance,
            transitionDuration: _fade,
            placeholderBuilder: (_) => const ColoredBox(
              key: Key('carousel-placeholder'),
              color: Colors.grey,
            ),
            emptyBuilder: (_) => const ColoredBox(
              key: Key('carousel-empty'),
              color: Colors.blue,
            ),
            errorBuilder: (_) =>
                const ColoredBox(key: Key('carousel-error'), color: Colors.red),
          ),
        ),
      ),
    ),
  );
}

Future<void> _finishFade(WidgetTester tester) async {
  // Timer callbacks schedule the transition for the next frame. Pump once to
  // start that frame, then advance through the complete fade.
  await tester.pump();
  await tester.pump(_fade);
  await tester.pump();
}

void main() {
  testWidgets('waits for pointer dwell, advances, and wraps previews', (
    tester,
  ) async {
    final catalog = _catalog(2);
    await tester.pumpWidget(
      _subject(catalog: catalog, isPointerHovering: true),
    );

    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);

    await tester.pump(_dwell - const Duration(milliseconds: 1));
    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);

    await tester.pump(_advance);
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(1)), findsOneWidget);

    await tester.pump(_advance);
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);
  });

  testWidgets('does not auto-advance when reduced animations are requested', (
    tester,
  ) async {
    final catalog = _catalog(2);
    await tester.pumpWidget(
      _subject(
        catalog: catalog,
        isPointerHovering: true,
        reduceAnimations: true,
      ),
    );

    await tester.pump(_dwell);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);

    await tester.pump(_advance * 2);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(1)), findsNothing);
  });

  testWidgets('keyboard focus opens the first preview without auto-advancing', (
    tester,
  ) async {
    final catalog = _catalog(2);
    await tester.pumpWidget(_subject(catalog: catalog));

    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);

    await tester.pumpWidget(_subject(catalog: catalog, isFocused: true));
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);

    await tester.pump(_advance * 2);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(1)), findsNothing);
  });

  testWidgets('resets to its collage and first preview when browsing ends', (
    tester,
  ) async {
    final catalog = _catalog(2);
    await tester.pumpWidget(
      _subject(catalog: catalog, isPointerHovering: true),
    );
    await tester.pump(_dwell);
    await _finishFade(tester);
    await tester.pump(_advance);
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(1)), findsOneWidget);

    await tester.pumpWidget(_subject(catalog: catalog));
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);

    await tester.pumpWidget(
      _subject(catalog: catalog, isPointerHovering: true),
    );
    await tester.pump(_dwell);
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(0)), findsOneWidget);
  });

  testWidgets('uses its empty fallback when the catalog has no previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(
        catalog: const DirectoryPreviewCatalog(previews: <DirectoryPreview>[]),
        isPointerHovering: true,
      ),
    );

    expect(find.byKey(const Key('carousel-empty')), findsOneWidget);

    await tester.pump(_dwell);
    expect(find.byKey(const Key('carousel-empty')), findsOneWidget);
    expect(
      find.byKey(DirectoryPreviewCarousel.previousButtonKey),
      findsNothing,
    );
    expect(find.byKey(DirectoryPreviewCarousel.nextButtonKey), findsNothing);
  });

  testWidgets(
    'offers bounded manual buttons with filename and position semantics',
    (tester) async {
      final catalog = _catalog(3);
      await tester.pumpWidget(_subject(catalog: catalog, isFocused: true));
      await _finishFade(tester);

      expect(
        find.byKey(DirectoryPreviewCarousel.previousButtonKey),
        findsOneWidget,
      );
      expect(
        find.byKey(DirectoryPreviewCarousel.nextButtonKey),
        findsOneWidget,
      );
      expect(find.byKey(DirectoryPreviewCarousel.counterKey), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('0.mp4'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.descendant(
                of: find.byKey(DirectoryPreviewCarousel.previousButtonKey),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );

      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(
              find.byKey(DirectoryPreviewCarousel.previewSemanticsKey),
            )
            .label,
        '0.mp4, preview 1 of 3',
      );
      semantics.dispose();

      await tester.tap(find.byKey(DirectoryPreviewCarousel.nextButtonKey));
      await _finishFade(tester);
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('1.mp4'), findsOneWidget);

      await tester.tap(find.byKey(DirectoryPreviewCarousel.previousButtonKey));
      await _finishFade(tester);
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );

      // The disabled leading button cannot wrap around to the last preview.
      await tester.tap(find.byKey(DirectoryPreviewCarousel.previousButtonKey));
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
    },
  );

  testWidgets('manual navigation restarts pointer auto-advance timing', (
    tester,
  ) async {
    final controller = DirectoryPreviewCarouselController();
    await tester.pumpWidget(
      _subject(
        catalog: _catalog(3),
        isPointerHovering: true,
        controller: controller,
      ),
    );
    await tester.pump(_dwell);
    await _finishFade(tester);

    // The first automatic advance is due shortly after this manual action.
    // Restarting the timer keeps the manually selected item on screen.
    await tester.pump(const Duration(milliseconds: 2200));
    expect(controller.showNextPreview(), isTrue);
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(1)), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(1)), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2250));
    await _finishFade(tester);
    expect(find.byKey(DirectoryPreviewCarousel.previewKey(2)), findsOneWidget);
  });

  testWidgets(
    're-arms hover dwell after focus leaves a still-hovered surface',
    (tester) async {
      final catalog = _catalog(2);
      await tester.pumpWidget(
        _subject(catalog: catalog, isPointerHovering: true),
      );
      await tester.pump(const Duration(milliseconds: 100));

      await tester.pumpWidget(
        _subject(catalog: catalog, isPointerHovering: true, isFocused: true),
      );
      await _finishFade(tester);

      await tester.pumpWidget(
        _subject(catalog: catalog, isPointerHovering: true),
      );
      await tester.pump(_dwell);
      await _finishFade(tester);

      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'on iOS, a tap starts browsing and swipes navigate without wrapping',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(_subject(catalog: _catalog(2)));

        // Compact arrows remain available before the tap as accessible alternatives.
        expect(
          find.byKey(DirectoryPreviewCarousel.previousButtonKey),
          findsOneWidget,
        );
        expect(
          find.byKey(DirectoryPreviewCarousel.nextButtonKey),
          findsOneWidget,
        );

        await tester.tap(find.byKey(DirectoryPreviewCarousel.nextButtonKey));
        await _finishFade(tester);
        expect(
          find.byKey(DirectoryPreviewCarousel.previewKey(1)),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(DirectoryPreviewCarousel.previousButtonKey),
        );
        await _finishFade(tester);
        expect(
          find.byKey(DirectoryPreviewCarousel.previewKey(0)),
          findsOneWidget,
        );

        await tester.tap(find.byKey(DirectoryPreviewCarousel.interactionKey));
        await _finishFade(tester);
        expect(
          find.byKey(DirectoryPreviewCarousel.previewKey(0)),
          findsOneWidget,
        );

        await tester.fling(
          find.byKey(DirectoryPreviewCarousel.interactionKey),
          const Offset(-120, 0),
          1000,
        );
        await _finishFade(tester);
        expect(
          find.byKey(DirectoryPreviewCarousel.previewKey(1)),
          findsOneWidget,
        );

        await tester.fling(
          find.byKey(DirectoryPreviewCarousel.interactionKey),
          const Offset(-120, 0),
          1000,
        );
        await tester.pump();
        expect(
          find.byKey(DirectoryPreviewCarousel.previewKey(1)),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

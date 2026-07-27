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
  test('maps iOS touch positions through bounded edge insets', () {
    expect(
      DirectoryPreviewCarousel.previewPositionForLocalDx(
        localDx: 0,
        width: 160,
        previewCount: 5,
      ),
      0,
    );
    expect(
      DirectoryPreviewCarousel.previewPositionForLocalDx(
        localDx: 12,
        width: 160,
        previewCount: 5,
      ),
      0,
    );
    expect(
      DirectoryPreviewCarousel.previewPositionForLocalDx(
        localDx: 80,
        width: 160,
        previewCount: 5,
      ),
      2,
    );
    expect(
      DirectoryPreviewCarousel.previewPositionForLocalDx(
        localDx: 148,
        width: 160,
        previewCount: 5,
      ),
      4,
    );
    expect(
      DirectoryPreviewCarousel.previewPositionForLocalDx(
        localDx: 40,
        width: 80,
        previewCount: 4,
      ),
      1.5,
    );
    expect(
      DirectoryPreviewCarousel.previewPositionForLocalDx(
        localDx: 160,
        width: 160,
        previewCount: 1,
      ),
      0,
    );
  });

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

  testWidgets('iOS shows no arrows and scrubs across the bounded catalog', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_subject(catalog: _catalog(5)));

      expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);
      expect(
        find.byKey(DirectoryPreviewCarousel.previousButtonKey),
        findsNothing,
      );
      expect(find.byKey(DirectoryPreviewCarousel.nextButtonKey), findsNothing);

      final rect = tester.getRect(
        find.byKey(DirectoryPreviewCarousel.interactionKey),
      );
      final gesture = await tester.startGesture(
        Offset(rect.left + 12, rect.center.dy),
      );
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
      expect(find.text('1 / 5'), findsOneWidget);

      await gesture.moveTo(Offset(rect.left + 148, rect.center.dy));
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(4)),
        findsOneWidget,
      );
      expect(find.text('5 / 5'), findsOneWidget);

      await gesture.moveTo(Offset(rect.left - 40, rect.center.dy));
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pump(_fade);
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(0)),
        findsOneWidget,
      );
      expect(
        find.byKey(DirectoryPreviewCarousel.previousButtonKey),
        findsNothing,
      );
      expect(find.byKey(DirectoryPreviewCarousel.nextButtonKey), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS strip follows a fractional touch and snaps on release', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_subject(catalog: _catalog(5)));
      final rect = tester.getRect(
        find.byKey(DirectoryPreviewCarousel.interactionKey),
      );
      final gesture = await tester.startGesture(
        Offset(rect.left + 12, rect.center.dy),
      );
      await tester.pump();

      // Position 2.25 in a five-item, 160-pixel catalog.
      await gesture.moveTo(Offset(rect.left + 88.5, rect.center.dy));
      await tester.pump();

      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(2)),
        findsOneWidget,
      );
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(3)),
        findsOneWidget,
      );
      expect(find.text('3 / 5'), findsOneWidget);
      final leading = tester.widget<Positioned>(
        find.byKey(DirectoryPreviewCarousel.scrubLeadingPreviewKey),
      );
      final trailing = tester.widget<Positioned>(
        find.byKey(DirectoryPreviewCarousel.scrubTrailingPreviewKey),
      );
      expect(leading.left, closeTo(-40, 0.001));
      expect(trailing.left, closeTo(120, 0.001));

      await gesture.up();
      await tester.pump();
      await tester.pump(_fade ~/ 2);
      final snappingLeading = tester.widget<Positioned>(
        find.byKey(DirectoryPreviewCarousel.scrubLeadingPreviewKey),
      );
      expect(snappingLeading.left, greaterThan(-40));
      expect(snappingLeading.left, lessThanOrEqualTo(0));

      await tester.pump(_fade);
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(2)),
        findsOneWidget,
      );
      expect(find.byKey(DirectoryPreviewCarousel.previewKey(3)), findsNothing);
      expect(
        tester
            .widget<Positioned>(
              find.byKey(DirectoryPreviewCarousel.scrubLeadingPreviewKey),
            )
            .left,
        0,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS reduced motion switches discretely at mapped positions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        _subject(catalog: _catalog(5), reduceAnimations: true),
      );
      final rect = tester.getRect(
        find.byKey(DirectoryPreviewCarousel.interactionKey),
      );
      final gesture = await tester.startGesture(
        Offset(rect.left + 88.5, rect.center.dy),
      );
      await tester.pump();

      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(2)),
        findsOneWidget,
      );
      expect(find.byKey(DirectoryPreviewCarousel.previewKey(3)), findsNothing);
      expect(find.byKey(DirectoryPreviewCarousel.scrubStripKey), findsNothing);

      await gesture.moveTo(Offset(rect.left + 148, rect.center.dy));
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(4)),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(4)),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('iOS exposes bounded VoiceOver previous and next actions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(_subject(catalog: _catalog(3)));
      expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);

      Semantics semanticsWidget() => tester.widget<Semantics>(
        find.byKey(DirectoryPreviewCarousel.previewSemanticsKey),
      );

      var actions = semanticsWidget().properties.customSemanticsActions!;
      expect(actions, contains(DirectoryPreviewCarousel.nextSemanticsAction));
      expect(
        actions,
        isNot(contains(DirectoryPreviewCarousel.previousSemanticsAction)),
      );

      actions[DirectoryPreviewCarousel.nextSemanticsAction]!();
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );

      actions = semanticsWidget().properties.customSemanticsActions!;
      expect(
        actions,
        contains(DirectoryPreviewCarousel.previousSemanticsAction),
      );
      expect(actions, contains(DirectoryPreviewCarousel.nextSemanticsAction));

      actions[DirectoryPreviewCarousel.nextSemanticsAction]!();
      await tester.pump();
      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(2)),
        findsOneWidget,
      );
      actions = semanticsWidget().properties.customSemanticsActions!;
      expect(
        actions,
        isNot(contains(DirectoryPreviewCarousel.nextSemanticsAction)),
      );
    } finally {
      semanticsHandle.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('stops scrub callbacks when the carousel is disposed', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(_subject(catalog: _catalog(5)));
      final rect = tester.getRect(
        find.byKey(DirectoryPreviewCarousel.interactionKey),
      );
      final gesture = await tester.startGesture(
        Offset(rect.left + 88.5, rect.center.dy),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(_fade ~/ 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(_fade * 2);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

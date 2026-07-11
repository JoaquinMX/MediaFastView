import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/constants/ui_constants.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/media_grid_item.dart';
import 'package:visibility_detector/visibility_detector.dart';

MediaEntity _media() {
  return MediaEntity(
    id: 'media-1',
    path: '/Photos/2024/a.jpg',
    name: 'a.jpg',
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024),
    tagIds: const [],
    directoryId: 'photos',
  );
}

void main() {
  late ThemeData theme;

  setUp(() {
    theme = ThemeData(useMaterial3: true);
    // MediaGridItem wraps its thumbnail in a VisibilityDetector, which defaults
    // to a 500ms debounce timer that outlives the test's widget tree.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<BorderSide> pumpItem(
    WidgetTester tester, {
    bool isSelected = false,
    bool isHighlighted = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 250,
              child: MediaGridItem(
                media: _media(),
                onTap: () {},
                onSelectionToggle: () {},
                isSelected: isSelected,
                isSelectionMode: false,
                isHighlighted: isHighlighted,
              ),
            ),
          ),
        ),
      ),
    );

    final card = tester.widget<Card>(find.byType(Card));
    return (card.shape! as RoundedRectangleBorder).side;
  }

  group('MediaGridItem highlight', () {
    testWidgets('a plain item has no border', (tester) async {
      final side = await pumpItem(tester);

      expect(side, BorderSide.none);
    });

    testWidgets('a selected item is bordered in the primary colour',
        (tester) async {
      final side = await pumpItem(tester, isSelected: true);

      expect(side.color, theme.colorScheme.primary);
      expect(side.width, UiSizing.borderWidth);
    });

    testWidgets('a revealed item is called out in a different colour',
        (tester) async {
      // Must not read as a selection: the user did not select this, they were
      // brought here to find it.
      final side = await pumpItem(tester, isHighlighted: true);

      expect(side.color, theme.colorScheme.tertiary);
      expect(side.color, isNot(theme.colorScheme.primary));
      expect(side.width, greaterThan(UiSizing.borderWidth));
    });

    testWidgets('the highlight wins over selection while it lasts',
        (tester) async {
      final side = await pumpItem(
        tester,
        isSelected: true,
        isHighlighted: true,
      );

      expect(side.color, theme.colorScheme.tertiary);
    });
  });
}

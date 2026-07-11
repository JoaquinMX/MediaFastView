import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/shared/utils/grid_scroll_offset.dart';

void main() {
  // A 4-column grid 816px wide with 16px padding and 16px gutters:
  //   content   = 816 - 32 - 16 * 3 = 736
  //   tileWidth = 736 / 4           = 184
  //   tileHeight= 184 / 0.8         = 230
  //   rowStride = 230 + 16          = 246
  const width = 816.0;
  const columns = 4;
  const rowStride = 246.0;

  double offsetFor(int index, {int columns = columns, double width = width}) {
    return gridScrollOffsetForIndex(
      index: index,
      columns: columns,
      viewportWidth: width,
    );
  }

  group('gridScrollOffsetForIndex', () {
    test('does not scroll for anything on the first row', () {
      expect(offsetFor(0), 0);
      expect(offsetFor(3), 0); // last item of row 0
    });

    test('scrolls one row stride for the first item of the second row', () {
      expect(offsetFor(4), closeTo(rowStride, 0.001));
    });

    test('scrolls by whole rows, not by items', () {
      // Every item on row 1 shares an offset — you scroll to the row.
      expect(offsetFor(5), closeTo(rowStride, 0.001));
      expect(offsetFor(7), closeTo(rowStride, 0.001));
      expect(offsetFor(8), closeTo(rowStride * 2, 0.001));
    });

    test('scales linearly with the row index', () {
      expect(offsetFor(40), closeTo(rowStride * 10, 0.001));
    });

    test('column count decides which row an index lands on', () {
      // Index 4 is row 1 in a 4-column grid but row 2 in a 2-column grid, and
      // the narrower columns make each row taller.
      final twoColumn = offsetFor(4, columns: 2);
      final fourColumn = offsetFor(4);

      expect(twoColumn, greaterThan(fourColumn));

      // content = 816 - 32 - 16 = 768; tile = 384 wide / 0.8 = 480 high.
      expect(twoColumn, closeTo(2 * (480 + 16), 0.001));
    });

    test('a wider viewport means taller tiles and a larger offset', () {
      expect(offsetFor(4, width: 1200), greaterThan(offsetFor(4, width: 816)));
    });

    group('degenerate input', () {
      test('a negative index does not scroll', () {
        expect(offsetFor(-1), 0);
      });

      test('zero columns does not scroll, and does not divide by zero', () {
        expect(offsetFor(4, columns: 0), 0);
      });

      test('a viewport too narrow to hold the gutters does not scroll', () {
        // Padding and spacing alone exceed the width, so there is no room for a
        // tile; returning 0 beats returning a negative or infinite offset.
        expect(offsetFor(4, width: 40), 0);
      });
    });

    test('honours a caller-supplied geometry', () {
      final offset = gridScrollOffsetForIndex(
        index: 2,
        columns: 2,
        viewportWidth: 200,
        padding: EdgeInsets.zero,
        crossAxisSpacing: 0,
        mainAxisSpacing: 0,
        childAspectRatio: 1,
      );

      // Two 100x100 tiles per row, no gutters: row 1 starts at 100.
      expect(offset, closeTo(100, 0.001));
    });
  });
}

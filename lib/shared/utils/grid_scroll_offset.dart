import 'package:flutter/widgets.dart';

import '../../core/constants/ui_constants.dart';

/// Scroll offset that brings the row holding [index] to the top of the viewport.
///
/// Computed rather than measured. The media grid is a lazy `GridView.builder`,
/// so the row we want to reveal has no `RenderObject` until we have already
/// scrolled to it — `Scrollable.ensureVisible` and the per-item `GlobalKey`s are
/// useless for an item that is still off screen. The grid's delegate is fully
/// deterministic, though, so the offset is exactly derivable from the geometry.
///
/// The row is left sitting `padding.top` below the viewport's top edge rather
/// than flush against it, which reads as breathing room instead of a crop. That
/// is why `padding.top` is absent from the offset even though `padding` is used
/// for the horizontal extent.
///
/// The caller must clamp the result to `position.maxScrollExtent`: the last row
/// cannot always be scrolled to the very top.
double gridScrollOffsetForIndex({
  required int index,
  required int columns,
  required double viewportWidth,
  EdgeInsets padding = UiSpacing.gridPadding,
  double crossAxisSpacing = UiGrid.crossAxisSpacing,
  double mainAxisSpacing = UiGrid.mainAxisSpacing,
  double childAspectRatio = UiGrid.childAspectRatio,
}) {
  if (index <= 0 || columns <= 0) {
    return 0;
  }

  final row = index ~/ columns;
  if (row == 0) {
    return 0;
  }

  final contentWidth =
      viewportWidth - padding.horizontal - crossAxisSpacing * (columns - 1);
  if (contentWidth <= 0) {
    return 0;
  }

  final tileWidth = contentWidth / columns;
  final tileHeight = tileWidth / childAspectRatio;

  return row * (tileHeight + mainAxisSpacing);
}

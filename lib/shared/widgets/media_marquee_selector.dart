import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/ui_constants.dart';

/// Drag-to-select over a grid of media tiles.
///
/// Wraps a grid and paints a marquee rectangle over it, reporting which tiles it
/// covers. Extracted from the Library grid so the Tags tab can select the same
/// way — two copies of this would have drifted apart immediately.
///
/// Deliberately owns no selection of its own: it reports what the rectangle
/// covers and lets the caller's view model hold the truth. [itemKeys] is the
/// caller's map of media id to the key on its tile, which is what lets the
/// marquee find them on screen.
class MediaMarqueeSelector extends StatefulWidget {
  const MediaMarqueeSelector({
    super.key,
    required this.itemKeys,
    required this.selection,
    required this.isSelectionMode,
    required this.onSelectionChanged,
    required this.onEnableSelectionMode,
    required this.onClearSelection,
    required this.child,
  });

  /// Media id to the [GlobalKey] on that item's tile.
  final Map<String, GlobalKey> itemKeys;

  /// What is selected right now — the base a modifier-drag adds to.
  final Set<String> selection;

  final bool isSelectionMode;

  /// The ids the marquee now covers. Replaces the selection outright; any
  /// modifier-append has already been folded in.
  final ValueChanged<Set<String>> onSelectionChanged;

  /// A long-press drag starts selecting even when selection mode is off.
  final VoidCallback onEnableSelectionMode;

  /// Tapping the background — not a tile — while selecting.
  final VoidCallback onClearSelection;

  final Widget child;

  @override
  State<MediaMarqueeSelector> createState() => _MediaMarqueeSelectorState();
}

class _MediaMarqueeSelectorState extends State<MediaMarqueeSelector> {
  final GlobalKey _overlayKey = GlobalKey();

  Rect? _selectionRect;
  Offset? _dragStart;
  bool _isActive = false;
  bool _appendMode = false;
  Set<String> _baseSelection = <String>{};
  Set<String> _lastSelection = <String>{};
  Map<String, Rect> _cachedItemRects = <String, Rect>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _handleBackgroundTap,
      onLongPressStart: _handleLongPressStart,
      onLongPressMoveUpdate: _handleLongPressMove,
      onLongPressEnd: (_) => _end(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: (_) => _end(),
        onPointerCancel: (_) => _end(),
        child: Stack(
          key: _overlayKey,
          children: [
            Positioned.fill(child: widget.child),
            if (_selectionRect != null)
              Positioned.fromRect(
                rect: _selectionRect!,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: UiSizing.borderWidth,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return;
    }

    final localPosition = _localPosition(event.position);
    if (localPosition == null) {
      return;
    }

    _start(
      localPosition,
      appendMode: _isMultiSelectModifierPressed(),
      ensureSelectionMode: false,
    );
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    final localPosition = _localPosition(details.globalPosition);
    if (localPosition == null) {
      return;
    }

    // Touch has no modifier keys, so a long-press drag is how selection mode is
    // entered there.
    _start(localPosition, appendMode: false, ensureSelectionMode: true);
  }

  void _handleBackgroundTap(TapDownDetails details) {
    if (!widget.isSelectionMode) {
      return;
    }
    final localPosition = _localPosition(details.globalPosition);
    if (localPosition == null) {
      return;
    }

    _cachedItemRects = _computeItemRects();
    if (_isPointInsideAnyRect(localPosition, _cachedItemRects.values)) {
      return; // The tile handles its own taps.
    }
    if (!_isInsideGrid(localPosition)) {
      return; // A tap on the filters above the grid is not "tap the background".
    }

    widget.onClearSelection();
  }

  void _handleLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_isActive) {
      return;
    }
    final localPosition = _localPosition(details.globalPosition);
    if (localPosition == null) {
      return;
    }

    _updateRect(localPosition);
    _cachedItemRects = _computeItemRects();
    _updateSelection();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_isActive || _dragStart == null) {
      return;
    }

    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons & kPrimaryMouseButton) == 0) {
      _end();
      return;
    }

    final localPosition = _localPosition(event.position);
    if (localPosition == null) {
      return;
    }

    _updateRect(localPosition);
    _cachedItemRects = _computeItemRects();
    _updateSelection();
  }

  void _start(
    Offset localPosition, {
    required bool appendMode,
    required bool ensureSelectionMode,
  }) {
    _cachedItemRects = _computeItemRects();
    // A drag that begins on a tile is that tile's gesture, not a marquee.
    if (_isPointInsideAnyRect(localPosition, _cachedItemRects.values)) {
      return;
    }
    if (!_isInsideGrid(localPosition)) {
      return;
    }

    if (ensureSelectionMode) {
      widget.onEnableSelectionMode();
    }

    _baseSelection = Set<String>.from(widget.selection);
    _lastSelection = Set<String>.from(widget.selection);
    _appendMode = appendMode;
    _isActive = true;
    _dragStart = localPosition;

    setState(() {
      _selectionRect = Rect.fromPoints(localPosition, localPosition);
    });

    _updateSelection();
  }

  void _updateRect(Offset localPosition) {
    if (_dragStart == null) {
      return;
    }
    setState(() {
      _selectionRect = Rect.fromPoints(_dragStart!, localPosition);
    });
  }

  void _updateSelection() {
    if (!_isActive) {
      return;
    }

    final selectionRect = _selectionRect;
    final covered = <String>{};

    if (selectionRect != null) {
      for (final entry in _cachedItemRects.entries) {
        if (entry.value.overlaps(selectionRect)) {
          covered.add(entry.key);
        }
      }
    }

    final desired = _appendMode ? {..._baseSelection, ...covered} : covered;

    // Only report real changes: this fires on every pointer move, and each report
    // rebuilds the grid.
    if (setEquals(desired, _lastSelection)) {
      return;
    }

    _lastSelection = desired;
    widget.onSelectionChanged(desired);
  }

  void _end() {
    if (!_isActive && _selectionRect == null) {
      return;
    }

    setState(() {
      _selectionRect = null;
    });
    _isActive = false;
    _dragStart = null;
    _appendMode = false;
    _baseSelection = <String>{};
    _lastSelection = <String>{};
    _cachedItemRects = <String, Rect>{};
  }

  Offset? _localPosition(Offset globalPosition) {
    final box = _overlayBox();
    return box?.globalToLocal(globalPosition);
  }

  RenderBox? _overlayBox() {
    final overlayContext = _overlayKey.currentContext;
    if (overlayContext == null) {
      return null;
    }
    final box = overlayContext.findRenderObject() as RenderBox?;
    return box != null && box.attached ? box : null;
  }

  /// Where each tile currently sits, in the overlay's coordinates.
  ///
  /// Also drops keys whose tile has been scrolled out of the tree, so the map
  /// does not grow without bound.
  Map<String, Rect> _computeItemRects() {
    final overlayBox = _overlayBox();
    if (overlayBox == null) {
      return <String, Rect>{};
    }

    final rects = <String, Rect>{};
    final staleKeys = <String>[];

    widget.itemKeys.forEach((id, key) {
      final context = key.currentContext;
      if (context == null) {
        staleKeys.add(id);
        return;
      }
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        staleKeys.add(id);
        return;
      }
      final topLeft = renderObject.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
      rects[id] = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        renderObject.size.width,
        renderObject.size.height,
      );
    });

    for (final id in staleKeys) {
      widget.itemKeys.remove(id);
    }

    return rects;
  }

  bool _isPointInsideAnyRect(Offset point, Iterable<Rect> rects) {
    for (final rect in rects) {
      if (rect.contains(point)) {
        return true;
      }
    }
    return false;
  }

  /// Whether [point] is in the part of the wrapped area that holds the grid.
  ///
  /// Everything from the topmost tile down, full width — so the empty space
  /// beside and below the last row still starts a marquee, but anything *above*
  /// the first tile does not.
  ///
  /// That distinction only matters for the Tags tab, where the grid is one sliver
  /// under a stack of filter cards: without it, dragging across the tag chips or
  /// the directory tree would start rubber-banding. In the Library grid the tiles
  /// begin at the top, so this is the whole area and nothing changes.
  bool _isInsideGrid(Offset point) {
    if (_cachedItemRects.isEmpty) {
      return false; // Nothing on screen to select.
    }

    final box = _overlayBox();
    if (box == null) {
      return false;
    }

    var gridTop = double.infinity;
    for (final rect in _cachedItemRects.values) {
      if (rect.top < gridTop) {
        gridTop = rect.top;
      }
    }

    return point.dy >= gridTop &&
        point.dy <= box.size.height &&
        point.dx >= 0 &&
        point.dx <= box.size.width;
  }

  bool _isMultiSelectModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
  }
}

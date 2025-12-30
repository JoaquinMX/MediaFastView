import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/media_entity.dart';
import '../view_models/media_grid_view_model.dart';

class MediaMarqueeController {
  MediaMarqueeController();

  final GlobalKey overlayKey = GlobalKey();
  final Map<String, GlobalKey> mediaItemKeys = <String, GlobalKey>{};
  final ValueNotifier<Rect?> selectionRectNotifier = ValueNotifier<Rect?>(null);

  Offset? _dragStart;
  bool _appendMode = false;
  bool _isActive = false;
  Set<String> _baseSelection = <String>{};
  Set<String> _lastSelection = <String>{};
  Map<String, Rect> _cachedItemRects = <String, Rect>{};

  void pruneMediaItemKeys(Iterable<MediaEntity> media) {
    final validIds = media.map((item) => item.id).toSet();
    mediaItemKeys.removeWhere((id, _) => !validIds.contains(id));
  }

  RenderBox? get overlayBox {
    final context = overlayKey.currentContext;
    final renderObject = context?.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      return renderObject;
    }
    return null;
  }

  void dispose() {
    selectionRectNotifier.dispose();
  }

  void cacheItemRects() {
    final overlay = overlayBox;
    if (overlay == null) {
      _cachedItemRects = <String, Rect>{};
      return;
    }

    final rects = <String, Rect>{};
    final staleKeys = <String>[];

    mediaItemKeys.forEach((id, key) {
      final context = key.currentContext;
      final renderObject = context?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        staleKeys.add(id);
        return;
      }
      final topLeft = renderObject.localToGlobal(
        Offset.zero,
        ancestor: overlay,
      );
      rects[id] = Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        renderObject.size.width,
        renderObject.size.height,
      );
    });

    for (final id in staleKeys) {
      mediaItemKeys.remove(id);
    }

    _cachedItemRects = rects;
  }

  bool handlePointerDown(
    PointerDownEvent event,
    MediaViewModel viewModel,
  ) {
    if (event.kind != PointerDeviceKind.mouse ||
        (event.buttons & kPrimaryMouseButton) == 0) {
      return false;
    }

    cacheItemRects();
    final overlay = overlayBox;
    if (overlay == null) {
      return false;
    }

    final localPosition = overlay.globalToLocal(event.position);
    if (_isPointInsideAnyRect(localPosition, _cachedItemRects.values)) {
      return false;
    }

    _baseSelection = Set<String>.from(viewModel.selectedMediaIds);
    _lastSelection = Set<String>.from(viewModel.selectedMediaIds);
    _appendMode = _isMultiSelectModifierPressed();
    _isActive = true;
    _dragStart = localPosition;

    selectionRectNotifier.value =
        Rect.fromPoints(localPosition, localPosition);
    _updateSelection(viewModel);
    return true;
  }

  void handlePointerMove(
    PointerMoveEvent event,
    MediaViewModel viewModel,
  ) {
    if (!_isActive || _dragStart == null) {
      return;
    }

    final overlay = overlayBox;
    if (overlay == null) {
      return;
    }

    final localPosition = overlay.globalToLocal(event.position);
    selectionRectNotifier.value =
        Rect.fromPoints(_dragStart!, localPosition);
    _updateSelection(viewModel);
  }

  void endSelection() {
    _isActive = false;
    _dragStart = null;
    _appendMode = false;
    _baseSelection = <String>{};
    _lastSelection = <String>{};
    selectionRectNotifier.value = null;
  }

  bool _isPointInsideAnyRect(Offset point, Iterable<Rect> rects) {
    for (final rect in rects) {
      if (rect.contains(point)) {
        return true;
      }
    }
    return false;
  }

  void _updateSelection(MediaViewModel viewModel) {
    if (!_isActive) {
      return;
    }

    final selectionRect = selectionRectNotifier.value;
    final intersectingIds = <String>{};

    if (selectionRect != null) {
      for (final entry in _cachedItemRects.entries) {
        if (entry.value.overlaps(selectionRect)) {
          intersectingIds.add(entry.key);
        }
      }
    }

    final desiredSelection = _appendMode
        ? {..._baseSelection, ...intersectingIds}
        : intersectingIds;

    if (setEquals(desiredSelection, _lastSelection)) {
      return;
    }

    _lastSelection = desiredSelection;
    viewModel.selectMediaRange(desiredSelection, append: false);
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

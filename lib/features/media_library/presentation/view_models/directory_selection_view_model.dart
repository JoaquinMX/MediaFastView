import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sealed class representing the state of directory marquee/multi-select UI.
sealed class DirectorySelectionState {
  const DirectorySelectionState();
}

/// Idle state - no marquee operation in progress.
class DirectorySelectionIdle extends DirectorySelectionState {
  const DirectorySelectionIdle();
}

/// Active marquee selection state.
class DirectorySelectionActive extends DirectorySelectionState {
  const DirectorySelectionActive({
    required this.selectionRect,
    required this.dragStart,
    required this.appendMode,
    required this.marqueeBaseSelection,
    required this.lastMarqueeSelection,
    required this.cachedItemRects,
  });

  final Rect selectionRect;
  final Offset dragStart;
  final bool appendMode;
  final Set<String> marqueeBaseSelection;
  final Set<String> lastMarqueeSelection;
  final Map<String, Rect> cachedItemRects;

  DirectorySelectionActive copyWith({
    Rect? selectionRect,
    Offset? dragStart,
    bool? appendMode,
    Set<String>? marqueeBaseSelection,
    Set<String>? lastMarqueeSelection,
    Map<String, Rect>? cachedItemRects,
  }) {
    return DirectorySelectionActive(
      selectionRect: selectionRect ?? this.selectionRect,
      dragStart: dragStart ?? this.dragStart,
      appendMode: appendMode ?? this.appendMode,
      marqueeBaseSelection: marqueeBaseSelection ?? this.marqueeBaseSelection,
      lastMarqueeSelection: lastMarqueeSelection ?? this.lastMarqueeSelection,
      cachedItemRects: cachedItemRects ?? this.cachedItemRects,
    );
  }
}

/// ViewModel for managing directory marquee selection state.
class DirectorySelectionViewModel extends StateNotifier<DirectorySelectionState> {
  DirectorySelectionViewModel() : super(const DirectorySelectionIdle());

  /// Starts a marquee drag operation with the given parameters.
  void startMarquee({
    required Set<String> baseSelection,
    required Offset dragStart,
    required bool appendMode,
    required Map<String, Rect> cachedItemRects,
  }) {
    state = DirectorySelectionActive(
      selectionRect: Rect.fromPoints(dragStart, dragStart),
      dragStart: dragStart,
      appendMode: appendMode,
      marqueeBaseSelection: Set<String>.from(baseSelection),
      lastMarqueeSelection: Set<String>.from(baseSelection),
      cachedItemRects: cachedItemRects,
    );
  }

  /// Updates the marquee selection rect and cached item rects during drag.
  void updateMarqueeDrag({
    required Offset currentPosition,
    required Map<String, Rect> cachedItemRects,
  }) {
    if (state is! DirectorySelectionActive) {
      return;
    }
    final active = state as DirectorySelectionActive;
    state = active.copyWith(
      selectionRect: Rect.fromPoints(active.dragStart, currentPosition),
      cachedItemRects: cachedItemRects,
    );
  }

  /// Updates the marquee selection based on intersecting items.
  void updateMarqueeSelection({
    required Set<String> desiredSelection,
  }) {
    if (state is! DirectorySelectionActive) {
      return;
    }
    final active = state as DirectorySelectionActive;
    state = active.copyWith(
      lastMarqueeSelection: desiredSelection,
    );
  }

  /// Ends the marquee selection operation, returning to idle state.
  void endMarquee() {
    state = const DirectorySelectionIdle();
  }

  /// Resets to idle state (useful for cancel operations).
  void reset() {
    state = const DirectorySelectionIdle();
  }
}

/// Provider for DirectorySelectionViewModel with auto-dispose.
final directorySelectionViewModelProvider = StateNotifierProvider.autoDispose<
    DirectorySelectionViewModel,
    DirectorySelectionState>(
  (ref) => DirectorySelectionViewModel(),
);

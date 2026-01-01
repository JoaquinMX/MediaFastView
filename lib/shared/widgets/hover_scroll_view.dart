import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A scroll view that responds to hover wheel events on desktop.
///
/// This widget forwards pointer scroll signals (e.g., mouse wheel or middle
/// button scrolling) to the provided [ScrollController] so that horizontal chip
/// lists remain scrollable without requiring drag gestures.
class HoverScrollView extends StatefulWidget {
  const HoverScrollView({
    super.key,
    required this.scrollDirection,
    required this.child,
    this.controller,
    this.physics,
    this.scrollAmountMultiplier = 1.0,
  });

  final Axis scrollDirection;
  final Widget child;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  /// Scales the pointer scroll delta before applying it to the scroll offset.
  final double scrollAmountMultiplier;

  @override
  State<HoverScrollView> createState() => _HoverScrollViewState();
}

class _HoverScrollViewState extends State<HoverScrollView> {
  late final ScrollController _controller =
      widget.controller ?? ScrollController();

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final delta = switch (widget.scrollDirection) {
          Axis.horizontal => event.scrollDelta.dy != 0
              ? event.scrollDelta.dy
              : event.scrollDelta.dx,
          Axis.vertical => event.scrollDelta.dy,
        } *
        widget.scrollAmountMultiplier;

    if (delta == 0 || !_controller.hasClients) {
      return;
    }

    final position = _controller.position;
    final targetOffset = (_controller.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);

    if (targetOffset != _controller.offset) {
      _controller.jumpTo(targetOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: SingleChildScrollView(
        scrollDirection: widget.scrollDirection,
        controller: _controller,
        physics: widget.physics,
        child: widget.child,
      ),
    );
  }
}

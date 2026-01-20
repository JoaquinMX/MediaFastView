import 'package:flutter/material.dart';

/// A zoomable and pannable image viewer widget
class ZoomPanViewer extends StatefulWidget {
  const ZoomPanViewer({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 4.0,
    this.onToggleControls,
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final VoidCallback? onToggleControls;

  @override
  State<ZoomPanViewer> createState() => _ZoomPanViewerState();
}

class _ZoomPanViewerState extends State<ZoomPanViewer> {
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onToggleControls,
        behavior: HitTestBehavior.deferToChild,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: widget.minScale,
          maxScale: widget.maxScale,
          constrained: true,
          child: widget.child,
        ),
      ),
    );
  }
}

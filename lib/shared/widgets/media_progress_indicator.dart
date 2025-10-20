import 'package:flutter/material.dart';

/// Builder for a custom counter presentation.
typedef MediaCounterBuilder = Widget Function(
  BuildContext context,
  int currentIndex,
  int totalItems,
  TextStyle? counterTextStyle,
);

/// Builder for a custom progress presentation.
typedef MediaProgressBarBuilder = Widget Function(
  BuildContext context,
  double progress,
  Color progressColor,
  Color backgroundColor,
  double height,
);

/// Shared widget that combines a textual counter with a progress visual.
class MediaProgressIndicator extends StatelessWidget {
  const MediaProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalItems,
    this.progress,
    this.showCounter = true,
    this.showProgressBar = true,
    this.counterTextStyle,
    this.progressColor = Colors.white,
    this.backgroundColor = Colors.white30,
    this.height = 4,
    this.counterBuilder,
    this.progressBuilder,
    this.spacing = 8,
  });

  final int currentIndex;
  final int totalItems;
  final double? progress;
  final bool showCounter;
  final bool showProgressBar;
  final TextStyle? counterTextStyle;
  final Color progressColor;
  final Color backgroundColor;
  final double height;
  final double spacing;
  final MediaCounterBuilder? counterBuilder;
  final MediaProgressBarBuilder? progressBuilder;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (showCounter) {
      children.add(counterBuilder?.call(
            context,
            currentIndex,
            totalItems,
            counterTextStyle,
          ) ??
          _DefaultCounter(
            currentIndex: currentIndex,
            totalItems: totalItems,
            style: counterTextStyle,
          ));
    }

    if (showCounter && showProgressBar) {
      children.add(SizedBox(height: spacing));
    }

    if (showProgressBar) {
      final progressValue = progress ??
          (totalItems > 0 ? (currentIndex + 1) / totalItems : 0.0);
      children.add(SizedBox(
        height: height,
        width: double.infinity,
        child: progressBuilder?.call(
              context,
              progressValue.clamp(0.0, 1.0),
              progressColor,
              backgroundColor,
              height,
            ) ??
            _DefaultProgressBar(
              progress: progressValue,
              progressColor: progressColor,
              backgroundColor: backgroundColor,
            ),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _DefaultCounter extends StatelessWidget {
  const _DefaultCounter({
    required this.currentIndex,
    required this.totalItems,
    this.style,
  });

  final int currentIndex;
  final int totalItems;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${currentIndex + 1} / $totalItems',
      style: style ??
          const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class _DefaultProgressBar extends StatelessWidget {
  const _DefaultProgressBar({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            color: progressColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

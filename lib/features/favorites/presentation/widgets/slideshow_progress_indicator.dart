import 'package:flutter/material.dart';

/// A progress indicator widget for slideshow that shows current position and total items.
class SlideshowProgressIndicator extends StatelessWidget {
  const SlideshowProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalItems,
    this.progress = 0.0,
    this.showCounter = true,
    this.showProgressBar = true,
  });

  final int currentIndex;
  final int totalItems;
  final double progress;
  final bool showCounter;
  final bool showProgressBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCounter) _buildCounter(),
        if (showCounter && showProgressBar) const SizedBox(height: 8),
        if (showProgressBar) _buildProgressBar(),
      ],
    );
  }

  Widget _buildCounter() {
    return Text(
      '${currentIndex + 1} / $totalItems',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 4,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: totalItems > 0 ? (currentIndex + 1) / totalItems : 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Favorite toggle button for full-screen mode
class FullScreenFavoriteToggle extends StatelessWidget {
  const FullScreenFavoriteToggle({
    super.key,
    required this.isFavorite,
    required this.onToggle,
  });

  final bool isFavorite;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onToggle,
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? colorScheme.error : colorScheme.onSurface,
        size: 28,
      ),
    );
  }
}

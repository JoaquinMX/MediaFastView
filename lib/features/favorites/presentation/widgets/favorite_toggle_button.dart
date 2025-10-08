import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../view_models/favorites_view_model.dart';

/// A heart-shaped button for toggling favorite status of media items.
class FavoriteToggleButton extends ConsumerStatefulWidget {
  const FavoriteToggleButton({super.key, required this.media, this.onToggle});

  final MediaEntity media;
  final ValueChanged<bool>? onToggle;

  @override
  ConsumerState<FavoriteToggleButton> createState() =>
      _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState
    extends ConsumerState<FavoriteToggleButton> {
  bool _isProcessing = false;

  Future<void> _handleToggle() async {
    if (_isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    final viewModel = ref.read(favoritesViewModelProvider.notifier);

    try {
      await viewModel.toggleFavorite(widget.media);
      final updatedStatus = viewModel.isFavoriteInState(widget.media.id);
      widget.onToggle?.call(updatedStatus);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ = ref.watch(favoritesViewModelProvider);
    final viewModel = ref.read(favoritesViewModelProvider.notifier);
    final isFavorite = viewModel.isFavoriteInState(widget.media.id);

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.red : Colors.white,
      ),
      onPressed: _isProcessing ? null : _handleToggle,
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: isFavorite ? Colors.red : Colors.white,
      ),
    );
  }
}

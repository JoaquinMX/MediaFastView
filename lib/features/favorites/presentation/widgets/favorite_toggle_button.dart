import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/domain/entities/media_entity.dart';
import '../view_models/favorites_view_model.dart';

/// A heart-shaped button for toggling favorite status of media items.
class FavoriteToggleButton extends ConsumerWidget {
  const FavoriteToggleButton({super.key, required this.media, this.onToggle});

  final MediaEntity media;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesViewModelProvider);
    final viewModel = ref.read(favoritesViewModelProvider.notifier);
    final isFavorite = viewModel.isFavoriteInState(media.id);
    final isBusy = state is FavoritesLoading;

    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.red : Colors.white,
      ),
      onPressed: isBusy
          ? null
          : () async {
              await viewModel.toggleFavorite(media);
              onToggle?.call(!isFavorite);
            },
      tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        foregroundColor: isFavorite ? Colors.red : Colors.white,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/favorite_toggle_button.dart'
    as shared;
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
    final hasLoadedFavorites = viewModel.hasLoadedFavorites;
    final isBusy = state is FavoritesLoading && hasLoadedFavorites;

    return shared.FavoriteToggleButton(
      isFavorite: isFavorite,
      onToggle: () async {
        await viewModel.toggleFavorite(media);
        onToggle?.call(!isFavorite);
      },
      isBusy: isBusy,
      showBusyIndicator: true,
      backgroundColor: Colors.black.withValues(alpha: 0.5),
      favoriteColor: Colors.red,
      idleColor: Colors.white,
    );
  }
}

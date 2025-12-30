import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../tagging/presentation/widgets/tag_filter_chips.dart';
import '../../domain/entities/media_entity.dart';
import '../view_models/media_grid_view_model.dart';

class MediaFilterBar extends StatelessWidget {
  const MediaFilterBar({
    super.key,
    required this.viewModel,
    required this.state,
    required this.favoritesState,
    required this.isSelectionMode,
  });

  final MediaViewModel viewModel;
  final MediaState state;
  final FavoritesState favoritesState;
  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    final selectedTagIds = state is MediaLoaded
        ? state.selectedTagIds
        : const <String>[];
    final showFavoritesOnly = state is MediaLoaded
        ? state.showFavoritesOnly
        : viewModel.showFavoritesOnly;
    final showUntaggedOnly = state is MediaLoaded
        ? state.showUntaggedOnly
        : viewModel.showUntaggedOnly;
    final visibleMediaTypes = state is MediaLoaded
        ? state.visibleMediaTypes
        : viewModel.visibleMediaTypes;
    final hasFavoriteMedia = switch (favoritesState) {
      FavoritesLoaded(:final favorites) => favorites.isNotEmpty,
      _ => false,
    };
    final shouldShowFavoritesChip = hasFavoriteMedia || showFavoritesOnly;

    return Container(
      padding: UiSpacing.tagFilterPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final type in [
                MediaType.image,
                MediaType.video,
                MediaType.directory,
              ])
                FilterChip(
                  label: Text(type.label),
                  avatar: Icon(_iconForType(type)),
                  selected: visibleMediaTypes.contains(type),
                  onSelected: (selected) => _onMediaTypeSelected(
                    type,
                    selected,
                    visibleMediaTypes,
                  ),
                ),
              if (shouldShowFavoritesChip)
                FilterChip(
                  label: const Text('Favorites'),
                  avatar: const Icon(Icons.star, color: Colors.amber),
                  selected: showFavoritesOnly,
                  onSelected: (value) {
                    if (!hasFavoriteMedia && value) {
                      return;
                    }
                    viewModel.setShowFavoritesOnly(value);
                  },
                ),
              FilterChip(
                label: const Text('Untagged'),
                avatar: const Icon(Icons.label_off),
                selected: showUntaggedOnly,
                onSelected: (value) async {
                  await viewModel.setShowUntaggedOnly(value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TagFilterChips(
            selectedTagIds:
                isSelectionMode ? viewModel.tagIdsInSelection() : selectedTagIds,
            onSelectionChanged:
                isSelectionMode ? (_) {} : viewModel.filterByTags,
            onTagTapped: isSelectionMode
                ? (tag, _) => viewModel.toggleTagForSelection(tag)
                : null,
            showAllButton: !isSelectionMode,
          ),
        ],
      ),
    );
  }

  IconData _iconForType(MediaType type) => switch (type) {
        MediaType.image => Icons.image_outlined,
        MediaType.video => Icons.movie_creation_outlined,
        MediaType.directory => Icons.folder,
        MediaType.text => Icons.description_outlined,
      };

  void _onMediaTypeSelected(
    MediaType type,
    bool isSelected,
    Set<MediaType> currentSelection,
  ) {
    final updatedSelection = Set<MediaType>.from(currentSelection);
    if (isSelected) {
      updatedSelection.add(type);
    } else {
      if (updatedSelection.length == 1) {
        return; // Prevent clearing all types
      }
      updatedSelection.remove(type);
    }

    viewModel.setVisibleMediaTypes(updatedSelection);
  }
}

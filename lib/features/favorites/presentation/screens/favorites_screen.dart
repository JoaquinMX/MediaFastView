import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/widgets/media_grid_item.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../view_models/favorites_view_model.dart';
import '../widgets/favorite_toggle_button.dart';
import 'slideshow_screen.dart';
import '../../../../core/services/logging_service.dart';

/// Screen for displaying favorite media items in a grid layout with slideshow mode.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(favoritesViewModelProvider.notifier).loadFavorites(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesViewModelProvider);
    final viewModel = ref.read(favoritesViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          if (state is FavoritesLoaded && state.media.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Start Slideshow',
              onPressed: () => _startSlideshow(context, state.media),
            ),
        ],
      ),
      body: switch (state) {
        FavoritesLoading() => const Center(child: CircularProgressIndicator()),
        FavoritesLoaded(:final media) => _buildGrid(media),
        FavoritesError(:final message) => _buildError(message, viewModel),
        FavoritesEmpty() => _buildEmpty(viewModel),
      },
    );
  }

  Widget _buildGrid(List<MediaEntity> media) {
    LoggingService.instance.info(
      'Building grid with ${media.length} media items',
    );
    for (final item in media) {
      final fileExists = File(item.path).existsSync();
      LoggingService.instance.debug(
        'Media item - ID: ${item.id}, Name: ${item.name}, Path: ${item.path}, File exists: $fileExists',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return _buildFavoriteGridItem(mediaItem, media);
      },
    );
  }

  Widget _buildFavoriteGridItem(MediaEntity media, List<MediaEntity> favoritesList) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaGridItem(
          media: media,
          onTap: () {
            final directoryPath = p.dirname(media.path);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => FullScreenViewerScreen(
                  directoryPath: directoryPath,
                  initialMediaId: media.id,
                  mediaList: favoritesList, // Pass favorites list for restricted navigation
                ),
              ),
            );
          },
        ),

        // Favorite toggle button overlay
        Positioned(top: 8, right: 8, child: FavoriteToggleButton(media: media)),

        // Media info overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Text(
              media.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message, FavoritesViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.loadFavorites,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(FavoritesViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No favorites yet'),
          const SizedBox(height: 8),
          const Text(
            'Mark media files as favorites to see them here',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.loadFavorites,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _startSlideshow(BuildContext context, List<MediaEntity> media) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SlideshowScreen(mediaList: media),
      ),
    );
  }
}

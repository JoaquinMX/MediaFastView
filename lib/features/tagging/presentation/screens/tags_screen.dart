import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/ui_constants.dart';
import '../../../favorites/presentation/screens/slideshow_screen.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../favorites/presentation/widgets/favorite_toggle_button.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/widgets/media_grid_item.dart';
import '../view_models/tags_view_model.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    Future.microtask(() async {
      await ref.read(tagsViewModelProvider.notifier).loadTags();
      await ref.read(favoritesViewModelProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tagsViewModelProvider);
    final viewModel = ref.read(tagsViewModelProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload tags',
            onPressed: viewModel.loadTags,
          ),
        ],
      ),
      body: switch (state) {
        TagsLoading() => const Center(child: CircularProgressIndicator()),
        TagsLoaded loaded => _buildSections(loaded, viewModel),
        TagsEmpty() => _buildEmpty(viewModel),
        TagsError(:final message) => _buildError(message, viewModel),
      },
    );
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Widget _buildSections(TagsLoaded state, TagsViewModel viewModel) {
    final selectedSections = state.sections
        .where((section) => state.selectedTagIds.contains(section.id))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: viewModel.loadTags,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildTagSelectionChips(state, viewModel),
          const SizedBox(height: 24),
          if (selectedSections.isEmpty)
            _buildSelectionPlaceholder()
          else
            _buildFilteredResults(selectedSections, state.filteredMedia),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: const InputDecoration(
        labelText: 'Search tags',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTagSelectionChips(
    TagsLoaded state,
    TagsViewModel viewModel,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredSections = state.sections.where((section) {
      if (query.isEmpty) {
        return true;
      }
      return section.name.toLowerCase().contains(query);
    }).toList();

    if (filteredSections.isEmpty) {
      return Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No tags match your search.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filteredSections.map((section) {
            final isSelected = state.selectedTagIds.contains(section.id);
            return FilterChip(
              label: Text(
                '${section.name} • ${section.itemCount} '
                'item${section.itemCount == 1 ? '' : 's'}',
              ),
              avatar: section.isFavorites
                  ? const Icon(Icons.star, color: Colors.amber)
                  : section.color != null
                      ? CircleAvatar(
                          backgroundColor: section.color,
                          radius: 12,
                        )
                      : null,
              selected: isSelected,
              onSelected: (selected) =>
                  viewModel.setTagSelected(section.id, selected),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSelectionPlaceholder() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select tags to view matching media',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the chips above to choose which tags or favorites to display across your library.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredResults(
    List<TagSection> selectedSections,
    List<MediaEntity> filteredMedia,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSelectionSummary(selectedSections, filteredMedia),
        const SizedBox(height: 16),
        if (filteredMedia.isEmpty)
          _buildNoResultsCard()
        else
          _buildAggregatedMediaGrid(filteredMedia),
      ],
    );
  }

  Widget _buildSelectionSummary(
    List<TagSection> selectedSections,
    List<MediaEntity> filteredMedia,
  ) {
    final theme = Theme.of(context);
    final tagCount = selectedSections.length;
    final mediaCount = filteredMedia.length;
    final tagLabel = tagCount == 1 ? 'tag' : 'tags';
    final mediaLabel = mediaCount == 1 ? 'item' : 'items';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Media matching $tagCount $tagLabel',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.slideshow),
                  tooltip: 'Start slideshow',
                  onPressed: filteredMedia.isEmpty
                      ? null
                      : () => _startSlideshow(filteredMedia),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$mediaCount $mediaLabel found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (selectedSections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedSections
                    .map(_buildSelectedTagChip)
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTagChip(TagSection section) {
    Widget? avatar;
    if (section.isFavorites) {
      avatar = const Icon(Icons.star, color: Colors.amber);
    } else if (section.color != null) {
      avatar = CircleAvatar(
        backgroundColor: section.color,
        radius: 12,
      );
    }

    return Chip(
      avatar: avatar,
      label: Text(section.name),
    );
  }

  Widget _buildNoResultsCard() {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No media match the selected tags',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting different tags or assigning tags to more media items.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAggregatedMediaGrid(List<MediaEntity> media) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const desiredTileWidth = 180.0;
        final columns = math.max(
          1,
          (constraints.maxWidth / desiredTileWidth).floor(),
        );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: UiGrid.crossAxisSpacing,
            mainAxisSpacing: UiGrid.mainAxisSpacing,
            childAspectRatio: 0.85,
          ),
          itemCount: media.length,
          itemBuilder: (context, index) {
            final mediaItem = media[index];
            return _buildMediaTile(mediaItem, media);
          },
        );
      },
    );
  }

  Widget _buildMediaTile(MediaEntity media, List<MediaEntity> collection) {
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaGridItem(
          media: media,
          onTap: () => _openFullScreen(collection, media),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: FavoriteToggleButton(
            media: media,
            onToggle: (_) =>
                ref.read(tagsViewModelProvider.notifier).refreshFavorites(),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message, TagsViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.loadTags,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(TagsViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.label_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No tags or favorites found yet'),
          const SizedBox(height: 8),
          const Text(
            'Create tags or favorite media items to organize your library.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: viewModel.loadTags,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(List<MediaEntity> mediaList, MediaEntity media) {
    final directoryPath = p.dirname(media.path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenViewerScreen(
          directoryPath: directoryPath,
          initialMediaId: media.id,
          mediaList: mediaList,
        ),
      ),
    );
  }

  void _startSlideshow(List<MediaEntity> media) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SlideshowScreen(mediaList: media),
      ),
    );
  }
}

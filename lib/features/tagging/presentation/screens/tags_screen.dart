import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../favorites/presentation/screens/slideshow_screen.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/widgets/media_grid_item.dart';
import '../../domain/enums/tag_filter_mode.dart';
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
        TagsLoaded loaded => _buildContent(loaded, viewModel),
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

  Widget _buildContent(TagsLoaded state, TagsViewModel viewModel) {
    final sections = state.sections;
    final selectedSections = sections
        .where((section) => state.selectedTagIds.contains(section.id))
        .toList();
    final aggregatedMedia = _collectMediaFromSections(
      selectedSections,
      state.filterMode,
    );

    return RefreshIndicator(
      onRefresh: viewModel.loadTags,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildTagSelectionChips(state, viewModel),
          const SizedBox(height: 12),
          _buildFilterModeToggle(state, viewModel),
          const SizedBox(height: 24),
          if (selectedSections.isEmpty)
            _buildSelectionPlaceholder()
          else ...[
            _buildSelectionSummary(
              aggregatedMedia,
              viewModel,
              state.filterMode,
              state.selectedTagIds.length,
            ),
            const SizedBox(height: 12),
            if (aggregatedMedia.isEmpty)
              _buildNoResultsMessage()
            else
              _buildMediaGrid(aggregatedMedia, aggregatedMedia),
          ],
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
              'Select tags to view their media',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the chips above to choose which tags or favorites to display.',
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

  Widget _buildSelectionSummary(
    List<MediaEntity> aggregatedMedia,
    TagsViewModel viewModel,
    TagFilterMode filterMode,
    int selectedTagCount,
  ) {
    final theme = Theme.of(context);
    final filterDescription = filterMode.matchesAll
        ? 'Matching all selected tags'
        : 'Matching any selected tag';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Showing ${aggregatedMedia.length} '
                'item${aggregatedMedia.length == 1 ? '' : 's'}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                selectedTagCount <= 1
                    ? filterDescription
                    : '$filterDescription (${selectedTagCount} tags)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: viewModel.clearSelection,
          child: const Text('Clear selection'),
        ),
        if (aggregatedMedia.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.slideshow),
            tooltip: 'Start slideshow',
            onPressed: () => _startSlideshow(aggregatedMedia),
          ),
      ],
    );
  }

  Widget _buildNoResultsMessage() {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No media found for the selected tags',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try choosing different tags or clear the selection.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MediaEntity> _collectMediaFromSections(
    List<TagSection> sections,
    TagFilterMode filterMode,
  ) {
    if (sections.isEmpty) {
      return const <MediaEntity>[];
    }

    final mediaById = <String, MediaEntity>{};
    final occurrenceCount = <String, int>{};

    for (final section in sections) {
      final seenInSection = <String>{};
      for (final media in section.allMedia) {
        mediaById[media.id] = media;
        if (seenInSection.add(media.id)) {
          occurrenceCount.update(
            media.id,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    if (!filterMode.matchesAll) {
      return mediaById.values.toList();
    }

    final requiredMatches = sections.length;
    return occurrenceCount.entries
        .where((entry) => entry.value == requiredMatches)
        .map((entry) => mediaById[entry.key]!)
        .toList();
  }

  Widget _buildFilterModeToggle(
    TagsLoaded state,
    TagsViewModel viewModel,
  ) {
    final isMatchAll = state.filterMode.matchesAll;
    return Card(
      elevation: 1,
      child: SwitchListTile.adaptive(
        value: isMatchAll,
        onChanged: (value) => viewModel.setFilterMode(
          value ? TagFilterMode.all : TagFilterMode.any,
        ),
        title: const Text('Match all selected tags'),
        subtitle: const Text(
          'When enabled, media must include every selected tag.',
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }

  Widget _buildMediaGrid(
    List<MediaEntity> collection,
    List<MediaEntity> media,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final mediaItem = media[index];
        return _buildMediaTile(mediaItem, collection);
      },
    );
  }

  Widget _buildMediaTile(MediaEntity media, List<MediaEntity> collection) {
    return MediaGridItem(
      media: media,
      onTap: () => _openFullScreen(collection, media),
      onFavoriteToggle: (_) =>
          ref.read(tagsViewModelProvider.notifier).refreshFavorites(),
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

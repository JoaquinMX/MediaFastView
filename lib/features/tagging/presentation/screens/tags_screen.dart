import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../favorites/presentation/screens/slideshow_screen.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/widgets/media_grid_item.dart';
import '../../../media_library/presentation/widgets/column_selector_popup.dart';
import '../../domain/enums/tag_filter_mode.dart';
import '../../domain/enums/tag_media_type_filter.dart';
import '../view_models/tags_view_model.dart';
import '../widgets/tag_directory_chip.dart';
import '../../../../shared/providers/grid_columns_provider.dart';

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
    final gridColumns = ref.watch(gridColumnsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload tags',
            onPressed: viewModel.loadTags,
          ),
          IconButton(
            icon: const Icon(Icons.view_module),
            tooltip: 'Change grid columns',
            onPressed: () => _showColumnSelector(context, gridColumns),
          ),
        ],
      ),
      body: switch (state) {
        TagsLoading() => const Center(child: CircularProgressIndicator()),
        TagsLoaded loaded => _buildContent(loaded, viewModel, gridColumns),
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

  Widget _buildContent(
    TagsLoaded state,
    TagsViewModel viewModel,
    int gridColumns,
  ) {
    final sections = state.sections;
    final selectedSections = sections
        .where((section) => state.selectedTagIds.contains(section.id))
        .toList();
    final hasSelectedTags = selectedSections.isNotEmpty;
    final sectionsForFiltering =
        hasSelectedTags || state.excludedTagIds.isEmpty ? selectedSections : sections;
    final aggregatedMedia = _collectMediaFromSections(
      sectionsForFiltering,
      state.filterMode,
      state.excludedTagIds,
      hasSelectedTags,
    );
    final filteredMedia = _filterMediaByType(
      aggregatedMedia,
      state.mediaTypeFilter,
    );
    final selectedDirectories = _collectDirectoriesFromSections(
      sectionsForFiltering,
      state.excludedTagIds,
    );

    final headerWidgets = <Widget>[
      _buildSearchField(),
      const SizedBox(height: 12),
      _buildTagSelectionChips(state, viewModel),
      const SizedBox(height: 12),
      _buildFilterModeToggle(state, viewModel),
      const SizedBox(height: 12),
      _buildMediaTypeFilter(state, viewModel),
      const SizedBox(height: 24),
    ];

    if (selectedSections.isEmpty && state.excludedTagIds.isEmpty) {
      headerWidgets.add(_buildSelectionPlaceholder());
    } else {
      headerWidgets.addAll([
        _buildSelectionSummary(
          filteredMedia,
          viewModel,
          state.filterMode,
          state.selectedTagIds.length,
          state.excludedTagIds.length,
        ),
        const SizedBox(height: 12),
      ]);

      if (selectedDirectories.isNotEmpty) {
        headerWidgets.addAll([
          _buildDirectorySection(selectedDirectories),
          const SizedBox(height: 24),
        ]);
      }

      if (filteredMedia.isEmpty) {
        headerWidgets.add(_buildNoResultsMessage());
      } else {
        headerWidgets.add(const SizedBox(height: 12));
      }
    }

    final slivers = <Widget>[
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildListDelegate(headerWidgets),
        ),
      ),
    ];

    if (filteredMedia.isNotEmpty &&
        (selectedSections.isNotEmpty || state.excludedTagIds.isNotEmpty)) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: _buildMediaGrid(filteredMedia, filteredMedia, gridColumns),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadTags,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
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
            final isExcluded = state.excludedTagIds.contains(section.id);
            final labelText = StringBuffer(section.name)
              ..write(' • ${section.itemCount} ')
              ..write('item${section.itemCount == 1 ? '' : 's'}');
            if (isExcluded) {
              labelText.write(' (excluded)');
            }

            return GestureDetector(
              onLongPress: () =>
                  viewModel.setTagExcluded(section.id, !isExcluded),
              onSecondaryTap: () =>
                  viewModel.setTagExcluded(section.id, !isExcluded),
              child: FilterChip(
                label: Text(labelText.toString()),
                avatar: section.isFavorites
                    ? const Icon(Icons.star, color: Colors.amber)
                    : section.color != null
                        ? CircleAvatar(
                            backgroundColor: section.color,
                            radius: 12,
                          )
                        : null,
                selected: isSelected || isExcluded,
                selectedColor: isExcluded
                    ? Theme.of(context)
                        .colorScheme
                        .errorContainer
                        .withOpacity(0.9)
                    : null,
                checkmarkColor: isExcluded
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : null,
                labelStyle: isExcluded
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : null,
                onSelected: (selected) =>
                    viewModel.setTagSelected(section.id, selected),
              ),
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
            const SizedBox(height: 8),
            Text(
              'Long press (mobile) or right-click (desktop) a tag to exclude it.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
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
    int excludedTagCount,
  ) {
    final theme = Theme.of(context);
    final filterDescription = filterMode.matchesAll
        ? 'Matching all selected tags'
        : 'Matching any selected tag';
    final exclusionDescription = excludedTagCount > 0
        ? 'Excluding $excludedTagCount tag${excludedTagCount == 1 ? '' : 's'}'
        : null;

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
                [
                  if (selectedTagCount > 0)
                    selectedTagCount <= 1
                        ? filterDescription
                        : '$filterDescription (${selectedTagCount} tags)',
                  if (selectedTagCount == 0) 'No tags selected',
                  if (exclusionDescription != null) exclusionDescription,
                ].where((text) => text.isNotEmpty).join(' • '),
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
              'Try choosing different tags or adjust the media type filter.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MediaEntity> _filterMediaByType(
    List<MediaEntity> media,
    TagMediaTypeFilter filter,
  ) {
    return media.where((item) {
      switch (filter) {
        case TagMediaTypeFilter.images:
          return item.type == MediaType.image;
        case TagMediaTypeFilter.videos:
          return item.type == MediaType.video;
        case TagMediaTypeFilter.all:
          return item.type == MediaType.image || item.type == MediaType.video;
      }
    }).toList();
  }

  List<MediaEntity> _collectMediaFromSections(
    List<TagSection> sections,
    TagFilterMode filterMode,
    List<String> excludedTagIds,
    bool hasSelectedTags,
  ) {
    if (sections.isEmpty) {
      return const <MediaEntity>[];
    }

    final excludedSet = excludedTagIds.toSet();
    final mediaById = <String, MediaEntity>{};
    final occurrenceCount = <String, int>{};

    for (final section in sections) {
      final seenInSection = <String>{};
      for (final media in section.allMedia) {
        if (excludedSet.isNotEmpty &&
            media.tagIds.any(excludedSet.contains)) {
          continue;
        }
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

    final requireAll = hasSelectedTags && filterMode.matchesAll;
    if (!requireAll) {
      return mediaById.values.toList();
    }

    final requiredMatches = sections.length;
    return occurrenceCount.entries
        .where((entry) => entry.value == requiredMatches)
        .map((entry) => mediaById[entry.key]!)
        .toList();
  }

  List<TagDirectoryContent> _collectDirectoriesFromSections(
    List<TagSection> sections,
    List<String> excludedTagIds,
  ) {
    if (sections.isEmpty) {
      return const <TagDirectoryContent>[];
    }

    final excludedSet = excludedTagIds.toSet();
    final map = <String, TagDirectoryContent>{};
    for (final section in sections) {
      for (final directoryContent in section.directories) {
        if (excludedSet.isNotEmpty &&
            directoryContent.directory.tagIds.any(excludedSet.contains)) {
          continue;
        }
        final filteredMedia = excludedSet.isEmpty
            ? directoryContent.media
            : directoryContent.media
                .where((media) => !media.tagIds.any(excludedSet.contains))
                .toList();
        if (filteredMedia.isEmpty) {
          continue;
        }
        map.update(
          directoryContent.directory.id,
          (existing) {
            final merged = <String, MediaEntity>{
              for (final media in existing.media) media.id: media,
              for (final media in filteredMedia) media.id: media,
            };
            return TagDirectoryContent(
              directory: directoryContent.directory,
              media: merged.values.toList(),
            );
          },
          ifAbsent: () => TagDirectoryContent(
            directory: directoryContent.directory,
            media: List<MediaEntity>.from(filteredMedia),
          ),
        );
      }
    }

    final directories = map.values.toList()
      ..sort((a, b) => a.directory.name.compareTo(b.directory.name));
    return directories;
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

  Widget _buildMediaTypeFilter(
    TagsLoaded state,
    TagsViewModel viewModel,
  ) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Media type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: TagMediaTypeFilter.values.map((filter) {
                final isSelected = state.mediaTypeFilter == filter;
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  onSelected: (_) => viewModel.setMediaTypeFilter(filter),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectorySection(List<TagDirectoryContent> directories) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Directories', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: directories
                  .map(
                    (content) => TagDirectoryChip(
                      directory: content.directory,
                      mediaCount: content.media.length,
                      onTap: () => _openDirectoryFullScreen(content),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  SliverGrid _buildMediaGrid(
    List<MediaEntity> collection,
    List<MediaEntity> media,
    int columns,
  ) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final mediaItem = media[index];
          return _buildMediaTile(mediaItem, collection);
        },
        childCount: media.length,
      ),
    );
  }

  void _showColumnSelector(BuildContext context, int currentColumns) {
    showDialog(
      context: context,
      builder: (context) => ColumnSelectorPopup(
        currentColumns: currentColumns,
        onColumnsSelected: (columns) {
          ref.read(gridColumnsProvider.notifier).setColumns(columns);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildMediaTile(MediaEntity media, List<MediaEntity> collection) {
    return MediaGridItem(
      media: media,
      onTap: () => _openFullScreen(collection, media),
      onFavoriteToggle: (_) =>
          ref.read(tagsViewModelProvider.notifier).refreshFavorites(),
      onSelectionToggle: () {},
      isSelected: false,
      isSelectionMode: false,
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
    if (media.type == MediaType.directory) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenViewerScreen(
            directoryPath: media.path,
            directoryName: media.name,
            bookmarkData: media.bookmarkData,
          ),
        ),
      );
      return;
    }

    final directoryPath = p.dirname(media.path);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenViewerScreen(
          directoryPath: directoryPath,
          directoryName: p.basename(directoryPath),
          initialMediaId: media.id,
          mediaList: mediaList,
        ),
      ),
    );
  }

  void _openDirectoryFullScreen(TagDirectoryContent directoryContent) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenViewerScreen(
          directoryPath: directoryContent.directory.path,
          directoryName: directoryContent.directory.name,
          bookmarkData: directoryContent.directory.bookmarkData,
          initialMediaId: directoryContent.media.isNotEmpty
              ? directoryContent.media.first.id
              : null,
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

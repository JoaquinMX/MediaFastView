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
import '../view_models/tags_view_model.dart';
import '../../../../shared/providers/grid_columns_provider.dart';

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String? _selectedDirectoryId;

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
              () => _clearSelection(viewModel),
            ),
            const SizedBox(height: 12),
            if (aggregatedMedia.isEmpty)
              _buildNoResultsMessage()
            else if (selectedSections.length == 1 &&
                selectedSections.first.directories.isNotEmpty)
              _buildTagDetailView(
                selectedSections.first,
                gridColumns,
              )
            else
              _buildMediaGrid(aggregatedMedia, aggregatedMedia, gridColumns),
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
                  _onTagChipToggled(section.id, selected, viewModel),
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
    VoidCallback onClearSelection,
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
          onPressed: onClearSelection,
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

  void _onTagChipToggled(
    String tagId,
    bool isSelected,
    TagsViewModel viewModel,
  ) {
    viewModel.setTagSelected(tagId, isSelected);
    setState(() {
      _selectedDirectoryId = null;
    });
  }

  void _clearSelection(TagsViewModel viewModel) {
    viewModel.clearSelection();
    setState(() {
      _selectedDirectoryId = null;
    });
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

  Widget _buildTagDetailView(
    TagSection section,
    int gridColumns,
  ) {
    _ensureSelectedDirectorySelection(section);

    TagDirectoryContent? selectedContent;
    if (_selectedDirectoryId != null) {
      for (final content in section.directories) {
        if (content.directory.id == _selectedDirectoryId) {
          selectedContent = content;
          break;
        }
      }
    }

    final entries = _buildDirectoryEntries(section.directories);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 800;
            final treeView = _buildDirectoryTreeView(entries);
            final preview = _buildDirectoryPreview(
              section,
              selectedContent,
              gridColumns,
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 240,
                    child: treeView,
                  ),
                  const Divider(height: 32),
                  preview,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: constraints.maxWidth * 0.35,
                  height: 360,
                  child: treeView,
                ),
                const SizedBox(width: 16),
                Expanded(child: preview),
              ],
            );
          },
        ),
      ),
    );
  }

  void _ensureSelectedDirectorySelection(TagSection section) {
    if (section.directories.isEmpty) {
      if (_selectedDirectoryId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() {
            _selectedDirectoryId = null;
          });
        });
      }
      return;
    }

    final hasSelection = section.directories
        .any((content) => content.directory.id == _selectedDirectoryId);
    if (!hasSelection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedDirectoryId = section.directories.first.directory.id;
        });
      });
    }
  }

  Widget _buildDirectoryTreeView(List<_DirectoryEntry> entries) {
    final theme = Theme.of(context);
    return Scrollbar(
      child: ListView.builder(
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final indentation = (entry.depth * 16.0) + 8;

          if (!entry.isSelectable) {
            return ListTile(
              dense: true,
              enabled: false,
              leading: const Icon(Icons.folder, size: 18),
              contentPadding:
                  EdgeInsets.only(left: indentation, right: 8, bottom: 0),
              title: Text(
                entry.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }

          final content = entry.content!;
          final isSelected = content.directory.id == _selectedDirectoryId;

          return ListTile(
            dense: true,
            selected: isSelected,
            leading: Icon(
              isSelected ? Icons.folder_open : Icons.folder_outlined,
              size: 18,
            ),
            contentPadding:
                EdgeInsets.only(left: indentation, right: 8, bottom: 0),
            title: Text(
              content.directory.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            subtitle: Text(_directoryItemCountLabel(content)),
            onTap: () => _onDirectorySelected(content),
          );
        },
      ),
    );
  }

  void _onDirectorySelected(TagDirectoryContent content) {
    setState(() {
      _selectedDirectoryId = content.directory.id;
    });
  }

  String _directoryItemCountLabel(TagDirectoryContent content) {
    final count = content.media.length;
    return '$count item${count == 1 ? '' : 's'}';
  }

  Widget _buildDirectoryPreview(
    TagSection section,
    TagDirectoryContent? selectedContent,
    int gridColumns,
  ) {
    final theme = Theme.of(context);

    if (selectedContent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a directory to preview its media.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      );
    }

    final segments = _buildBreadcrumbSegments(selectedContent);
    final media = selectedContent.media;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumbBar(segments),
        const SizedBox(height: 12),
        Text(
          _directoryItemCountLabel(selectedContent),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (media.isEmpty)
          Text(
            'No media found in this directory for the selected tag.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          _buildMediaGrid(media, media, gridColumns),
        if (section.media.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Other tagged media',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          _buildMediaGrid(section.media, section.media, gridColumns),
        ],
      ],
    );
  }

  List<String> _buildBreadcrumbSegments(TagDirectoryContent content) {
    final segments = _splitPathSegments(content.directory.path);
    if (segments.isEmpty) {
      return [content.directory.name];
    }
    if (segments.last != content.directory.name &&
        content.directory.name.isNotEmpty) {
      segments.add(content.directory.name);
    }
    return segments;
  }

  Widget _buildBreadcrumbBar(List<String> segments) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    for (var i = 0; i < segments.length; i++) {
      if (i == 0) {
        children.add(const Icon(Icons.folder, size: 18));
      } else {
        children.add(const Icon(Icons.chevron_right, size: 16));
      }
      children.add(
        Text(
          segments[i],
          style: i == segments.length - 1
              ? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )
              : theme.textTheme.bodySmall,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: children,
    );
  }

  List<String> _splitPathSegments(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    final segments = parts.where((segment) => segment.isNotEmpty).toList();
    return segments;
  }

  List<_DirectoryEntry> _buildDirectoryEntries(
    List<TagDirectoryContent> directories,
  ) {
    final root = _DirectoryNode();
    for (final content in directories) {
      final segments = _splitPathSegments(content.directory.path);
      if (segments.isEmpty) {
        segments.add(content.directory.name);
      }

      var current = root;
      for (final segment in segments) {
        current = current.children.putIfAbsent(
          segment,
          () => _DirectoryNode(name: segment),
        );
      }
      current.content = content;
    }

    final entries = <_DirectoryEntry>[];
    final sortedRoots = root.children.values.toList()
      ..sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
    for (final node in sortedRoots) {
      _collectDirectoryEntries(node, 0, entries);
    }
    return entries;
  }

  void _collectDirectoryEntries(
    _DirectoryNode node,
    int depth,
    List<_DirectoryEntry> entries,
  ) {
    entries.add(_DirectoryEntry(
      name: node.name!,
      depth: depth,
      content: node.content,
    ));

    final children = node.children.values.toList()
      ..sort((a, b) => a.name!.toLowerCase().compareTo(b.name!.toLowerCase()));
    for (final child in children) {
      _collectDirectoryEntries(child, depth + 1, entries);
    }
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
    int columns,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
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

class _DirectoryNode {
  _DirectoryNode({this.name});

  final String? name;
  final Map<String, _DirectoryNode> children = {};
  TagDirectoryContent? content;
}

class _DirectoryEntry {
  _DirectoryEntry({
    required this.name,
    required this.depth,
    this.content,
  });

  final String name;
  final int depth;
  final TagDirectoryContent? content;

  bool get isSelectable => content != null;
}

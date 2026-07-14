import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/ui_constants.dart';
import '../../../../core/services/file_transfer_result.dart';
import '../../../profiles/presentation/widgets/profile_switcher.dart';
import '../../../../shared/providers/media_mutation_bus.dart';
import '../../../../shared/providers/navigation_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/delete_media_action.dart';
import '../../../../shared/widgets/media_marquee_selector.dart';
import '../../../../shared/widgets/move_copy_media_action.dart';
import '../../domain/entities/saved_filter_entity.dart';
import '../widgets/bulk_tag_assignment_dialog.dart';
import '../widgets/save_filter_dialog.dart';
import '../widgets/saved_filter_chip_strip.dart';

import '../../../favorites/presentation/screens/slideshow_screen.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../../../full_screen/presentation/screens/full_screen_viewer_screen.dart';
import '../../../media_library/domain/entities/directory_tree_node.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/presentation/widgets/media_grid_item.dart';
import '../../../media_library/presentation/widgets/column_selector_popup.dart';
import '../../domain/enums/tag_filter_mode.dart';
import '../../domain/enums/tag_media_type_filter.dart';
import '../view_models/tags_view_model.dart';
import '../widgets/directory_filter_tree.dart';
import '../widgets/tag_directory_chip.dart';
import '../widgets/tag_management_dialog.dart';
import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/utils/directory_tree_builder.dart';

/// What the tag, media-type and directory filters derive from the library.
///
/// Cached across rebuilds so that selecting tiles — which changes none of it —
/// does not pay for it again. See `_TagsScreenState._filterView`.
class _TagsFilterView {
  const _TagsFilterView({
    required this.selectedSections,
    required this.filteredMedia,
    required this.directoryTree,
    required this.selectedDirectories,
  });

  final List<TagSection> selectedSections;
  final List<MediaEntity> filteredMedia;
  final List<DirectoryTreeNode> directoryTree;
  final List<TagDirectoryContent> selectedDirectories;
}

class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  /// Media id to the key on its tile, so the marquee can find it on screen.
  final Map<String, GlobalKey> _mediaItemKeys = <String, GlobalKey>{};

  /// The last derived filter view, and the state it came from. See [_filterView].
  _TagsFilterView? _filterViewCache;
  TagsLoaded? _filterViewFrom;

  /// Holds the keyboard focus for the tab, so the [Shortcuts] above it are on
  /// the path a key event walks up. See [_takeFocusOnTabChange].
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
    _focusNode = FocusNode(debugLabel: 'TagsScreen');
    Future.microtask(() async {
      await ref.read(tagsViewModelProvider.notifier).loadTags();
      await ref.read(favoritesViewModelProvider.notifier).loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Claims the keyboard focus whenever this tab comes to the front.
  ///
  /// The tabs are children of an `IndexedStack`, which hides the ones it is not
  /// showing behind `ExcludeFocus` — so a backgrounded tab cannot hold the focus,
  /// and the tab brought forward is handed nothing. Without this the focus sits
  /// on the enclosing route scope, above this screen's [Shortcuts], and every key
  /// press here is delivered somewhere it means nothing.
  ///
  /// It has to wait for the end of the frame. The listener runs while the tab is
  /// still the hidden one, where `ExcludeFocus` refuses the request outright.
  void _takeFocusOnTabChange() {
    ref.listen<AppTab>(selectedTabProvider, (previous, next) {
      if (next != AppTab.tags) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tagsViewModelProvider);
    final viewModel = ref.read(tagsViewModelProvider.notifier);
    final gridColumns = ref.watch(gridColumnsProvider);

    // Deleting or moving an item from this grid used to leave its tile behind:
    // nothing here ever refreshed. The rows have already been rewritten by the
    // time this fires, so re-reading them is enough — and it sets no loading
    // state, so the screen doesn't flash.
    ref.listen(mediaMutationBusProvider, (_, __) {
      unawaited(ref.read(tagsViewModelProvider.notifier).refreshTags());
    });

    _takeFocusOnTabChange();

    final isSelecting = state is TagsLoaded && state.isSelectionMode;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape):
            const _ClearTagsSelectionIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ClearTagsSelectionIntent: CallbackAction<_ClearTagsSelectionIntent>(
            onInvoke: (_) {
              ref.read(tagsViewModelProvider.notifier).clearMediaSelection();
              return null;
            },
          ),
        },
        child: Focus(
          focusNode: _focusNode,
          child: Scaffold(
            appBar: isSelecting
                ? _buildSelectionAppBar(state, viewModel)
                : AppBar(
                    title: const ProfileSwitcher(fallbackTitle: 'Tags'),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.bookmark_outline),
                        tooltip: 'Saved filters',
                        onPressed: () => _showSavedFilterMenu(state, viewModel),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sell_outlined),
                        tooltip: 'Manage tags',
                        onPressed: _showTagManagement,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Reload tags',
                        onPressed: viewModel.loadTags,
                      ),
                      IconButton(
                        icon: const Icon(Icons.view_module),
                        tooltip: 'Change grid columns',
                        onPressed: () =>
                            _showColumnSelector(context, gridColumns),
                      ),
                    ],
                  ),
            body: switch (state) {
              TagsLoading() => const Center(child: CircularProgressIndicator()),
              TagsLoaded loaded => _buildContent(
                loaded,
                viewModel,
                gridColumns,
              ),
              TagsEmpty() => _buildEmpty(viewModel),
              TagsError(:final message) => _buildError(message, viewModel),
            },
          ),
        ),
      ),
    );
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  /// Everything the filters derive from the library, cached between rebuilds.
  ///
  /// This is the expensive part of the screen — several passes over every media
  /// item, each normalising paths — and **none of it depends on which tiles are
  /// selected**. Recomputing it per frame made marquee-dragging crawl: at 20k
  /// media the directory facet and the directory filter alone cost ~21ms, and
  /// the frame budget is 16.7ms.
  _TagsFilterView _filterView(TagsLoaded state) {
    final cached = _filterViewCache;
    if (cached != null && _sameFilterInputs(_filterViewFrom!, state)) {
      return cached;
    }

    final sections = state.sections;
    final selectedTagIds = state.selectedTagIds;
    final optionalTagIds = state.optionalTagIds;
    final excludedTagIds = state.excludedTagIds;
    final selectedSections = sections
        .where((section) => selectedTagIds.contains(section.id))
        .toList();
    final optionalSections = sections
        .where((section) => optionalTagIds.contains(section.id))
        .toList();
    final hasSelectedTags =
        selectedSections.isNotEmpty || optionalSections.isNotEmpty;

    final aggregatedMedia = _collectMediaFromSections(
      sections,
      selectedSections,
      optionalSections,
      state.filterMode,
      excludedTagIds,
      state.mediaById,
    );
    // The directory facet is built *before* the directory filter is applied.
    // Counting the already-narrowed set instead would collapse every other
    // folder to zero the moment you picked one, leaving no way to widen back.
    final mediaMatchingType = _filterMediaByType(
      aggregatedMedia,
      state.mediaTypeFilter,
    );
    final directoryTree = buildDirectoryTree(
      roots: state.libraryDirectories,
      media: mediaMatchingType,
    );

    final selectedDirectoryPaths = state.selectedDirectoryPaths;
    final filteredMedia = _filterMediaByDirectory(
      mediaMatchingType,
      selectedDirectoryPaths,
    );

    final resolvedSections = _resolveFilterSections(
      sections,
      selectedSections,
      optionalSections,
      hasSelectedTags,
      excludedTagIds.isEmpty,
    );
    final sectionsForDirectories = selectedDirectoryPaths.isEmpty
        ? resolvedSections
        : _filterSectionsByDirectory(
            resolvedSections,
            selectedDirectoryPaths,
            state.mediaById,
          );
    final selectedDirectories = _collectDirectoriesFromSections(
      sectionsForDirectories,
      excludedTagIds,
      state.mediaById,
    );

    // The marquee scans these keys, so they follow the result set — and pruning
    // them is itself O(media), so it belongs behind the cache too.
    _pruneMediaItemKeys(filteredMedia);

    final view = _TagsFilterView(
      selectedSections: selectedSections,
      filteredMedia: filteredMedia,
      directoryTree: directoryTree,
      selectedDirectories: selectedDirectories,
    );
    _filterViewFrom = state;
    _filterViewCache = view;
    return view;
  }

  /// Whether [next] would derive the same filter view as [previous].
  ///
  /// Only the inputs the pipeline actually reads. `selectedMediaIds` and
  /// `isSelectionMode` are deliberately absent: they change on every pointer move
  /// of a marquee drag, and they change nothing here.
  ///
  /// `identical` on the collections is enough because `copyWith` passes the same
  /// references through for fields it does not touch.
  bool _sameFilterInputs(TagsLoaded previous, TagsLoaded next) {
    return identical(previous.sections, next.sections) &&
        identical(previous.mediaById, next.mediaById) &&
        identical(previous.libraryDirectories, next.libraryDirectories) &&
        previous.filterMode == next.filterMode &&
        previous.mediaTypeFilter == next.mediaTypeFilter &&
        setEquals(previous.selectedTagIds, next.selectedTagIds) &&
        setEquals(previous.optionalTagIds, next.optionalTagIds) &&
        setEquals(previous.excludedTagIds, next.excludedTagIds) &&
        setEquals(previous.selectedDirectoryPaths, next.selectedDirectoryPaths);
  }

  Widget _buildContent(
    TagsLoaded state,
    TagsViewModel viewModel,
    int gridColumns,
  ) {
    final view = _filterView(state);

    final sections = state.sections;
    final selectedTagIds = state.selectedTagIds;
    final optionalTagIds = state.optionalTagIds;
    final excludedTagIds = state.excludedTagIds;
    final selectedDirectoryPaths = state.selectedDirectoryPaths;

    final selectedSections = view.selectedSections;
    final filteredMedia = view.filteredMedia;
    final directoryTree = view.directoryTree;
    final selectedDirectories = view.selectedDirectories;

    final savedFilters =
        ref.watch(savedFiltersProvider).valueOrNull ?? const [];

    final headerWidgets = <Widget>[
      if (savedFilters.isNotEmpty) ...[
        SavedFilterChipStrip(
          filters: savedFilters,
          appliedFilterId: state.appliedFilterId,
          onApply: (filter) => _applySavedFilter(viewModel, filter),
          onClear: viewModel.clearSavedFilter,
          onAction: (filter, action) =>
              _handleSavedFilterAction(viewModel, filter, action),
        ),
        const SizedBox(height: 12),
      ],
      _buildSearchField(),
      const SizedBox(height: 12),
      _buildDirectoryFilter(state, viewModel, directoryTree),
      const SizedBox(height: 12),
      _buildTagSelectionChips(state, viewModel, sections),
      const SizedBox(height: 12),
      _buildFilterModeToggle(state, viewModel),
      if (state.filterMode.isHybrid) ...[
        const SizedBox(height: 12),
        _buildSelectionModeToggle(state, viewModel),
      ],
      const SizedBox(height: 12),
      _buildMediaTypeFilter(state, viewModel),
      const SizedBox(height: 24),
    ];

    if (selectedSections.isEmpty &&
        excludedTagIds.isEmpty &&
        selectedDirectoryPaths.isEmpty) {
      headerWidgets.add(_buildSelectionPlaceholder());
    } else {
      headerWidgets.addAll([
        _buildSelectionSummary(
          filteredMedia,
          viewModel,
          state.filterMode,
          selectedTagIds.length,
          optionalTagIds.length,
          excludedTagIds.length,
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
        sliver: SliverList(delegate: SliverChildListDelegate(headerWidgets)),
      ),
    ];

    final hasDirectoryFilter = selectedDirectoryPaths.isNotEmpty;

    if (filteredMedia.isNotEmpty &&
        (selectedSections.isNotEmpty ||
            excludedTagIds.isNotEmpty ||
            hasDirectoryFilter)) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: _buildMediaGrid(
            filteredMedia,
            filteredMedia,
            gridColumns,
            state,
            viewModel,
          ),
        ),
      );
    } else {
      // Nothing to select, so let go of any keys the last result set left behind.
      _pruneMediaItemKeys(const []);
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadTags,
      // The marquee wraps the whole scroll view because the grid is one sliver
      // among the filter cards. It scopes itself to the grid: a drag that starts
      // above the first tile — over the tag chips or the directory tree — is not
      // a rubber-band.
      child: MediaMarqueeSelector(
        itemKeys: _mediaItemKeys,
        selection: state.selectedMediaIds,
        isSelectionMode: state.isSelectionMode,
        onSelectionChanged: (ids) =>
            viewModel.selectMediaRange(ids, append: false),
        onEnableSelectionMode: viewModel.enableMediaSelectionMode,
        onClearSelection: viewModel.clearMediaSelection,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: slivers,
        ),
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

  Widget _buildDirectoryFilter(
    TagsLoaded state,
    TagsViewModel viewModel,
    List<DirectoryTreeNode> directoryTree,
  ) {
    if (directoryTree.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final selected = state.selectedDirectoryPaths;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter by directory', style: theme.textTheme.titleMedium),
                if (selected.isNotEmpty)
                  TextButton(
                    onPressed: viewModel.clearDirectorySelection,
                    child: const Text('Clear directory filter'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            DirectoryFilterTree(
              nodes: directoryTree,
              selectedPaths: selected,
              onToggle: viewModel.toggleDirectorySelection,
            ),
            if (selected.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Select directories to limit results. Expand one to narrow '
                  'down to a sub-directory. Hover to preview their contents.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagSelectionChips(
    TagsLoaded state,
    TagsViewModel viewModel,
    List<TagSection> sections,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredSections = sections.where((section) {
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

    final selectedTagIds = state.selectedTagIds;
    final optionalTagIds = state.optionalTagIds;
    final excludedTagIds = state.excludedTagIds;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: filteredSections.map((section) {
            final isSelected = selectedTagIds.contains(section.id);
            final isOptional = optionalTagIds.contains(section.id);
            final isExcluded = excludedTagIds.contains(section.id);
            final labelText = StringBuffer(section.name)
              ..write(' • ${section.itemCount} ')
              ..write('item${section.itemCount == 1 ? '' : 's'}');
            if (isExcluded) {
              labelText.write(' (excluded)');
            } else if (isOptional) {
              labelText.write(' (optional)');
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
                    ? CircleAvatar(backgroundColor: section.color, radius: 12)
                    : null,
                selected: isSelected || isOptional || isExcluded,
                selectedColor: isExcluded
                    ? Theme.of(
                        context,
                      ).colorScheme.errorContainer.withOpacity(0.9)
                    : isOptional
                    ? Theme.of(
                        context,
                      ).colorScheme.secondaryContainer.withOpacity(0.9)
                    : null,
                checkmarkColor: isExcluded
                    ? Theme.of(context).colorScheme.onErrorContainer
                    : isOptional
                    ? Theme.of(context).colorScheme.onSecondaryContainer
                    : null,
                labelStyle: isExcluded
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      )
                    : isOptional
                    ? TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
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
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Long press (mobile) or right-click (desktop) a tag to exclude it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hybrid mode lets you mix must-include and match-any tags.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
    int optionalTagCount,
    int excludedTagCount,
  ) {
    final theme = Theme.of(context);
    final filterDescription = switch (filterMode) {
      TagFilterMode.hybrid => 'Hybrid match',
      _ when filterMode.matchesAll => 'Matching all selected tags',
      _ => 'Matching any selected tag',
    };
    final requiredDescription = selectedTagCount > 0
        ? 'Must include $selectedTagCount tag${selectedTagCount == 1 ? '' : 's'}'
        : null;
    final optionalDescription = optionalTagCount > 0
        ? 'Match any of $optionalTagCount tag${optionalTagCount == 1 ? '' : 's'}'
        : null;
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
                  if (filterMode.isHybrid &&
                      hasSelection(selectedTagCount, optionalTagCount))
                    filterDescription,
                  if (filterMode.isHybrid && requiredDescription != null)
                    requiredDescription,
                  if (filterMode.isHybrid && optionalDescription != null)
                    optionalDescription,
                  if (!filterMode.isHybrid && selectedTagCount > 0)
                    selectedTagCount <= 1
                        ? filterDescription
                        : '$filterDescription (${selectedTagCount} tags)',
                  if (!filterMode.isHybrid && selectedTagCount == 0)
                    'No tags selected',
                  if (filterMode.isHybrid &&
                      !hasSelection(selectedTagCount, optionalTagCount))
                    'No tags selected',
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

  bool hasSelection(int selectedCount, int optionalCount) {
    return selectedCount + optionalCount > 0;
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
        case TagMediaTypeFilter.audio:
          return item.type == MediaType.audio;
        case TagMediaTypeFilter.all:
          return item.type == MediaType.image ||
              item.type == MediaType.video ||
              item.type == MediaType.audio;
      }
    }).toList();
  }

  List<TagSection> _resolveFilterSections(
    List<TagSection> allSections,
    List<TagSection> requiredSections,
    List<TagSection> optionalSections,
    bool hasSelectedTags,
    bool excludedIsEmpty,
  ) {
    if (hasSelectedTags) {
      return _mergeSections(requiredSections, optionalSections);
    }
    if (excludedIsEmpty) {
      return allSections;
    }
    return allSections;
  }

  List<TagSection> _mergeSections(
    List<TagSection> requiredSections,
    List<TagSection> optionalSections,
  ) {
    final map = <String, TagSection>{
      for (final section in requiredSections) section.id: section,
    };
    for (final section in optionalSections) {
      map.putIfAbsent(section.id, () => section);
    }
    return map.values.toList();
  }

  List<TagSection> _filterSectionsByDirectory(
    List<TagSection> sections,
    Set<String> selectedDirectoryPaths,
    Map<String, MediaEntity> mediaById,
  ) {
    if (selectedDirectoryPaths.isEmpty) {
      return sections;
    }

    bool isInSelectedDirectory(String mediaId) {
      final media = mediaById[mediaId];
      return media != null &&
          _isInSelectedDirectory(media, selectedDirectoryPaths);
    }

    final filtered = <TagSection>[];

    for (final section in sections) {
      final filteredDirectories = section.directories
          .map(
            (content) => TagDirectoryContent(
              directory: content.directory,
              mediaIds: content.mediaIds
                  .where(isInSelectedDirectory)
                  .toList(growable: false),
            ),
          )
          .where((content) => content.mediaIds.isNotEmpty)
          .toList();

      final filteredMedia = section.mediaIds
          .where(isInSelectedDirectory)
          .toList();

      if (filteredDirectories.isEmpty && filteredMedia.isEmpty) {
        continue;
      }

      filtered.add(
        TagSection(
          id: section.id,
          name: section.name,
          isFavorites: section.isFavorites,
          directories: filteredDirectories,
          mediaIds: filteredMedia,
          itemCount:
              filteredMedia.length +
              filteredDirectories.fold<int>(
                0,
                (sum, entry) => sum + entry.mediaIds.length,
              ),
          color: section.color,
        ),
      );
    }

    return filtered;
  }

  List<MediaEntity> _filterMediaByDirectory(
    List<MediaEntity> media,
    Set<String> selectedDirectoryPaths,
  ) {
    if (selectedDirectoryPaths.isEmpty) {
      return media;
    }

    return media
        .where((item) => _isInSelectedDirectory(item, selectedDirectoryPaths))
        .toList();
  }

  /// A media item matches when the directory it sits *directly* in is selected.
  ///
  /// Selecting a folder cascades over its subtree in the view model, so this
  /// stays a single set lookup rather than an ancestor walk per item.
  bool _isInSelectedDirectory(
    MediaEntity media,
    Set<String> selectedDirectoryPaths,
  ) {
    return selectedDirectoryPaths.contains(p.dirname(p.normalize(media.path)));
  }

  List<MediaEntity> _collectMediaFromSections(
    List<TagSection> allSections,
    List<TagSection> requiredSections,
    List<TagSection> optionalSections,
    TagFilterMode filterMode,
    Set<String> excludedTagIds,
    Map<String, MediaEntity> mediaById,
  ) {
    if (allSections.isEmpty) {
      return const <MediaEntity>[];
    }

    final excludedSet = excludedTagIds;
    final requiredIds = {for (final section in requiredSections) section.id};
    final optionalIds = {for (final section in optionalSections) section.id};
    final hasRequired = requiredSections.isNotEmpty;
    final hasOptional = optionalSections.isNotEmpty;

    final sectionsToScan = filterMode.isHybrid
        ? _resolveFilterSections(
            allSections,
            requiredSections,
            optionalSections,
            hasRequired || hasOptional,
            excludedTagIds.isEmpty,
          )
        : (hasRequired ? requiredSections : allSections);

    if (sectionsToScan.isEmpty) {
      return const <MediaEntity>[];
    }

    final matchedMediaById = <String, MediaEntity>{};
    final requiredCount = <String, int>{};
    final optionalCount = <String, int>{};

    for (final section in sectionsToScan) {
      final seenInSection = <String>{};
      for (final mediaId in section.allMediaIds) {
        final media = mediaById[mediaId];
        if (media == null) {
          continue;
        }
        if (excludedSet.isNotEmpty && media.tagIds.any(excludedSet.contains)) {
          continue;
        }
        matchedMediaById[media.id] = media;
        if (seenInSection.add(media.id)) {
          if (requiredIds.contains(section.id)) {
            requiredCount.update(
              media.id,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
          if (optionalIds.contains(section.id)) {
            optionalCount.update(
              media.id,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
        }
      }
    }

    if (!filterMode.isHybrid) {
      final requireAll = hasRequired && filterMode.matchesAll;
      if (!requireAll) {
        return matchedMediaById.values.toList();
      }

      final requiredMatches = requiredSections.length;
      return requiredCount.entries
          .where((entry) => entry.value == requiredMatches)
          .map((entry) => matchedMediaById[entry.key]!)
          .toList();
    }

    return matchedMediaById.values.where((media) {
      final mediaId = media.id;
      if (hasRequired) {
        if ((requiredCount[mediaId] ?? 0) != requiredSections.length) {
          return false;
        }
      }
      if (hasOptional) {
        if ((optionalCount[mediaId] ?? 0) == 0) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<TagDirectoryContent> _collectDirectoriesFromSections(
    List<TagSection> sections,
    Set<String> excludedTagIds,
    Map<String, MediaEntity> mediaById,
  ) {
    if (sections.isEmpty) {
      return const <TagDirectoryContent>[];
    }

    final excludedSet = excludedTagIds;
    final map = <String, TagDirectoryContent>{};
    for (final section in sections) {
      for (final directoryContent in section.directories) {
        if (excludedSet.isNotEmpty &&
            directoryContent.directory.tagIds.any(excludedSet.contains)) {
          continue;
        }
        final filteredMediaIds = directoryContent.mediaIds
            .where((mediaId) {
              final media = mediaById[mediaId];
              if (media == null) {
                return false;
              }
              if (excludedSet.isEmpty) {
                return true;
              }
              return !media.tagIds.any(excludedSet.contains);
            })
            .toList(growable: false);
        if (filteredMediaIds.isEmpty) {
          continue;
        }
        map.update(
          directoryContent.directory.id,
          (existing) {
            final merged = <String>{...existing.mediaIds, ...filteredMediaIds};
            return TagDirectoryContent(
              directory: directoryContent.directory,
              mediaIds: merged.toList(growable: false),
            );
          },
          ifAbsent: () => TagDirectoryContent(
            directory: directoryContent.directory,
            mediaIds: filteredMediaIds,
          ),
        );
      }
    }

    final directories = map.values.toList()
      ..sort((a, b) => a.directory.name.compareTo(b.directory.name));
    return directories;
  }

  Widget _buildFilterModeToggle(TagsLoaded state, TagsViewModel viewModel) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tag matching',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: TagFilterMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(mode.label),
                  selected: state.filterMode == mode,
                  onSelected: (_) => viewModel.setFilterMode(mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              state.filterMode.helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionModeToggle(TagsLoaded state, TagsViewModel viewModel) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selection mode',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: TagSelectionMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(mode.label),
                  selected: state.selectionMode == mode,
                  onSelected: (_) => viewModel.setSelectionMode(mode),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              state.selectionMode.helperText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTypeFilter(TagsLoaded state, TagsViewModel viewModel) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Media type', style: Theme.of(context).textTheme.titleMedium),
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
                      mediaCount: content.mediaIds.length,
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
    TagsLoaded state,
    TagsViewModel viewModel,
  ) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final mediaItem = media[index];
        return _buildMediaTile(mediaItem, collection, state, viewModel);
      }, childCount: media.length),
    );
  }

  /// Drops keys for media the filters no longer show, so the map the marquee
  /// scans does not grow without bound.
  void _pruneMediaItemKeys(Iterable<MediaEntity> media) {
    final visibleIds = media.map((item) => item.id).toSet();
    _mediaItemKeys.removeWhere((id, _) => !visibleIds.contains(id));
  }

  /// The app bar shown while media is selected, mirroring the Library grid's.
  AppBar _buildSelectionAppBar(TagsLoaded state, TagsViewModel viewModel) {
    final theme = Theme.of(context);
    final count = state.selectedMediaIds.length;
    final selection = viewModel.selectedMedia();

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Clear selection',
        onPressed: viewModel.clearMediaSelection,
      ),
      title: Text('$count selected', style: theme.textTheme.titleLarge),
      actions: [
        TextButton.icon(
          onPressed: count == 0
              ? null
              : () => unawaited(_assignTagsToSelection(viewModel)),
          icon: const Icon(Icons.tag),
          label: const Text('Assign Tags'),
        ),
        TextButton.icon(
          onPressed: count == 0
              ? null
              : () => unawaited(_toggleFavoritesForSelection(selection)),
          icon: const Icon(Icons.favorite),
          label: const Text('Favorite'),
        ),
        if (Platform.isMacOS) ...[
          MenuAnchor(
            menuChildren: [
              MenuItemButton(
                onPressed: () =>
                    unawaited(_transferSelection(selection, TransferMode.move)),
                child: const Text('Move to…'),
              ),
              MenuItemButton(
                onPressed: () =>
                    unawaited(_transferSelection(selection, TransferMode.copy)),
                child: const Text('Copy to…'),
              ),
            ],
            builder: (context, controller, _) => TextButton.icon(
              onPressed: count == 0
                  ? null
                  : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
              icon: const Icon(Icons.drive_file_move_outline),
              label: const Text('Move'),
            ),
          ),
          TextButton.icon(
            onPressed: count == 0
                ? null
                : () => unawaited(_deleteSelection(selection)),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(width: 8),
      ],
    );
  }

  Future<void> _assignTagsToSelection(TagsViewModel viewModel) async {
    final count = viewModel.selectedMedia().length;

    final applied = await BulkTagAssignmentDialog.show(
      context,
      title: 'Assign Tags ($count selected)',
      description:
          'Choose the tags that should be applied to every selected media item. '
          'Existing tags will be replaced.',
      initialTagIds: viewModel.commonTagIdsForSelection(),
      onTagsAssigned: viewModel.applyTagsToSelection,
    );

    if (!mounted || !applied) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updated tags for $count media items')),
    );
  }

  Future<void> _toggleFavoritesForSelection(List<MediaEntity> selection) async {
    if (selection.isEmpty) {
      return;
    }

    await ref
        .read(favoritesViewModelProvider.notifier)
        .toggleFavoritesForMedia(selection);

    if (!mounted) {
      return;
    }
    await ref.read(tagsViewModelProvider.notifier).refreshFavorites();
  }

  Future<void> _transferSelection(
    List<MediaEntity> selection,
    TransferMode mode,
  ) async {
    if (selection.isEmpty) {
      return;
    }

    // The mutation bus listener in build() rebuilds the sections afterwards, so
    // the moved items leave the grid on their own.
    await pickDestinationAndTransferMediaBatch(context, selection, mode: mode);
  }

  Future<void> _deleteSelection(List<MediaEntity> selection) async {
    if (selection.isEmpty) {
      return;
    }

    await confirmAndDeleteMediaBatch(context, selection);

    if (!mounted) {
      return;
    }
    // Whatever survived is no longer selected — the reload prunes the ids, but
    // leaving selection mode on with nothing in it would strand the app bar.
    ref.read(tagsViewModelProvider.notifier).clearMediaSelection();
  }

  // ---------------------------------------------------------------------------
  // Saved filters
  // ---------------------------------------------------------------------------

  /// The bookmark menu: save the current query, or update the one applied.
  Future<void> _showSavedFilterMenu(
    TagsState state,
    TagsViewModel viewModel,
  ) async {
    final applied = _appliedFilter(state);
    final isModified = viewModel.isAppliedFilterModified;

    final action = await showMenu<String>(
      context: context,
      position: UiPosition.contextMenu,
      items: [
        const PopupMenuItem(value: 'save', child: Text('Save current filter…')),
        if (applied != null && isModified)
          PopupMenuItem(
            value: 'update',
            child: Text('Update "${applied.name}"'),
          ),
      ],
    );

    if (action == null || !mounted) {
      return;
    }

    if (action == 'save') {
      await _saveCurrentFilter(viewModel);
    } else {
      await _updateFilterFromCurrent(viewModel, applied!);
    }
  }

  SavedFilterEntity? _appliedFilter(TagsState state) {
    if (state is! TagsLoaded || state.appliedFilterId == null) {
      return null;
    }
    final filters = ref.read(savedFiltersProvider).valueOrNull ?? const [];
    return filters
        .where((filter) => filter.id == state.appliedFilterId)
        .firstOrNull;
  }

  Future<void> _saveCurrentFilter(TagsViewModel viewModel) async {
    final definition = viewModel.currentFilter();

    // A filter that selects nothing is the unfiltered view with a name on it.
    if (definition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select at least one tag or directory before saving a filter',
          ),
        ),
      );
      return;
    }

    final saved = await SaveFilterDialog.show(context, definition: definition);
    if (saved == null || !mounted) {
      return;
    }

    // The filter we just saved becomes the applied one, and is not "modified".
    viewModel.setAppliedFilter(saved.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved filter "${saved.name}"')));
  }

  /// Overwrites [filter]'s query with whatever the tab is showing now.
  Future<void> _updateFilterFromCurrent(
    TagsViewModel viewModel,
    SavedFilterEntity filter,
  ) async {
    final definition = viewModel.currentFilter();
    if (definition.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one tag or directory first'),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(saveFilterUseCaseProvider)(
        name: filter.name,
        definition: definition,
        existingId: filter.id,
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to update filter: $error'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    ref.invalidate(savedFiltersProvider);
    // Re-baseline: the applied filter now matches what is on screen.
    viewModel.setAppliedFilter(filter.id);
    messenger.showSnackBar(SnackBar(content: Text('Updated "${filter.name}"')));
  }

  void _applySavedFilter(TagsViewModel viewModel, SavedFilterEntity filter) {
    final result = viewModel.applySavedFilter(filter);

    if (result.isIntact) {
      return;
    }

    // A saved filter outlives the things it names. Say what was dropped rather
    // than quietly showing the wrong results.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.describeDropped()} in "${filter.name}" no longer exist '
          'and were skipped',
        ),
      ),
    );
  }

  Future<void> _handleSavedFilterAction(
    TagsViewModel viewModel,
    SavedFilterEntity filter,
    SavedFilterAction action,
  ) async {
    switch (action) {
      case SavedFilterAction.update:
        await _updateFilterFromCurrent(viewModel, filter);
      case SavedFilterAction.rename:
        final renamed = await SaveFilterDialog.show(
          context,
          definition: filter.definition,
          existing: filter,
        );
        if (renamed != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Renamed to "${renamed.name}"')),
          );
        }
      case SavedFilterAction.delete:
        await _deleteSavedFilter(viewModel, filter);
    }
  }

  Future<void> _deleteSavedFilter(
    TagsViewModel viewModel,
    SavedFilterEntity filter,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete filter',
      content:
          'Delete "${filter.name}"? The tags and media it selects are not '
          'affected — only the saved query is removed.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await ref.read(deleteSavedFilterUseCaseProvider)(filter.id);
    ref.invalidate(savedFiltersProvider);

    if (!mounted) {
      return;
    }
    // The applied filter is gone; the query stays on screen, it is just no
    // longer "a saved filter".
    if (viewModel.appliedFilterId == filter.id) {
      viewModel.setAppliedFilter(null);
    }
  }

  /// Opens the manage-tags dialog, then reloads so a rename or recolour is
  /// reflected in the chips and the sections re-sort by the new name.
  Future<void> _showTagManagement() async {
    await TagManagementDialog.show(context);
    if (!mounted) {
      return;
    }
    await ref.read(tagsViewModelProvider.notifier).refreshTags();
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

  Widget _buildMediaTile(
    MediaEntity media,
    List<MediaEntity> collection,
    TagsLoaded state,
    TagsViewModel viewModel,
  ) {
    final isSelected = state.selectedMediaIds.contains(media.id);

    return MediaGridItem(
      key: _mediaItemKeys.putIfAbsent(media.id, GlobalKey.new),
      media: media,
      // While selecting, a tap picks the item rather than opening it — the same
      // bargain the Library grid makes.
      onTap: state.isSelectionMode
          ? () => viewModel.toggleMediaSelection(media.id)
          : () => _openFullScreen(collection, media),
      onFavoriteToggle: (_) => viewModel.refreshFavorites(),
      onSelectionToggle: () => viewModel.toggleMediaSelection(media.id),
      isSelected: isSelected,
      isSelectionMode: state.isSelectionMode,
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
          initialMediaId: directoryContent.mediaIds.isNotEmpty
              ? directoryContent.mediaIds.first
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

/// Escape: leave selection mode, matching the Library tab's grids.
class _ClearTagsSelectionIntent extends Intent {
  const _ClearTagsSelectionIntent();
}

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/logging_service.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../../media_library/data/models/media_model.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../tagging/domain/entities/saved_filter_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/enums/tag_filter_mode.dart';
import '../../../tagging/domain/enums/tag_media_type_filter.dart';
import '../../../tagging/domain/use_cases/assign_tag_use_case.dart';
import '../../../tagging/domain/use_cases/filter_by_tags_use_case.dart';
import '../../../tagging/domain/use_cases/get_tags_use_case.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/utils/directory_tree_builder.dart';

@immutable
class TagDirectoryContent {
  const TagDirectoryContent({required this.directory, required this.mediaIds});

  final DirectoryEntity directory;
  final List<String> mediaIds;

  int get itemCount => mediaIds.length;
}

@immutable
class TagSection {
  const TagSection({
    required this.id,
    required this.name,
    required this.isFavorites,
    required this.directories,
    required this.mediaIds,
    required this.itemCount,
    this.color,
  });

  final String id;
  final String name;
  final bool isFavorites;
  final List<TagDirectoryContent> directories;
  final List<String> mediaIds;
  final int itemCount;
  final Color? color;

  Iterable<String> get allMediaIds sync* {
    yield* mediaIds;
    for (final directory in directories) {
      yield* directory.mediaIds;
    }
  }
}

/// What was lost when a saved filter was applied.
///
/// A saved filter outlives the things it names: tags get deleted, library roots
/// get removed. Rather than apply it blind and show the wrong results, the view
/// model prunes and reports, so the screen can say so.
@immutable
class SavedFilterApplied {
  const SavedFilterApplied({
    this.droppedTagCount = 0,
    this.droppedDirectoryCount = 0,
  });

  final int droppedTagCount;
  final int droppedDirectoryCount;

  bool get isIntact => droppedTagCount == 0 && droppedDirectoryCount == 0;

  /// "2 tags and 1 folder", dropping whichever half is zero. Empty when intact.
  String describeDropped() {
    final parts = <String>[
      if (droppedTagCount > 0)
        '$droppedTagCount tag${droppedTagCount == 1 ? '' : 's'}',
      if (droppedDirectoryCount > 0)
        '$droppedDirectoryCount folder${droppedDirectoryCount == 1 ? '' : 's'}',
    ];
    return parts.join(' and ');
  }
}

sealed class TagsState {
  const TagsState();
}

enum TagSelectionMode { required, optional, excluded }

extension TagSelectionModeX on TagSelectionMode {
  String get label => switch (this) {
    TagSelectionMode.required => 'Must include',
    TagSelectionMode.optional => 'Match any',
    TagSelectionMode.excluded => 'Exclude',
  };

  String get helperText => switch (this) {
    TagSelectionMode.required => 'Media must include every required tag.',
    TagSelectionMode.optional =>
      'Media must include at least one optional tag.',
    TagSelectionMode.excluded => 'Media must not include excluded tags.',
  };
}

class TagsLoading extends TagsState {
  const TagsLoading();
}

class TagsLoaded extends TagsState {
  const TagsLoaded({
    required this.sections,
    required this.selectedTagIds,
    required this.optionalTagIds,
    required this.excludedTagIds,
    required this.filterMode,
    required this.mediaTypeFilter,
    required this.selectionMode,
    required this.libraryDirectories,
    required this.selectedDirectoryPaths,
    required this.mediaById,
    this.selectedMediaIds = const <String>{},
    this.isSelectionMode = false,
    this.appliedFilterId,
  });

  final List<TagSection> sections;
  final Set<String> selectedTagIds;
  final Set<String> optionalTagIds;
  final Set<String> excludedTagIds;
  final TagFilterMode filterMode;
  final TagMediaTypeFilter mediaTypeFilter;
  final TagSelectionMode selectionMode;
  final List<DirectoryEntity> libraryDirectories;

  /// Normalized paths of the directories whose direct media is included.
  ///
  /// Empty means no directory filtering at all. Holds paths at any depth, so a
  /// media item matches when this contains `p.dirname(media.path)`.
  final Set<String> selectedDirectoryPaths;

  final Map<String, MediaEntity> mediaById;

  /// Media picked out of the grid for a bulk action.
  ///
  /// Unlike the Library grid, whose selection lives in a `MediaViewModel` keyed
  /// on one directory, this selection spans every directory the tag filter
  /// matched.
  final Set<String> selectedMediaIds;

  /// Whether the grid is showing its checkboxes. Kept separate from
  /// [selectedMediaIds] so an empty selection can still be "in selection mode",
  /// which is what lets a drag start from nothing.
  final bool isSelectionMode;

  /// The saved filter currently applied, if any — which chip reads as selected.
  final String? appliedFilterId;

  List<String> get orderedSelectedTagIds {
    return _orderedTagIds(selectedTagIds);
  }

  List<String> get orderedOptionalTagIds {
    return _orderedTagIds(optionalTagIds);
  }

  List<String> get orderedExcludedTagIds {
    return _orderedTagIds(excludedTagIds);
  }

  List<String> _orderedTagIds(Set<String> ids) {
    final orderedBySection = sections
        .where((section) => ids.contains(section.id))
        .map((section) => section.id)
        .toList(growable: false);
    if (orderedBySection.length == ids.length) {
      return orderedBySection;
    }

    final missing = ids.difference(orderedBySection.toSet()).toList()..sort();
    return <String>[...orderedBySection, ...missing];
  }

  TagsLoaded copyWith({
    List<TagSection>? sections,
    Set<String>? selectedTagIds,
    Set<String>? optionalTagIds,
    Set<String>? excludedTagIds,
    TagFilterMode? filterMode,
    TagMediaTypeFilter? mediaTypeFilter,
    TagSelectionMode? selectionMode,
    List<DirectoryEntity>? libraryDirectories,
    Set<String>? selectedDirectoryPaths,
    Map<String, MediaEntity>? mediaById,
    Set<String>? selectedMediaIds,
    bool? isSelectionMode,
    String? appliedFilterId,
    // `?? this.x` cannot express "set this back to null", and un-applying a
    // filter is exactly that.
    bool clearAppliedFilter = false,
  }) {
    return TagsLoaded(
      sections: sections ?? this.sections,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      optionalTagIds: optionalTagIds ?? this.optionalTagIds,
      excludedTagIds: excludedTagIds ?? this.excludedTagIds,
      filterMode: filterMode ?? this.filterMode,
      mediaTypeFilter: mediaTypeFilter ?? this.mediaTypeFilter,
      selectionMode: selectionMode ?? this.selectionMode,
      libraryDirectories: libraryDirectories ?? this.libraryDirectories,
      selectedDirectoryPaths:
          selectedDirectoryPaths ?? this.selectedDirectoryPaths,
      mediaById: mediaById ?? this.mediaById,
      selectedMediaIds: selectedMediaIds ?? this.selectedMediaIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      appliedFilterId: clearAppliedFilter
          ? null
          : (appliedFilterId ?? this.appliedFilterId),
    );
  }
}

class TagsEmpty extends TagsState {
  const TagsEmpty();
}

class TagsError extends TagsState {
  const TagsError(this.message);

  final String message;
}

class TagsViewModel extends StateNotifier<TagsState> {
  TagsViewModel(
    this._getTagsUseCase,
    this._filterByTagsUseCase,
    this._favoritesRepository,
    this._mediaDataSource,
    this._directoryRepository,
    this._assignTagUseCase,
  ) : super(const TagsLoading());

  final GetTagsUseCase _getTagsUseCase;
  final FilterByTagsUseCase _filterByTagsUseCase;
  final FavoritesRepository _favoritesRepository;
  final IsarMediaDataSource _mediaDataSource;
  final DirectoryRepository _directoryRepository;
  final AssignTagUseCase _assignTagUseCase;
  Set<String> _selectedTagIds = <String>{};
  Set<String> _optionalTagIds = <String>{};
  Set<String> _excludedTagIds = <String>{};
  Set<String> _selectedDirectoryPaths = <String>{};
  Set<String> _selectedMediaIds = <String>{};
  bool _isMediaSelectionMode = false;
  String? _appliedFilterId;

  /// The applied filter as it landed *after pruning* — the baseline the dirty
  /// check compares against.
  SavedFilterDefinition? _appliedFilterDefinition;
  TagFilterMode _filterMode = TagFilterMode.any;
  TagMediaTypeFilter _mediaTypeFilter = TagMediaTypeFilter.all;
  TagSelectionMode _selectionMode = TagSelectionMode.required;
  List<DirectoryEntity> _libraryDirectories = const [];
  Map<String, String> _rootIdByNormalizedPath = const {};

  /// Every directory path the library knows about, derived from *all* cached
  /// media rather than the filtered subset, so that checking a folder includes
  /// its whole subtree even where the current tag filter hides part of it.
  Set<String> _knownDirectoryPaths = const <String>{};

  Future<void> loadTags() async {
    state = const TagsLoading();
    await _reloadSections();
  }

  Future<void> refreshTags() async {
    await _reloadSections();
  }

  Future<void> refreshFavorites() async {
    try {
      final favoritesSection = await _buildFavoritesSection();
      if (!mounted) {
        return;
      }

      final currentState = state;
      if (currentState is TagsLoaded) {
        final otherSections = currentState.sections
            .where((section) => !section.isFavorites)
            .toList();

        if (favoritesSection != null) {
          final updatedSections = [favoritesSection, ...otherSections];
          state = TagsLoaded(
            sections: updatedSections,
            selectedTagIds: _syncSelectionWithSections(updatedSections),
            optionalTagIds: _syncOptionalWithSections(updatedSections),
            excludedTagIds: _syncExclusionsWithSections(updatedSections),
            filterMode: _filterMode,
            mediaTypeFilter: _mediaTypeFilter,
            selectionMode: _selectionMode,
            libraryDirectories: _libraryDirectories,
            selectedDirectoryPaths: Set<String>.unmodifiable(
              _selectedDirectoryPaths,
            ),
            mediaById: currentState.mediaById,
            selectedMediaIds: Set<String>.unmodifiable(_selectedMediaIds),
            isSelectionMode: _isMediaSelectionMode,
          );
        } else if (otherSections.isEmpty) {
          _selectedTagIds = <String>{};
          _optionalTagIds = <String>{};
          _excludedTagIds = <String>{};
          state = const TagsEmpty();
        } else {
          state = TagsLoaded(
            sections: otherSections,
            selectedTagIds: _syncSelectionWithSections(otherSections),
            optionalTagIds: _syncOptionalWithSections(otherSections),
            excludedTagIds: _syncExclusionsWithSections(otherSections),
            filterMode: _filterMode,
            mediaTypeFilter: _mediaTypeFilter,
            selectionMode: _selectionMode,
            libraryDirectories: _libraryDirectories,
            selectedDirectoryPaths: Set<String>.unmodifiable(
              _selectedDirectoryPaths,
            ),
            mediaById: currentState.mediaById,
            selectedMediaIds: Set<String>.unmodifiable(_selectedMediaIds),
            isSelectionMode: _isMediaSelectionMode,
          );
        }
      } else {
        await _reloadSections();
      }
    } catch (e) {
      LoggingService.instance.error('Failed to refresh favorites: $e');
    }
  }

  Future<void> _reloadSections() async {
    try {
      final sections = <TagSection>[];

      await _directoryRepository.refreshChangedLibraryRoots();

      final allDirectories =
          await _filterByTagsUseCase.filterDirectories(const []);
      _libraryDirectories = _extractTopLevelDirectories(allDirectories);
      _rootIdByNormalizedPath = <String, String>{
        for (final directory in _libraryDirectories)
          p.normalize(directory.path): directory.id,
      };

      final cachedMediaModels = await _mediaDataSource.getMedia();
      final mediaCount = cachedMediaModels.length;
      final cachedMediaEntities = List<MediaEntity>.generate(
        mediaCount,
        (index) => _toEntity(cachedMediaModels[index]),
        growable: false,
      );

      final cachedMediaById = <String, MediaEntity>{};
      final mediaOrderById = <String, int>{};
      final mediaIdsByTagId = <String, Set<String>>{};
      final mediaIdsByTopDirectoryId = <String, Set<String>>{};

      for (var index = 0; index < mediaCount; index += 1) {
        final media = cachedMediaEntities[index];
        cachedMediaById[media.id] = media;
        mediaOrderById[media.id] = index;

        for (final tagId in media.tagIds) {
          mediaIdsByTagId.putIfAbsent(tagId, () => <String>{}).add(media.id);
        }

        final topDirectoryId = _findTopDirectoryIdForPath(media.path);
        if (topDirectoryId != null) {
          mediaIdsByTopDirectoryId
              .putIfAbsent(topDirectoryId, () => <String>{})
              .add(media.id);
        }
      }

      _knownDirectoryPaths = collectDirectoryPaths(
        roots: _libraryDirectories,
        media: cachedMediaEntities,
      );

      final favoritesSection = await _buildFavoritesSection(
        cachedMediaById: cachedMediaById,
      );
      if (favoritesSection != null) {
        sections.add(favoritesSection);
      }

      final untaggedSection = await _buildUntaggedSection(
        cachedMediaEntities,
        mediaIdsByTopDirectoryId,
        mediaOrderById,
      );
      if (untaggedSection != null) {
        sections.add(untaggedSection);
      }

      final tags = await _getTagsUseCase()
        ..sort((a, b) => a.name.compareTo(b.name));
      for (final tag in tags) {
        final section = _buildSectionForTag(
          tag,
          mediaOrderById,
          mediaIdsByTagId,
          mediaIdsByTopDirectoryId,
        );
        sections.add(section);
      }

      if (!mounted) {
        return;
      }

      _selectedDirectoryPaths = _selectedDirectoryPaths.intersection(
        _knownDirectoryPaths,
      );
      _pruneMediaSelection(cachedMediaById.keys.toSet());

      if (sections.isEmpty) {
        _selectedTagIds = <String>{};
        _optionalTagIds = <String>{};
        _excludedTagIds = <String>{};
        state = const TagsEmpty();
      } else {
        state = TagsLoaded(
          sections: sections,
          selectedTagIds: _syncSelectionWithSections(sections),
          optionalTagIds: _syncOptionalWithSections(sections),
          excludedTagIds: _syncExclusionsWithSections(sections),
          filterMode: _filterMode,
          mediaTypeFilter: _mediaTypeFilter,
          selectionMode: _selectionMode,
          libraryDirectories: _libraryDirectories,
          selectedDirectoryPaths: Set<String>.unmodifiable(
            _selectedDirectoryPaths,
          ),
          mediaById: cachedMediaById,
          selectedMediaIds: Set<String>.unmodifiable(_selectedMediaIds),
          isSelectionMode: _isMediaSelectionMode,
        );
      }
    } catch (e) {
      LoggingService.instance.error('Failed to load tags: $e');
      if (!mounted) {
        return;
      }
      state = TagsError(e.toString());
    }
  }

  void setTagSelected(String tagId, bool isSelected) {
    final selectionMode = _filterMode.isHybrid
        ? _selectionMode
        : TagSelectionMode.required;
    switch (selectionMode) {
      case TagSelectionMode.required:
        _updateRequired(tagId, isSelected);
      case TagSelectionMode.optional:
        _updateOptional(tagId, isSelected);
      case TagSelectionMode.excluded:
        setTagExcluded(tagId, isSelected);
    }
  }

  void setSelectionMode(TagSelectionMode mode) {
    if (_selectionMode == mode) {
      return;
    }

    _selectionMode = mode;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(selectionMode: _selectionMode);
    }
  }

  void _updateRequired(String tagId, bool isSelected) {
    final updatedSelection = <String>{..._selectedTagIds};
    if (isSelected) {
      updatedSelection.add(tagId);
      _optionalTagIds.remove(tagId);
      _excludedTagIds.remove(tagId);
    } else {
      updatedSelection.remove(tagId);
    }
    _updateSelection(updatedSelection);
  }

  void _updateOptional(String tagId, bool isSelected) {
    final updatedOptional = <String>{..._optionalTagIds};
    if (isSelected) {
      updatedOptional.add(tagId);
      _selectedTagIds.remove(tagId);
      _excludedTagIds.remove(tagId);
    } else {
      updatedOptional.remove(tagId);
    }
    _updateOptionalSelection(updatedOptional);
  }

  void setTagExcluded(String tagId, bool isExcluded) {
    final updatedExclusions = <String>{..._excludedTagIds};
    if (isExcluded) {
      updatedExclusions.add(tagId);
      _selectedTagIds.remove(tagId);
      _optionalTagIds.remove(tagId);
    } else {
      updatedExclusions.remove(tagId);
    }
    _updateExclusions(updatedExclusions);
  }

  void clearSelection() {
    _updateSelection(<String>{});
    _updateOptionalSelection(<String>{});
    _updateExclusions(<String>{});
  }

  Set<String> _syncSelectionWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _selectedTagIds = _selectedTagIds.intersection(availableIds);
    return Set<String>.unmodifiable(_selectedTagIds);
  }

  Set<String> _syncOptionalWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _optionalTagIds = _optionalTagIds
        .intersection(availableIds)
        .difference(_selectedTagIds);
    return Set<String>.unmodifiable(_optionalTagIds);
  }

  Set<String> _syncExclusionsWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _excludedTagIds = _excludedTagIds
        .intersection(availableIds)
        .difference(_selectedTagIds)
        .difference(_optionalTagIds);
    return Set<String>.unmodifiable(_excludedTagIds);
  }

  void _updateSelection(Set<String> newSelection) {
    if (setEquals(_selectedTagIds, newSelection)) {
      return;
    }
    _selectedTagIds = newSelection;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedTagIds: Set<String>.unmodifiable(_selectedTagIds),
        excludedTagIds: Set<String>.unmodifiable(_excludedTagIds),
        optionalTagIds: Set<String>.unmodifiable(_optionalTagIds),
      );
    }
  }

  void _updateOptionalSelection(Set<String> newOptional) {
    if (setEquals(_optionalTagIds, newOptional)) {
      return;
    }
    _optionalTagIds = newOptional;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        optionalTagIds: Set<String>.unmodifiable(_optionalTagIds),
        selectedTagIds: Set<String>.unmodifiable(_selectedTagIds),
        excludedTagIds: Set<String>.unmodifiable(_excludedTagIds),
      );
    }
  }

  void _updateExclusions(Set<String> newExclusions) {
    if (setEquals(_excludedTagIds, newExclusions)) {
      return;
    }
    _excludedTagIds = newExclusions;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        excludedTagIds: Set<String>.unmodifiable(_excludedTagIds),
        selectedTagIds: Set<String>.unmodifiable(_selectedTagIds),
        optionalTagIds: Set<String>.unmodifiable(_optionalTagIds),
      );
    }
  }

  void setFilterMode(TagFilterMode mode) {
    if (_filterMode == mode) {
      return;
    }

    _filterMode = mode;
    if (!_filterMode.isHybrid && _optionalTagIds.isNotEmpty) {
      _selectedTagIds = <String>{..._selectedTagIds, ..._optionalTagIds};
      _optionalTagIds = <String>{};
    }
    if (!_filterMode.isHybrid) {
      _selectionMode = TagSelectionMode.required;
    }
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        filterMode: _filterMode,
        selectedTagIds: Set<String>.unmodifiable(_selectedTagIds),
        optionalTagIds: Set<String>.unmodifiable(_optionalTagIds),
        selectionMode: _selectionMode,
      );
    }
  }

  void setMediaTypeFilter(TagMediaTypeFilter filter) {
    if (_mediaTypeFilter == filter) {
      return;
    }

    _mediaTypeFilter = filter;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(mediaTypeFilter: _mediaTypeFilter);
    }
  }

  /// Includes or excludes [directoryPath] together with everything below it.
  ///
  /// The whole subtree moves as one, so a fully-selected folder clears, and a
  /// partially-selected or unselected one fills. Unchecking a single child
  /// afterwards is what leaves its parent partially selected.
  void toggleDirectorySelection(String directoryPath) {
    final normalized = p.normalize(directoryPath);
    final subtree = _knownDirectoryPaths
        .where(
          (candidate) =>
              candidate == normalized || p.isWithin(normalized, candidate),
        )
        .toSet();
    if (subtree.isEmpty) {
      return;
    }

    final isFullySelected = subtree.every(_selectedDirectoryPaths.contains);
    _selectedDirectoryPaths = isFullySelected
        ? _selectedDirectoryPaths.difference(subtree)
        : <String>{..._selectedDirectoryPaths, ...subtree};

    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedDirectoryPaths: Set<String>.unmodifiable(
          _selectedDirectoryPaths,
        ),
      );
    }
  }

  void clearDirectorySelection() {
    if (_selectedDirectoryPaths.isEmpty) {
      return;
    }

    _selectedDirectoryPaths = <String>{};
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedDirectoryPaths: const <String>{},
      );
    }
  }

  /// Adds or removes [mediaId] from the grid selection.
  void toggleMediaSelection(String mediaId) {
    final updated = Set<String>.from(_selectedMediaIds);
    if (!updated.remove(mediaId)) {
      updated.add(mediaId);
    }
    _applyMediaSelection(updated, isSelectionMode: true);
  }

  /// Replaces the selection with [mediaIds], or adds to it when [append].
  ///
  /// The marquee's entry point: it reports what its rectangle covers on every
  /// pointer move.
  void selectMediaRange(Iterable<String> mediaIds, {bool append = false}) {
    final updated = append
        ? (Set<String>.from(_selectedMediaIds)..addAll(mediaIds))
        : Set<String>.from(mediaIds);
    _applyMediaSelection(updated, isSelectionMode: true);
  }

  /// Turns on selection mode without changing what is selected.
  ///
  /// A long-press drag starts here, before the rectangle has covered anything.
  void enableMediaSelectionMode() {
    if (_isMediaSelectionMode) {
      return;
    }
    _applyMediaSelection(_selectedMediaIds, isSelectionMode: true);
  }

  void clearMediaSelection() {
    if (_selectedMediaIds.isEmpty && !_isMediaSelectionMode) {
      return;
    }
    _applyMediaSelection(const <String>{}, isSelectionMode: false);
  }

  void _applyMediaSelection(
    Set<String> mediaIds, {
    required bool isSelectionMode,
  }) {
    _selectedMediaIds = mediaIds;
    _isMediaSelectionMode = isSelectionMode;

    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedMediaIds: Set<String>.unmodifiable(_selectedMediaIds),
        isSelectionMode: _isMediaSelectionMode,
      );
    }
  }

  /// The query the tab is currently expressing.
  SavedFilterDefinition currentFilter() {
    return SavedFilterDefinition(
      requiredTagIds: Set<String>.unmodifiable(_selectedTagIds),
      optionalTagIds: Set<String>.unmodifiable(_optionalTagIds),
      excludedTagIds: Set<String>.unmodifiable(_excludedTagIds),
      filterMode: _filterMode,
      mediaTypeFilter: _mediaTypeFilter,
      directoryPaths: Set<String>.unmodifiable(_selectedDirectoryPaths),
    );
  }

  /// Restores a saved filter, dropping anything it refers to that is gone.
  ///
  /// A saved filter can outlive the things it names: a tag can be deleted, and a
  /// library root can be removed, taking its directory paths with it. Both are
  /// pruned here rather than being applied blind, and the [SavedFilterApplied]
  /// report says what was dropped so the screen can tell the user instead of
  /// quietly showing the wrong results.
  SavedFilterApplied applySavedFilter(SavedFilterEntity filter) {
    final definition = filter.definition;

    final knownTagIds = switch (state) {
      TagsLoaded(:final sections) =>
        sections.map((section) => section.id).toSet(),
      _ => const <String>{},
    };

    Set<String> keepTags(Set<String> ids) => ids.intersection(knownTagIds);

    final required = keepTags(definition.requiredTagIds);
    final optional = keepTags(definition.optionalTagIds);
    final excluded = keepTags(definition.excludedTagIds);
    final directories =
        definition.directoryPaths.intersection(_knownDirectoryPaths);

    // Distinct ids that vanished. Counting per bucket would double-count a tag
    // the filter names in two of them, and comparing a de-duplicated total
    // against the sum of the bucket sizes would go negative.
    final droppedTags =
        definition.allTagIds.toSet().difference(knownTagIds).length;
    final droppedDirectories =
        definition.directoryPaths.difference(_knownDirectoryPaths).length;

    _selectedTagIds = required;
    _optionalTagIds = optional;
    _excludedTagIds = excluded;
    _filterMode = definition.filterMode;
    _mediaTypeFilter = definition.mediaTypeFilter;
    _selectedDirectoryPaths = directories;

    // A non-hybrid mode has no optional bucket, so the input mode must not be
    // left pointing at one.
    if (!_filterMode.isHybrid) {
      _selectionMode = TagSelectionMode.required;
    }

    // The baseline for "has this been modified?" is the *pruned* filter, not the
    // stored one — otherwise a prune would mark the filter dirty the instant it
    // was applied.
    final applied = currentFilter();
    _appliedFilterId = filter.id;
    _appliedFilterDefinition = applied;

    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedTagIds: Set<String>.unmodifiable(_selectedTagIds),
        optionalTagIds: Set<String>.unmodifiable(_optionalTagIds),
        excludedTagIds: Set<String>.unmodifiable(_excludedTagIds),
        filterMode: _filterMode,
        mediaTypeFilter: _mediaTypeFilter,
        selectionMode: _selectionMode,
        selectedDirectoryPaths: Set<String>.unmodifiable(
          _selectedDirectoryPaths,
        ),
        appliedFilterId: _appliedFilterId,
      );
    }

    return SavedFilterApplied(
      droppedTagCount: droppedTags,
      droppedDirectoryCount: droppedDirectories,
    );
  }

  /// Whether the applied filter has been edited since it was applied.
  ///
  /// Drives the "Update 'X'" option. `null` when no filter is applied.
  bool get isAppliedFilterModified {
    final baseline = _appliedFilterDefinition;
    return baseline != null && baseline != currentFilter();
  }

  String? get appliedFilterId => _appliedFilterId;

  /// Marks [filterId] as the applied filter, taking the current query as its
  /// baseline.
  ///
  /// Pass `null` to forget the applied filter **without changing the query** —
  /// which is what deleting a saved filter does: the results you are looking at
  /// stay, they are just no longer "a saved filter". To actually undo a filter,
  /// use [clearSavedFilter].
  void setAppliedFilter(String? filterId) {
    _appliedFilterId = filterId;
    _appliedFilterDefinition = filterId == null ? null : currentFilter();

    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        appliedFilterId: _appliedFilterId,
        clearAppliedFilter: filterId == null,
      );
    }
  }

  /// Un-applies the saved filter, restoring the unfiltered view.
  ///
  /// What tapping the applied chip a second time does. It has to undo the whole
  /// query — every field [applySavedFilter] set — and not merely deselect the
  /// chip, or the results would stay filtered by something that no longer looks
  /// applied.
  void clearSavedFilter() {
    _selectedTagIds = <String>{};
    _optionalTagIds = <String>{};
    _excludedTagIds = <String>{};
    _filterMode = TagFilterMode.any;
    _mediaTypeFilter = TagMediaTypeFilter.all;
    _selectionMode = TagSelectionMode.required;
    _selectedDirectoryPaths = <String>{};
    _appliedFilterId = null;
    _appliedFilterDefinition = null;

    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedTagIds: const <String>{},
        optionalTagIds: const <String>{},
        excludedTagIds: const <String>{},
        filterMode: _filterMode,
        mediaTypeFilter: _mediaTypeFilter,
        selectionMode: _selectionMode,
        selectedDirectoryPaths: const <String>{},
        clearAppliedFilter: true,
      );
    }
  }

  /// The media currently selected, as entities.
  List<MediaEntity> selectedMedia() {
    final currentState = state;
    if (currentState is! TagsLoaded) {
      return const [];
    }
    return _selectedMediaIds
        .map((id) => currentState.mediaById[id])
        .whereType<MediaEntity>()
        .toList(growable: false);
  }

  /// Tags every selected item already shares — what the bulk dialog opens with.
  List<String> commonTagIdsForSelection() {
    final selection = selectedMedia();
    if (selection.isEmpty) {
      return const [];
    }

    final common = LinkedHashSet<String>.from(selection.first.tagIds);
    for (final media in selection.skip(1)) {
      common.retainAll(media.tagIds);
    }
    return List<String>.unmodifiable(common);
  }

  /// Replaces the tags on every selected item with [tagIds].
  Future<void> applyTagsToSelection(List<String> tagIds) async {
    if (_selectedMediaIds.isEmpty) {
      return;
    }

    final sanitized = List<String>.unmodifiable(
      LinkedHashSet<String>.from(tagIds),
    );

    await _assignTagUseCase.setTagsForMedia(
      _selectedMediaIds.toList(growable: false),
      sanitized,
    );

    // The tag sections are derived from these rows, so they have to be rebuilt —
    // a media item may have just left or joined the very section it is sitting in.
    await _reloadSections();
  }

  /// Drops selected ids that the current filters no longer show.
  ///
  /// Called after a reload: a bulk delete, or a tag change that narrows the
  /// result set, would otherwise leave the selection pointing at media the grid
  /// is no longer displaying.
  void _pruneMediaSelection(Set<String> visibleMediaIds) {
    if (_selectedMediaIds.isEmpty) {
      return;
    }
    _selectedMediaIds = _selectedMediaIds.intersection(visibleMediaIds);
    if (_selectedMediaIds.isEmpty) {
      _isMediaSelectionMode = false;
    }
  }

  Future<TagSection?> _buildFavoritesSection({
    Map<String, MediaEntity>? cachedMediaById,
  }) async {
    final favoriteIds = await _favoritesRepository.getFavoriteMediaIds();
    if (favoriteIds.isEmpty) {
      return null;
    }

    final favoritesMedia = await _loadMediaByIds(
      favoriteIds,
      cachedMediaById: cachedMediaById,
    );
    if (favoritesMedia.isEmpty) {
      return null;
    }

    return TagSection(
      id: 'favorites',
      name: 'Favorites',
      isFavorites: true,
      directories: const [],
      mediaIds: favoritesMedia.map((media) => media.id).toList(),
      itemCount: favoritesMedia.length,
    );
  }

  Future<TagSection?> _buildUntaggedSection(
    List<MediaEntity> cachedMedia,
    Map<String, Set<String>> mediaIdsByTopDirectoryId,
    Map<String, int> mediaOrderById,
  ) async {
    final untaggedMedia = cachedMedia
        .where((media) => media.tagIds.isEmpty)
        .toList();
    if (untaggedMedia.isEmpty) {
      return null;
    }

    final untaggedIds = untaggedMedia.map((media) => media.id).toSet();
    final directoryContents = <TagDirectoryContent>[];
    final collectedMediaIds = <String>{};
    for (final directory in _libraryDirectories) {
      final directoryMediaIds =
          mediaIdsByTopDirectoryId[directory.id] ?? const <String>{};
      final idsForDirectory =
          directoryMediaIds.where(untaggedIds.contains).toList()..sort(
            (a, b) => (mediaOrderById[a] ?? 1 << 30).compareTo(
              mediaOrderById[b] ?? 1 << 30,
            ),
          );

      if (idsForDirectory.isEmpty) {
        continue;
      }

      collectedMediaIds.addAll(idsForDirectory);
      directoryContents.add(
        TagDirectoryContent(directory: directory, mediaIds: idsForDirectory),
      );
    }

    final standaloneMedia = untaggedMedia
        .where((media) => !collectedMediaIds.contains(media.id))
        .map((media) => media.id)
        .toList(growable: false);

    final itemCount = standaloneMedia.length + collectedMediaIds.length;

    return TagSection(
      id: 'untagged',
      name: 'Untagged',
      isFavorites: false,
      directories: directoryContents,
      mediaIds: standaloneMedia,
      itemCount: itemCount,
    );
  }

  TagSection _buildSectionForTag(
    TagEntity tag,
    Map<String, int> mediaOrderById,
    Map<String, Set<String>> mediaIdsByTagId,
    Map<String, Set<String>> mediaIdsByTopDirectoryId,
  ) {
    final tagMediaIds = mediaIdsByTagId[tag.id] ?? const <String>{};
    final collectedMediaIds = <String>{};
    final directorySections = <TagDirectoryContent>[];

    for (final directory in _libraryDirectories) {
      final directoryMediaIds =
          mediaIdsByTopDirectoryId[directory.id] ?? const <String>{};
      final mediaIdsForDirectory = directoryMediaIds
          .where(tagMediaIds.contains)
          .toList();

      if (mediaIdsForDirectory.isEmpty) {
        continue;
      }

      mediaIdsForDirectory.sort(
        (a, b) => (mediaOrderById[a] ?? 1 << 30).compareTo(
          mediaOrderById[b] ?? 1 << 30,
        ),
      );

      collectedMediaIds.addAll(mediaIdsForDirectory);
      directorySections.add(
        TagDirectoryContent(
          directory: directory,
          mediaIds: mediaIdsForDirectory,
        ),
      );
    }

    final standaloneMediaIds =
        tagMediaIds
            .where((mediaId) => !collectedMediaIds.contains(mediaId))
            .toList()
          ..sort(
            (a, b) => (mediaOrderById[a] ?? 1 << 30).compareTo(
              mediaOrderById[b] ?? 1 << 30,
            ),
          );

    final itemCount = collectedMediaIds.length + standaloneMediaIds.length;

    return TagSection(
      id: tag.id,
      name: tag.name,
      isFavorites: false,
      directories: directorySections,
      mediaIds: standaloneMediaIds,
      itemCount: itemCount,
      color: Color(tag.color),
    );
  }

  List<DirectoryEntity> _extractTopLevelDirectories(
    List<DirectoryEntity> directories,
  ) {
    if (directories.isEmpty) {
      return const [];
    }

    final normalized =
        directories
            .map(
              (directory) =>
                  directory.copyWith(path: p.normalize(directory.path)),
            )
            .toList()
          ..sort((a, b) => a.path.length.compareTo(b.path.length));

    final topDirectories = <DirectoryEntity>[];
    for (final directory in normalized) {
      final isNested = topDirectories.any(
        (top) =>
            directory.path == top.path ||
            p.isWithin(top.path, directory.path),
      );
      if (!isNested) {
        topDirectories.add(directory);
      }
    }

    topDirectories.sort((a, b) => a.name.compareTo(b.name));
    return topDirectories;
  }

  String? _findTopDirectoryIdForPath(String path) {
    final rootPath = findContainingRootPath(
      path,
      _rootIdByNormalizedPath.keys,
    );
    return rootPath == null ? null : _rootIdByNormalizedPath[rootPath];
  }

  Future<List<MediaEntity>> _loadMediaByIds(
    List<String> mediaIds, {
    Map<String, MediaEntity>? cachedMediaById,
  }) async {
    if (cachedMediaById != null) {
      return mediaIds
          .map((mediaId) => cachedMediaById[mediaId])
          .whereType<MediaEntity>()
          .toList();
    }

    final storedMedia = await _mediaDataSource.getMedia();
    final mediaMap = {for (final media in storedMedia) media.id: media};

    final entities = <MediaEntity>[];
    for (final mediaId in mediaIds) {
      final mediaModel = mediaMap[mediaId];
      if (mediaModel != null) {
        entities.add(_toEntity(mediaModel));
      }
    }
    return entities;
  }

  MediaEntity _toEntity(MediaModel model) {
    return MediaEntity(
      id: model.id,
      path: model.path,
      name: model.name,
      type: model.type,
      size: model.size,
      lastModified: model.lastModified,
      tagIds: model.tagIds,
      directoryId: model.directoryId,
      bookmarkData: model.bookmarkData,
    );
  }
}

final tagsViewModelProvider =
    StateNotifierProvider.autoDispose<TagsViewModel, TagsState>((ref) {
      final viewModel = TagsViewModel(
        ref.watch(getTagsUseCaseProvider),
        ref.watch(filterByTagsUseCaseProvider),
        ref.watch(favoritesRepositoryProvider),
        ref.watch(isarMediaDataSourceProvider),
        ref.watch(directoryRepositoryProvider),
        ref.watch(assignTagUseCaseProvider),
      );
      return viewModel;
    });

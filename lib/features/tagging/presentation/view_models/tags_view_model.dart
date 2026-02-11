import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/logging_service.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../media_library/data/isar/isar_media_data_source.dart';
import '../../../media_library/data/models/media_model.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../../tagging/domain/enums/tag_filter_mode.dart';
import '../../../tagging/domain/enums/tag_media_type_filter.dart';
import '../../../tagging/domain/use_cases/filter_by_tags_use_case.dart';
import '../../../tagging/domain/use_cases/get_tags_use_case.dart';
import '../../../../shared/providers/repository_providers.dart';

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

sealed class TagsState {
  const TagsState();
}

enum TagSelectionMode {
  required,
  optional,
  excluded,
}

extension TagSelectionModeX on TagSelectionMode {
  String get label => switch (this) {
        TagSelectionMode.required => 'Must include',
        TagSelectionMode.optional => 'Match any',
        TagSelectionMode.excluded => 'Exclude',
      };

  String get helperText => switch (this) {
        TagSelectionMode.required => 'Media must include every required tag.',
        TagSelectionMode.optional => 'Media must include at least one optional tag.',
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
    required this.selectedDirectoryIds,
    required this.directoryMediaCounts,
    required this.mediaById,
  });

  final List<TagSection> sections;
  final List<String> selectedTagIds;
  final List<String> optionalTagIds;
  final List<String> excludedTagIds;
  final TagFilterMode filterMode;
  final TagMediaTypeFilter mediaTypeFilter;
  final TagSelectionMode selectionMode;
  final List<DirectoryEntity> libraryDirectories;
  final List<String> selectedDirectoryIds;
  final Map<String, int> directoryMediaCounts;
  final Map<String, MediaEntity> mediaById;

  TagsLoaded copyWith({
    List<TagSection>? sections,
    List<String>? selectedTagIds,
    List<String>? optionalTagIds,
    List<String>? excludedTagIds,
    TagFilterMode? filterMode,
    TagMediaTypeFilter? mediaTypeFilter,
    TagSelectionMode? selectionMode,
    List<DirectoryEntity>? libraryDirectories,
    List<String>? selectedDirectoryIds,
    Map<String, int>? directoryMediaCounts,
    Map<String, MediaEntity>? mediaById,
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
      selectedDirectoryIds: selectedDirectoryIds ?? this.selectedDirectoryIds,
      directoryMediaCounts: directoryMediaCounts ?? this.directoryMediaCounts,
      mediaById: mediaById ?? this.mediaById,
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
  ) : super(const TagsLoading());

  final GetTagsUseCase _getTagsUseCase;
  final FilterByTagsUseCase _filterByTagsUseCase;
  final FavoritesRepository _favoritesRepository;
  final IsarMediaDataSource _mediaDataSource;
  List<String> _selectedTagIds = const [];
  List<String> _optionalTagIds = const [];
  List<String> _excludedTagIds = const [];
  List<String> _selectedDirectoryIds = const [];
  TagFilterMode _filterMode = TagFilterMode.any;
  TagMediaTypeFilter _mediaTypeFilter = TagMediaTypeFilter.all;
  TagSelectionMode _selectionMode = TagSelectionMode.required;
  List<DirectoryEntity> _libraryDirectories = const [];
  Map<String, int> _directoryMediaCounts = const {};

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
            selectedDirectoryIds: List<String>.from(_selectedDirectoryIds),
            directoryMediaCounts: _directoryMediaCounts,
            mediaById: currentState.mediaById,
          );
        } else if (otherSections.isEmpty) {
          _selectedTagIds = const [];
          _optionalTagIds = const [];
          _excludedTagIds = const [];
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
            selectedDirectoryIds: List<String>.from(_selectedDirectoryIds),
            directoryMediaCounts: _directoryMediaCounts,
            mediaById: currentState.mediaById,
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

      final allDirectories =
          await _filterByTagsUseCase.filterDirectories(const []);
      _libraryDirectories = _extractTopLevelDirectories(allDirectories);

      final cachedMediaModels = await _mediaDataSource.getMedia();
      final cachedMediaEntities = cachedMediaModels
          .map(_toEntity)
          .toList(growable: false);
      _directoryMediaCounts = _countMediaByTopDirectory(cachedMediaEntities);
      final cachedMediaById = {
        for (final media in cachedMediaEntities) media.id: media,
      };
      final mediaOrderById = {
        for (var index = 0; index < cachedMediaEntities.length; index += 1)
          cachedMediaEntities[index].id: index,
      };
      final mediaIdsByTagId = <String, Set<String>>{};
      final mediaIdsByTopDirectoryId = <String, Set<String>>{};
      for (final media in cachedMediaEntities) {
        for (final tagId in media.tagIds) {
          mediaIdsByTagId
              .putIfAbsent(tagId, () => <String>{})
              .add(media.id);
        }

        final topDirectoryId = _findTopDirectoryIdForPath(media.path);
        if (topDirectoryId != null) {
          mediaIdsByTopDirectoryId
              .putIfAbsent(topDirectoryId, () => <String>{})
              .add(media.id);
        }
      }

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

      _selectedDirectoryIds = _selectedDirectoryIds
          .where((id) => _libraryDirectories.any((dir) => dir.id == id))
          .toList();

      if (sections.isEmpty) {
        _selectedTagIds = const [];
        _optionalTagIds = const [];
        _excludedTagIds = const [];
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
          selectedDirectoryIds: List<String>.from(_selectedDirectoryIds),
          directoryMediaCounts: _directoryMediaCounts,
          mediaById: cachedMediaById,
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
    final selectionMode =
        _filterMode.isHybrid ? _selectionMode : TagSelectionMode.required;
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
    final updatedSelection = List<String>.from(_selectedTagIds);
    if (isSelected) {
      if (!updatedSelection.contains(tagId)) {
        updatedSelection.add(tagId);
      }
      _optionalTagIds = _optionalTagIds.where((id) => id != tagId).toList();
      _excludedTagIds = _excludedTagIds.where((id) => id != tagId).toList();
    } else {
      updatedSelection.remove(tagId);
    }
    _updateSelection(updatedSelection);
  }

  void _updateOptional(String tagId, bool isSelected) {
    final updatedOptional = List<String>.from(_optionalTagIds);
    if (isSelected) {
      if (!updatedOptional.contains(tagId)) {
        updatedOptional.add(tagId);
      }
      _selectedTagIds = _selectedTagIds.where((id) => id != tagId).toList();
      _excludedTagIds = _excludedTagIds.where((id) => id != tagId).toList();
    } else {
      updatedOptional.remove(tagId);
    }
    _updateOptionalSelection(updatedOptional);
  }

  void setTagExcluded(String tagId, bool isExcluded) {
    final updatedExclusions = List<String>.from(_excludedTagIds);
    if (isExcluded) {
      if (!updatedExclusions.contains(tagId)) {
        updatedExclusions.add(tagId);
      }
      _selectedTagIds = _selectedTagIds.where((id) => id != tagId).toList();
      _optionalTagIds = _optionalTagIds.where((id) => id != tagId).toList();
    } else {
      updatedExclusions.remove(tagId);
    }
    _updateExclusions(updatedExclusions);
  }

  void clearSelection() {
    _updateSelection(const []);
    _updateOptionalSelection(const []);
    _updateExclusions(const []);
  }

  List<String> _syncSelectionWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _selectedTagIds = _selectedTagIds
        .where((tagId) => availableIds.contains(tagId))
        .toList();
    return List<String>.from(_selectedTagIds);
  }

  List<String> _syncOptionalWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _optionalTagIds = _optionalTagIds
        .where((tagId) => availableIds.contains(tagId))
        .where((tagId) => !_selectedTagIds.contains(tagId))
        .toList();
    return List<String>.from(_optionalTagIds);
  }

  List<String> _syncExclusionsWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _excludedTagIds = _excludedTagIds
        .where((tagId) => availableIds.contains(tagId))
        .where((tagId) => !_selectedTagIds.contains(tagId))
        .where((tagId) => !_optionalTagIds.contains(tagId))
        .toList();
    return List<String>.from(_excludedTagIds);
  }

  void _updateSelection(List<String> newSelection) {
    _selectedTagIds = newSelection;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedTagIds: List<String>.from(_selectedTagIds),
        excludedTagIds: List<String>.from(_excludedTagIds),
        optionalTagIds: List<String>.from(_optionalTagIds),
      );
    }
  }

  void _updateOptionalSelection(List<String> newOptional) {
    _optionalTagIds = newOptional;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        optionalTagIds: List<String>.from(_optionalTagIds),
        selectedTagIds: List<String>.from(_selectedTagIds),
        excludedTagIds: List<String>.from(_excludedTagIds),
      );
    }
  }

  void _updateExclusions(List<String> newExclusions) {
    _excludedTagIds = newExclusions;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        excludedTagIds: List<String>.from(_excludedTagIds),
        selectedTagIds: List<String>.from(_selectedTagIds),
        optionalTagIds: List<String>.from(_optionalTagIds),
      );
    }
  }

  void setFilterMode(TagFilterMode mode) {
    if (_filterMode == mode) {
      return;
    }

    _filterMode = mode;
    if (!_filterMode.isHybrid && _optionalTagIds.isNotEmpty) {
      _selectedTagIds = {..._selectedTagIds, ..._optionalTagIds}.toList();
      _optionalTagIds = const [];
    }
    if (!_filterMode.isHybrid) {
      _selectionMode = TagSelectionMode.required;
    }
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        filterMode: _filterMode,
        selectedTagIds: List<String>.from(_selectedTagIds),
        optionalTagIds: List<String>.from(_optionalTagIds),
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

  void toggleDirectorySelection(String directoryId) {
    final updatedSelection = List<String>.from(_selectedDirectoryIds);
    if (updatedSelection.contains(directoryId)) {
      updatedSelection.remove(directoryId);
    } else {
      updatedSelection.add(directoryId);
    }

    _selectedDirectoryIds = updatedSelection;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(
        selectedDirectoryIds: List<String>.from(_selectedDirectoryIds),
      );
    }
  }

  void clearDirectorySelection() {
    if (_selectedDirectoryIds.isEmpty) {
      return;
    }

    _selectedDirectoryIds = const [];
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(selectedDirectoryIds: const []);
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
    final untaggedMedia =
        cachedMedia.where((media) => media.tagIds.isEmpty).toList();
    if (untaggedMedia.isEmpty) {
      return null;
    }

    final untaggedIds = untaggedMedia.map((media) => media.id).toSet();
    final directoryContents = <TagDirectoryContent>[];
    final collectedMediaIds = <String>{};
    for (final directory in _libraryDirectories) {
      final directoryMediaIds = mediaIdsByTopDirectoryId[directory.id] ??
          const <String>{};
      final idsForDirectory = directoryMediaIds
          .where(untaggedIds.contains)
          .toList()
        ..sort(
          (a, b) => (mediaOrderById[a] ?? 1 << 30).compareTo(
            mediaOrderById[b] ?? 1 << 30,
          ),
        );

      if (idsForDirectory.isEmpty) {
        continue;
      }

      collectedMediaIds.addAll(idsForDirectory);
      directoryContents.add(
        TagDirectoryContent(
          directory: directory,
          mediaIds: idsForDirectory,
        ),
      );
    }

    final standaloneMedia = untaggedMedia
        .where((media) => !collectedMediaIds.contains(media.id))
        .map((media) => media.id)
        .toList(growable: false);

    final itemCount =
        standaloneMedia.length + collectedMediaIds.length;

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
      final directoryMediaIds = mediaIdsByTopDirectoryId[directory.id] ??
          const <String>{};
      final mediaIdsForDirectory =
          directoryMediaIds.where(tagMediaIds.contains).toList();

      if (mediaIdsForDirectory.isEmpty) {
        continue;
      }

      mediaIdsForDirectory.sort(
        (a, b) =>
            (mediaOrderById[a] ?? 1 << 30).compareTo(mediaOrderById[b] ?? 1 << 30),
      );

      collectedMediaIds.addAll(mediaIdsForDirectory);
      directorySections.add(
        TagDirectoryContent(directory: directory, mediaIds: mediaIdsForDirectory),
      );
    }

    final standaloneMediaIds = tagMediaIds
        .where((mediaId) => !collectedMediaIds.contains(mediaId))
        .toList()
      ..sort(
        (a, b) =>
            (mediaOrderById[a] ?? 1 << 30).compareTo(mediaOrderById[b] ?? 1 << 30),
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

  Map<String, int> _countMediaByTopDirectory(List<MediaEntity> media) {
    if (media.isEmpty || _libraryDirectories.isEmpty) {
      return const {};
    }

    final counts = <String, int>{};
    for (final item in media) {
      final directoryId = _findTopDirectoryIdForPath(item.path);
      if (directoryId == null) {
        continue;
      }
      counts.update(directoryId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  List<DirectoryEntity> _extractTopLevelDirectories(
    List<DirectoryEntity> directories,
  ) {
    if (directories.isEmpty) {
      return const [];
    }

    final normalized = directories
        .map(
          (directory) => directory.copyWith(path: p.normalize(directory.path)),
        )
        .toList()
      ..sort((a, b) => a.path.length.compareTo(b.path.length));

    final topDirectories = <DirectoryEntity>[];
    for (final directory in normalized) {
      final isNested = topDirectories.any(
        (top) => _isPathWithin(top.path, directory.path),
      );
      if (!isNested) {
        topDirectories.add(directory);
      }
    }

    topDirectories.sort((a, b) => a.name.compareTo(b.name));
    return topDirectories;
  }

  String? _findTopDirectoryIdForPath(String path) {
    if (_libraryDirectories.isEmpty) {
      return null;
    }

    final normalized = p.normalize(path);
    for (final directory in _libraryDirectories) {
      if (_isPathWithin(directory.path, normalized)) {
        return directory.id;
      }
    }
    return null;
  }

  bool _isPathWithin(String parentPath, String childPath) {
    final normalizedParent = p.normalize(parentPath);
    final normalizedChild = p.normalize(childPath);
    return normalizedChild == normalizedParent ||
        p.isWithin(normalizedParent, normalizedChild);
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
      );
      return viewModel;
    });

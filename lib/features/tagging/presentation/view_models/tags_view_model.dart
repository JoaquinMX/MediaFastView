import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  const TagDirectoryContent({required this.directory, required this.media});

  final DirectoryEntity directory;
  final List<MediaEntity> media;
}

@immutable
class TagSection {
  const TagSection({
    required this.id,
    required this.name,
    required this.isFavorites,
    required this.directories,
    required this.media,
    this.color,
  });

  final String id;
  final String name;
  final bool isFavorites;
  final List<TagDirectoryContent> directories;
  final List<MediaEntity> media;
  final Color? color;

  int get itemCount => allMedia.length;

  List<MediaEntity> get allMedia => [
    ...media,
    for (final directory in directories) ...directory.media,
  ];
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

      _libraryDirectories =
          await _filterByTagsUseCase.filterDirectories(const []);

      final cachedMediaModels = await _mediaDataSource.getMedia();
      final cachedMediaEntities = cachedMediaModels
          .map(_toEntity)
          .toList(growable: false);
      _directoryMediaCounts = <String, int>{};
      for (final media in cachedMediaEntities) {
        _directoryMediaCounts.update(
          media.directoryId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      final cachedMediaById = {
        for (final media in cachedMediaEntities) media.id: media,
      };
      final mediaByTagId = <String, List<MediaEntity>>{};
      for (final media in cachedMediaEntities) {
        for (final tagId in media.tagIds) {
          mediaByTagId.putIfAbsent(tagId, () => <MediaEntity>[]).add(media);
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
      );
      if (untaggedSection != null) {
        sections.add(untaggedSection);
      }

      final tags = await _getTagsUseCase();
      for (final tag in tags) {
        final section = await _buildSectionForTag(tag, mediaByTagId);
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
      media: favoritesMedia,
    );
  }

  Future<TagSection?> _buildUntaggedSection(
    List<MediaEntity> cachedMedia,
  ) async {
    final untaggedMedia =
        cachedMedia.where((media) => media.tagIds.isEmpty).toList();
    if (untaggedMedia.isEmpty) {
      return null;
    }

    final directories = await _filterByTagsUseCase.filterDirectories(const []);
    final directoryById = {
      for (final directory in directories) directory.id: directory,
    };

    final mediaByDirectoryId = <String, List<MediaEntity>>{};
    for (final media in untaggedMedia) {
      mediaByDirectoryId
          .putIfAbsent(media.directoryId, () => <MediaEntity>[])
          .add(media);
    }

    final directoryContents = <TagDirectoryContent>[];
    final collectedMediaIds = <String>{};
    mediaByDirectoryId.forEach((directoryId, media) {
      final directory = directoryById[directoryId];
      if (directory == null) {
        return;
      }

      collectedMediaIds.addAll(media.map((item) => item.id));
      directoryContents.add(
        TagDirectoryContent(
          directory: directory,
          media: media,
        ),
      );
    });

    final standaloneMedia = untaggedMedia
        .where((media) => !collectedMediaIds.contains(media.id))
        .toList();

    return TagSection(
      id: 'untagged',
      name: 'Untagged',
      isFavorites: false,
      directories: directoryContents,
      media: standaloneMedia,
    );
  }

  Future<TagSection> _buildSectionForTag(
    TagEntity tag,
    Map<String, List<MediaEntity>> cachedMediaByTag,
  ) async {
    final filterResults = await _filterByTagsUseCase.getFilteredResults([
      tag.id,
    ]);

    final cachedMediaForTag = List<MediaEntity>.from(
      cachedMediaByTag[tag.id] ?? const [],
    );
    final cachedMediaByDirectoryId = <String, List<MediaEntity>>{};
    for (final media in cachedMediaForTag) {
      cachedMediaByDirectoryId
          .putIfAbsent(media.directoryId, () => <MediaEntity>[])
          .add(media);
    }

    final collectedMediaIds = <String>{};
    final directorySections = <TagDirectoryContent>[];

    for (final directory in filterResults.directories) {
      List<MediaEntity> directoryMedia = const [];
      try {
        directoryMedia = await _filterByTagsUseCase.filterMediaInDirectory(
          directory,
          [tag.id],
        );
      } catch (e) {
        LoggingService.instance.error(
          'Failed to load media for directory ${directory.id} and tag ${tag.id}: $e',
        );
      }

      if (directoryMedia.isEmpty) {
        directoryMedia = List<MediaEntity>.from(
          cachedMediaByDirectoryId[directory.id] ?? const <MediaEntity>[],
        );
      }

      if (directoryMedia.isNotEmpty) {
        collectedMediaIds.addAll(directoryMedia.map((media) => media.id));
      }

      directorySections.add(
        TagDirectoryContent(directory: directory, media: directoryMedia),
      );
    }

    final standaloneCandidates = [
      ...filterResults.media,
      for (final media in cachedMediaForTag)
        if (!collectedMediaIds.contains(media.id)) media,
    ];

    final uniqueStandalone = <String, MediaEntity>{};
    for (final media in standaloneCandidates) {
      uniqueStandalone[media.id] = media;
    }

    return TagSection(
      id: tag.id,
      name: tag.name,
      isFavorites: false,
      directories: directorySections,
      media: uniqueStandalone.values.toList(),
      color: Color(tag.color),
    );
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

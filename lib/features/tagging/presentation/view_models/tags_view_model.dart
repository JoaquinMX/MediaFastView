import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/logging_service.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../../media_library/data/data_sources/local_media_data_source.dart';
import '../../../media_library/data/models/media_model.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
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

class TagsLoading extends TagsState {
  const TagsLoading();
}

class TagsLoaded extends TagsState {
  const TagsLoaded({
    required this.sections,
    required this.selectedTagIds,
    required this.filteredMedia,
  });

  final List<TagSection> sections;
  final List<String> selectedTagIds;
  final List<MediaEntity> filteredMedia;

  TagsLoaded copyWith({
    List<TagSection>? sections,
    List<String>? selectedTagIds,
    List<MediaEntity>? filteredMedia,
  }) {
    return TagsLoaded(
      sections: sections ?? this.sections,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      filteredMedia: filteredMedia ?? this.filteredMedia,
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
  final SharedPreferencesMediaDataSource _mediaDataSource;
  List<String> _selectedTagIds = const [];

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

        final updatedSections = [
          if (favoritesSection != null) favoritesSection,
          ...otherSections,
        ];

        if (updatedSections.isEmpty) {
          _selectedTagIds = const [];
          state = const TagsEmpty();
        } else {
          final syncedSelection = _syncSelectionWithSections(updatedSections);
          state = TagsLoaded(
            sections: updatedSections,
            selectedTagIds: syncedSelection,
            filteredMedia: _buildFilteredMedia(
              updatedSections,
              syncedSelection,
            ),
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

      final cachedMediaModels = await _mediaDataSource.getMedia();
      final cachedMediaEntities = cachedMediaModels
          .map(_toEntity)
          .toList(growable: false);
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

      final tags = await _getTagsUseCase();
      for (final tag in tags) {
        final section = await _buildSectionForTag(tag, mediaByTagId);
        sections.add(section);
      }

      if (!mounted) {
        return;
      }

      if (sections.isEmpty) {
        _selectedTagIds = const [];
        state = const TagsEmpty();
      } else {
        final syncedSelection = _syncSelectionWithSections(sections);
        state = TagsLoaded(
          sections: sections,
          selectedTagIds: syncedSelection,
          filteredMedia: _buildFilteredMedia(sections, syncedSelection),
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
    final updatedSelection = List<String>.from(_selectedTagIds);
    if (isSelected) {
      if (!updatedSelection.contains(tagId)) {
        updatedSelection.add(tagId);
      }
    } else {
      updatedSelection.remove(tagId);
    }
    _updateSelection(updatedSelection);
  }

  void clearSelection() {
    _updateSelection(const []);
  }

  List<String> _syncSelectionWithSections(List<TagSection> sections) {
    final availableIds = sections.map((section) => section.id).toSet();
    _selectedTagIds = _selectedTagIds
        .where((tagId) => availableIds.contains(tagId))
        .toList();
    return List<String>.from(_selectedTagIds);
  }

  void _updateSelection(List<String> newSelection) {
    _selectedTagIds = newSelection;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      final updatedFilteredMedia =
          _buildFilteredMedia(currentState.sections, _selectedTagIds);
      state = currentState.copyWith(
        selectedTagIds: List<String>.from(_selectedTagIds),
        filteredMedia: updatedFilteredMedia,
      );
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

  List<MediaEntity> _buildFilteredMedia(
    List<TagSection> sections,
    List<String> selectedTagIds,
  ) {
    if (selectedTagIds.isEmpty) {
      return const [];
    }

    final selectedSet = selectedTagIds.toSet();
    final mediaById = <String, MediaEntity>{};

    for (final section in sections) {
      if (!selectedSet.contains(section.id)) {
        continue;
      }

      for (final media in section.allMedia) {
        mediaById[media.id] = media;
      }
    }

    final media = mediaById.values.toList()
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return media;
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
        ref.watch(mediaDataSourceProvider),
      );
      return viewModel;
    });

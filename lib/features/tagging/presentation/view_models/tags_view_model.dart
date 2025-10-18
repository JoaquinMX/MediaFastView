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
    required this.filterMode,
  });

  final List<TagSection> sections;
  final List<String> selectedTagIds;
  final TagFilterMode filterMode;

  TagsLoaded copyWith({
    List<TagSection>? sections,
    List<String>? selectedTagIds,
    TagFilterMode? filterMode,
  }) {
    return TagsLoaded(
      sections: sections ?? this.sections,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      filterMode: filterMode ?? this.filterMode,
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
  TagFilterMode _filterMode = TagFilterMode.any;

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
            filterMode: _filterMode,
          );
        } else if (otherSections.isEmpty) {
          _selectedTagIds = const [];
          state = const TagsEmpty();
        } else {
          state = TagsLoaded(
            sections: otherSections,
            selectedTagIds: _syncSelectionWithSections(otherSections),
            filterMode: _filterMode,
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
        state = TagsLoaded(
          sections: sections,
          selectedTagIds: _syncSelectionWithSections(sections),
          filterMode: _filterMode,
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
      state = currentState.copyWith(
        selectedTagIds: List<String>.from(_selectedTagIds),
      );
    }
  }

  void setFilterMode(TagFilterMode mode) {
    if (_filterMode == mode) {
      return;
    }

    _filterMode = mode;
    final currentState = state;
    if (currentState is TagsLoaded && mounted) {
      state = currentState.copyWith(filterMode: _filterMode);
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

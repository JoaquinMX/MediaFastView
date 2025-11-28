import 'dart:collection';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../domain/use_cases/get_media_use_case.dart';
import '../../domain/use_cases/update_directory_access_use_case.dart';
import '../../domain/entities/media_entity.dart';
import '../../../tagging/domain/entities/tag_entity.dart';
import '../../data/isar/isar_media_data_source.dart';
import '../../data/models/media_model.dart';
import '../../../../core/services/logging_service.dart';
import '../../../favorites/presentation/view_models/favorites_view_model.dart';
import '../models/directory_navigation_target.dart';

/// Defines the available sort options for media items.
enum MediaSortOption {
  nameAscending,
  nameDescending,
  lastModifiedDescending,
  lastModifiedAscending,
  sizeDescending,
}

extension MediaSortOptionX on MediaSortOption {
  String get label => switch (this) {
    MediaSortOption.nameAscending => 'Name (A-Z)',
    MediaSortOption.nameDescending => 'Name (Z-A)',
    MediaSortOption.lastModifiedDescending => 'Last Modified (Newest)',
    MediaSortOption.lastModifiedAscending => 'Last Modified (Oldest)',
    MediaSortOption.sizeDescending => 'Size',
  };
}

/// Sealed class representing the state of the media grid.
sealed class MediaState {
  const MediaState();
}

/// Loading state when media are being fetched.
class MediaLoading extends MediaState {
  const MediaLoading();
}

/// Loaded state with media data.
class MediaLoaded extends MediaState {
  const MediaLoaded({
    required this.media,
    required this.searchQuery,
    required this.selectedTagIds,
    required this.columns,
    required this.currentDirectoryPath,
    required this.currentDirectoryName,
    required this.sortOption,
    required this.selectedMediaIds,
    required this.isSelectionMode,
    required this.showFavoritesOnly,
    required this.visibleMediaTypes,
  });

  final List<MediaEntity> media;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;
  final String currentDirectoryPath;
  final String currentDirectoryName;
  final MediaSortOption sortOption;
  final Set<String> selectedMediaIds;
  final bool isSelectionMode;
  final bool showFavoritesOnly;
  final Set<MediaType> visibleMediaTypes;

  MediaLoaded copyWith({
    List<MediaEntity>? media,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
    String? currentDirectoryPath,
    String? currentDirectoryName,
    MediaSortOption? sortOption,
    Set<String>? selectedMediaIds,
    bool? isSelectionMode,
    bool? showFavoritesOnly,
    Set<MediaType>? visibleMediaTypes,
  }) {
    return MediaLoaded(
      media: media ?? this.media,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
      currentDirectoryPath: currentDirectoryPath ?? this.currentDirectoryPath,
      currentDirectoryName: currentDirectoryName ?? this.currentDirectoryName,
      sortOption: sortOption ?? this.sortOption,
      selectedMediaIds: selectedMediaIds ?? this.selectedMediaIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      visibleMediaTypes: visibleMediaTypes ?? this.visibleMediaTypes,
    );
  }
}

/// Error state when an operation fails.
class MediaError extends MediaState {
  const MediaError(this.message);

  final String message;
}

/// Empty state when no media are available.
class MediaEmpty extends MediaState {
  const MediaEmpty();
}

/// Permission revoked state when the directory is inaccessible.
class MediaPermissionRevoked extends MediaState {
  const MediaPermissionRevoked({
    required this.directoryPath,
    required this.directoryName,
  });

  final String directoryPath;
  final String directoryName;
}

/// ViewModel for managing media grid state and operations.
class MediaViewModel extends StateNotifier<MediaState> {
  MediaViewModel(
    this._ref,
    this._params, {
    required GetMediaUseCase getMediaUseCase,
    required IsarMediaDataSource mediaDataSource,
    required UpdateDirectoryAccessUseCase updateDirectoryAccessUseCase,
  }) : super(const MediaLoading()) {
    _directoryPath = _params.directoryPath;
    _directoryName = _params.directoryName;
    _bookmarkData = _params.bookmarkData;
    _getMediaUseCase = getMediaUseCase;
    _mediaDataSource = mediaDataSource;
    _updateDirectoryAccessUseCase = updateDirectoryAccessUseCase;
    _gridColumnsSubscription = _ref.listen<int>(
      gridColumnsProvider,
      (_, next) => _applyColumnUpdate(next),
    );
    _favoritesSubscription = _ref.listen<FavoritesState>(
      favoritesViewModelProvider,
      (previous, next) {
        final favorites = switch (next) {
          FavoritesLoaded(:final favorites) => favorites,
          FavoritesEmpty() => const <String>[],
          _ => _favoriteMediaIds,
        };
        if (!listEquals(favorites, _favoriteMediaIds)) {
          _favoriteMediaIds = favorites;
          if (_showFavoritesOnly && _favoriteMediaIds.isEmpty) {
            _showFavoritesOnly = false;
            _emitLoadedStateFromCache();
            return;
          }
          if (_showFavoritesOnly) {
            _emitLoadedStateFromCache();
          }
        }
      },
      fireImmediately: true,
    );
    loadMedia();
  }

  final Ref _ref;
  late final GetMediaUseCase _getMediaUseCase;
  late final IsarMediaDataSource _mediaDataSource;
  final MediaViewModelParams _params;
  late String _directoryPath;
  late String _directoryName;
  late String? _bookmarkData;
  late final ProviderSubscription<int> _gridColumnsSubscription;
  List<MediaEntity> _cachedMedia = const [];
  MediaSortOption _currentSortOption = MediaSortOption.nameAscending;
  Set<String> _selectedMediaIds = <String>{};
  bool _isSelectionMode = false;
  late final UpdateDirectoryAccessUseCase _updateDirectoryAccessUseCase;
  List<String> _favoriteMediaIds = const <String>[];
  bool _showFavoritesOnly = false;
  late final ProviderSubscription<FavoritesState> _favoritesSubscription;
  Set<MediaType> _visibleMediaTypes = Set<MediaType>.from(MediaType.values);

  MediaSortOption get currentSortOption => _currentSortOption;
  Set<String> get selectedMediaIds => Set<String>.unmodifiable(_selectedMediaIds);
  bool get isSelectionMode => _isSelectionMode;
  int get selectedMediaCount => _selectedMediaIds.length;
  bool get showFavoritesOnly => _showFavoritesOnly;
  Set<MediaType> get visibleMediaTypes => Set<MediaType>.unmodifiable(
        _visibleMediaTypes,
      );

  /// Returns tags shared by every selected media item.
  List<String> commonTagIdsForSelection() {
    if (_selectedMediaIds.isEmpty) {
      return const <String>[];
    }

    LinkedHashSet<String>? common;
    for (final media in _cachedMedia) {
      if (!_selectedMediaIds.contains(media.id)) {
        continue;
      }
      final tagSet = LinkedHashSet<String>.from(media.tagIds);
      common = common == null
          ? tagSet
          : LinkedHashSet<String>.from(common.where(tagSet.contains));
    }

    return common == null
        ? const <String>[]
        : List<String>.unmodifiable(common);
  }

  /// Returns the union of tag IDs present across the current selection.
  /// Used to reflect which tags are already applied to at least one item when
  /// performing bulk tag operations.
  List<String> tagIdsInSelection() {
    if (_selectedMediaIds.isEmpty) {
      return const <String>[];
    }

    final tagUnion = LinkedHashSet<String>();
    for (final media in _cachedMedia) {
      if (_selectedMediaIds.contains(media.id)) {
        tagUnion.addAll(media.tagIds);
      }
    }

    return List<String>.unmodifiable(tagUnion);
  }

  /// Gets the directory ID generated from the directory path.
  String get directoryId {
    final bytes = utf8.encode(_directoryPath);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  void dispose() {
    _gridColumnsSubscription.close();
    _favoritesSubscription.close();
    super.dispose();
  }

  /// Toggles the selection state for a single media item.
  void toggleMediaSelection(String mediaId) {
    final updated = Set<String>.from(_selectedMediaIds);
    if (!updated.remove(mediaId)) {
      updated.add(mediaId);
    }
    _applySelectionUpdate(updated);
  }

  /// Selects a set of media IDs, optionally appending to the current
  /// selection when [append] is true.
  void selectMediaRange(Iterable<String> mediaIds, {bool append = false}) {
    Set<String> updated = Set<String>.from(_selectedMediaIds);
    if (append) {
      updated.addAll(mediaIds);
    } 
    else {
      updated = Set<String>.from(mediaIds);
    }
    _applySelectionUpdate(updated);
  }

  /// Clears the current media selection and exits selection mode.
  void clearMediaSelection() {
    if (_selectedMediaIds.isEmpty && !_isSelectionMode) {
      return;
    }
    _selectedMediaIds = <String>{};
    _isSelectionMode = false;
    _emitLoadedStateFromCache();
  }

  /// Applies [tagIds] to every selected media item, replacing existing tags.
  Future<void> applyTagsToSelection(List<String> tagIds) async {
    if (_selectedMediaIds.isEmpty) {
      return;
    }

    final sanitizedTags = List<String>.unmodifiable(
      LinkedHashSet<String>.from(tagIds),
    );

    final assignTagUseCase = _ref.read(assignTagUseCaseProvider);
    final result = await assignTagUseCase.setTagsForMedia(
      _selectedMediaIds.toList(),
      sanitizedTags,
    );

    if (result.successfulIds.isNotEmpty) {
      final updatedIds = result.successfulIds.toSet();
      _cachedMedia = _updateMediaTagsForSelection(sanitizedTags, updatedIds);
    }

    if (result.hasFailures) {
      LoggingService.instance.warning(
        'Failed to update tags for media items: ${result.failureReasons}',
      );
    }

    _emitLoadedStateFromCache();
  }

  /// Toggles [tag] across the current selection. If any selected media already
  /// has the tag, it will be removed from all selected items; otherwise the tag
  /// will be added to every selected item.
  Future<void> toggleTagForSelection(TagEntity tag) async {
    if (_selectedMediaIds.isEmpty) {
      return;
    }

    final selectedMedia = _cachedMedia
        .where((media) => _selectedMediaIds.contains(media.id))
        .toList(growable: false);

    if (selectedMedia.isEmpty) {
      return;
    }

    final shouldAddTag =
        !selectedMedia.any((media) => media.tagIds.contains(tag.id));
    final assignTagUseCase = _ref.read(assignTagUseCaseProvider);

    final updatedMedia = <MediaEntity>[];
    for (final media in _cachedMedia) {
      if (!_selectedMediaIds.contains(media.id)) {
        updatedMedia.add(media);
        continue;
      }

      final hasTag = media.tagIds.contains(tag.id);
      final updatedTagIds = shouldAddTag
          ? (hasTag ? media.tagIds : [...media.tagIds, tag.id])
          : media.tagIds.where((id) => id != tag.id).toList(growable: false);

      updatedMedia.add(
        media.copyWith(tagIds: List<String>.unmodifiable(updatedTagIds)),
      );

      if (shouldAddTag && !hasTag) {
        await assignTagUseCase.assignTagToMedia(media.id, tag);
      } else if (!shouldAddTag && hasTag) {
        await assignTagUseCase.removeTagFromMedia(media.id, tag);
      }
    }

    _cachedMedia = updatedMedia;
    _emitLoadedStateFromCache();
  }

  void _applySelectionUpdate(Set<String> selection) {
    final sanitized = selection..removeWhere((id) => id.isEmpty);
    _selectedMediaIds = sanitized;
    _isSelectionMode = _selectedMediaIds.isNotEmpty;
    _emitLoadedStateFromCache();
  }

  void _clearSelectionInternal() {
    _selectedMediaIds = <String>{};
    _isSelectionMode = false;
  }

  void _synchronizeSelectionWithCache() {
    if (_selectedMediaIds.isEmpty) {
      _isSelectionMode = false;
      return;
    }

    final availableIds = {for (final media in _cachedMedia) media.id};
    final sanitized = _selectedMediaIds.where(availableIds.contains).toSet();
    if (sanitized.length != _selectedMediaIds.length) {
      _selectedMediaIds = sanitized;
    }
    _isSelectionMode = _selectedMediaIds.isNotEmpty;
  }

  List<MediaEntity> _updateMediaTagsForSelection(
    List<String> tagIds,
    Set<String> targetMediaIds,
  ) {
    if (targetMediaIds.isEmpty || _cachedMedia.isEmpty) {
      return List<MediaEntity>.from(_cachedMedia);
    }
    return _cachedMedia
        .map(
          (media) => targetMediaIds.contains(media.id)
              ? media.copyWith(tagIds: tagIds)
              : media,
        )
        .toList();
  }

  /// Loads media for the current directory.
  Future<void> loadMedia() async {
    final loadStartTime = DateTime.now();
    LoggingService.instance.info(
      'Loading media for directory: $_directoryPath, bookmarkData present: ${_bookmarkData != null}',
    );
    state = const MediaLoading();
    try {
      LoggingService.instance.debug(
        'Calling _getMediaUseCase.forDirectoryPath',
      );
      final scanStartTime = DateTime.now();
      final media = await _getMediaUseCase.forDirectoryPath(
        _directoryPath,
        bookmarkData: _bookmarkData,
      );
      final scanTime = DateTime.now().difference(scanStartTime);
      LoggingService.instance.info(
        'Retrieved ${media.length} media items in ${scanTime.inMilliseconds}ms',
      );

      // Get existing persisted media to merge tagIds
      final mergeStartTime = DateTime.now();
      final existingMedia = await _mediaDataSource.getMedia();
      final existingMediaMap = {for (final m in existingMedia) m.id: m};

      // Convert entities back to models for persistence, merging tagIds from persisted data
      final mediaModels = media.map((entity) {
        final existing = existingMediaMap[entity.id];
        return MediaModel(
          id: entity.id,
          path: entity.path,
          name: entity.name,
          type: entity.type,
          size: entity.size,
          lastModified: entity.lastModified,
          tagIds:
              existing?.tagIds ??
              entity.tagIds, // Merge tagIds from persisted data
          directoryId: entity.directoryId,
          bookmarkData: entity.bookmarkData,
        );
      }).toList();
      final mergeTime = DateTime.now().difference(mergeStartTime);

      // Replace persisted entries for this directory with the freshly scanned data
      final persistStartTime = DateTime.now();
      await _mediaDataSource.removeMediaForDirectory(directoryId);
      await _mediaDataSource.upsertMedia(mediaModels);
      final persistTime = DateTime.now().difference(persistStartTime);

      final totalTime = DateTime.now().difference(loadStartTime);
      LoggingService.instance.info(
        'Media loading completed in ${totalTime.inMilliseconds}ms (scan: ${scanTime.inMilliseconds}ms, merge: ${mergeTime.inMilliseconds}ms, persist: ${persistTime.inMilliseconds}ms)',
      );

      _cachedMedia = _sortMedia(media, _currentSortOption);

      if (media.isEmpty) {
        LoggingService.instance.info('No media found, setting empty state');
        _clearSelectionInternal();
        state = const MediaEmpty();
      } else {
        LoggingService.instance.info('Media loaded successfully, setting loaded state');
        _clearSelectionInternal();
        state = MediaLoaded(
          media: _applySearchFilters(_cachedMedia, ''),
          searchQuery: '',
          selectedTagIds: const [],
          columns: _ref.read(gridColumnsProvider),
          currentDirectoryPath: _directoryPath,
          currentDirectoryName: _directoryName,
          sortOption: _currentSortOption,
          selectedMediaIds: const <String>{},
          isSelectionMode: false,
          showFavoritesOnly: _showFavoritesOnly,
          visibleMediaTypes: _visibleMediaTypes,
        );
      }
    } catch (e) {
      final totalTime = DateTime.now().difference(loadStartTime);
      LoggingService.instance.error(
        'Error loading media after ${totalTime.inMilliseconds}ms: $e',
      );
      // Check if this is a permission-related error
      final errorMessage = e.toString();
      _cachedMedia = const [];
      if (_isPermissionError(errorMessage)) {
        LoggingService.instance.warning(
          'Permission error detected, setting permission revoked state',
        );
        _clearSelectionInternal();
        state = MediaPermissionRevoked(
          directoryPath: _directoryPath,
          directoryName: _directoryName,
        );
      } else {
        LoggingService.instance
            .error('Non-permission error, setting error state');
        _clearSelectionInternal();
        state = MediaError(errorMessage);
      }
    }
  }

  /// Searches media by query.
  void searchMedia(String query) {
    if (state case MediaLoaded(
      :final selectedTagIds,
      :final columns,
      :final currentDirectoryPath,
      :final currentDirectoryName,
      :final sortOption,
    )) {
      final results = _applySearchFilters(_cachedMedia, query);
      _synchronizeSelectionWithCache();
      final selectionSnapshot = Set<String>.unmodifiable(_selectedMediaIds);
      final selectionMode = selectionSnapshot.isNotEmpty && _isSelectionMode;
      _isSelectionMode = selectionMode;
      state = MediaLoaded(
        media: results,
        searchQuery: query,
        selectedTagIds: selectedTagIds,
        columns: columns,
        currentDirectoryPath: currentDirectoryPath,
        currentDirectoryName: currentDirectoryName,
        sortOption: sortOption,
        selectedMediaIds: selectionSnapshot,
        isSelectionMode: selectionMode,
        showFavoritesOnly: _showFavoritesOnly,
        visibleMediaTypes: _visibleMediaTypes,
      );
    }
  }

  /// Filters media by tag IDs.
  void filterByTags(List<String> tagIds) async {
    final previousColumns = _ref.read(gridColumnsProvider);
    state = const MediaLoading();
    try {
      final media = await _getMediaUseCase.filterByTagsForDirectory(
        tagIds,
        _directoryPath,
        bookmarkData: _bookmarkData,
      );

      // Get existing persisted media to merge tagIds
      final existingMedia = await _mediaDataSource.getMedia();
      final existingMediaMap = {for (final m in existingMedia) m.id: m};

      // Convert entities back to models for persistence, merging tagIds from persisted data
      final mediaModels = media.map((entity) {
        final existing = existingMediaMap[entity.id];
        return MediaModel(
          id: entity.id,
          path: entity.path,
          name: entity.name,
          type: entity.type,
          size: entity.size,
          lastModified: entity.lastModified,
          tagIds:
              existing?.tagIds ??
              entity.tagIds, // Merge tagIds from persisted data
          directoryId: entity.directoryId,
          bookmarkData: entity.bookmarkData,
        );
      }).toList();

      // Merge filtered results to ensure tag updates are persisted without
      // discarding media from other directories or filters
      await _mediaDataSource.upsertMedia(mediaModels);

      _cachedMedia = _sortMedia(media, _currentSortOption);

      _clearSelectionInternal();
      state = MediaLoaded(
        media: _applySearchFilters(_cachedMedia, ''),
        searchQuery: '', // Reset search when filtering
        selectedTagIds: tagIds,
        columns: previousColumns,
        currentDirectoryPath: _directoryPath,
        currentDirectoryName: _directoryName,
        sortOption: _currentSortOption,
        selectedMediaIds: const <String>{},
        isSelectionMode: false,
        showFavoritesOnly: _showFavoritesOnly,
        visibleMediaTypes: _visibleMediaTypes,
      );
    } catch (e) {
      // Check if this is a permission-related error
      final errorMessage = e.toString();
      _cachedMedia = const [];
      if (_isPermissionError(errorMessage)) {
        state = MediaPermissionRevoked(
          directoryPath: _directoryPath,
          directoryName: _directoryName,
        );
      } else {
        state = MediaError(errorMessage);
      }
      _clearSelectionInternal();
    }
  }

  /// Filters media to only show favorites when [value] is true.
  void setShowFavoritesOnly(bool value) {
    if (_showFavoritesOnly == value) {
      return;
    }
    if (value && _favoriteMediaIds.isEmpty) {
      return;
    }
    _showFavoritesOnly = value;
    _emitLoadedStateFromCache();
  }

  /// Updates the active media types and reapplies filters.
  void setVisibleMediaTypes(Set<MediaType> mediaTypes) {
    if (mediaTypes.isEmpty) {
      return;
    }

    if (setEquals(mediaTypes, _visibleMediaTypes)) {
      return;
    }

    _visibleMediaTypes = Set<MediaType>.from(mediaTypes);
    _emitLoadedStateFromCache();
  }

  /// Sets the number of columns for the grid.
  void setColumns(int columns) {
    final clampedColumns = columns.clamp(2, 12);
    _ref.read(gridColumnsProvider.notifier).setColumns(clampedColumns);
  }

  /// Navigates to a subdirectory.
  Future<void> navigateToDirectory(
    String directoryPath,
    String directoryName, {
    String? bookmarkData,
    List<DirectoryNavigationTarget>? siblingDirectories,
    int? currentIndex,
  }) async {
    _params.navigateToDirectory?.call(
      directoryPath,
      directoryName,
      bookmarkData,
      siblingDirectories,
      currentIndex,
    );
  }

  /// Attempts to recover permissions by prompting user to re-select the directory.
  Future<void> recoverPermissions() async {
    LoggingService.instance.info(
      'Attempting to recover permissions for directory: $_directoryPath',
    );
    if (_params.onPermissionRecoveryNeeded == null) {
      LoggingService.instance.warning(
        'No permission recovery callback provided',
      );
      throw Exception(
        'Permission recovery not available - no callback provided',
      );
    }

    state = const MediaLoading(); // Show loading state during recovery

    try {
      final selectedPath = await _params.onPermissionRecoveryNeeded!();
      if (selectedPath != null && selectedPath.isNotEmpty) {
        LoggingService.instance.info(
          'User selected new path: $selectedPath, updating directory path and reloading',
        );

        // Validate the new path before proceeding
        final permissionService = PermissionService();
        final accessStatus = await permissionService.checkDirectoryAccess(
          selectedPath,
        );

        if (accessStatus != PermissionStatus.granted) {
          throw Exception(
            'Selected directory is not accessible: ${accessStatus.name}',
          );
        }

        final originalDirectoryId = directoryId;

        // Update the directory path and reload
        _directoryPath = selectedPath;
        _directoryName = selectedPath
            .split('/')
            .lastWhere(
              (element) => element.isNotEmpty,
              orElse: () => selectedPath,
            );
        _bookmarkData = null; // Clear bookmark data since we're re-selecting

        // Try to create a new bookmark for the selected directory
        try {
          final bookmarkService = BookmarkService.instance;
          _bookmarkData = await bookmarkService.createBookmark(_directoryPath);
          LoggingService.instance.info(
            'Created new bookmark for recovered directory',
          );
        } catch (e) {
          LoggingService.instance.warning(
            'Failed to create bookmark for recovered directory: $e',
          );
          // Continue without bookmark - it's not critical for basic functionality
        }

        await _updateDirectoryAccessUseCase(
          directoryId: originalDirectoryId,
          newPath: _directoryPath,
          newName: _directoryName,
          bookmarkData: _bookmarkData,
        );

        await loadMedia();
        LoggingService.instance.info(
          'Permission recovery completed successfully',
        );
      } else {
        LoggingService.instance.info('User cancelled permission recovery');
        // Revert to permission revoked state
        state = MediaPermissionRevoked(
          directoryPath: _directoryPath,
          directoryName: _directoryName,
        );
        throw Exception('User cancelled permission recovery');
      }
    } catch (e) {
      LoggingService.instance.error('Error during permission recovery: $e');
      // Revert to permission revoked state with error details
      state = MediaPermissionRevoked(
        directoryPath: _directoryPath,
        directoryName: _directoryName,
      );
      throw Exception('Failed to recover permissions: $e');
    }
  }

  /// Validates current permissions without triggering recovery
  Future<bool> validateCurrentPermissions() async {
    try {
      final permissionService = PermissionService();
      final accessStatus = await permissionService.checkDirectoryAccess(
        _directoryPath,
      );
      final hasAccess = accessStatus == PermissionStatus.granted;

      LoggingService.instance.debug(
        'Permission validation result: $accessStatus for $_directoryPath',
      );

      // Also validate bookmark if present
      final bookmarkData = _bookmarkData;
      if (bookmarkData != null && hasAccess) {
        final bookmarkResult = await permissionService.validateBookmark(
          bookmarkData,
        );
        if (!bookmarkResult.isValid) {
          LoggingService.instance.warning(
            'Bookmark validation failed: ${bookmarkResult.reason}',
          );
          return false;
        }
      }

      return hasAccess;
    } catch (e) {
      LoggingService.instance.error('Error validating permissions: $e');
      return false;
    }
  }

  /// Helper method to search media.
  List<MediaEntity> _searchMedia(List<MediaEntity> media, String query) {
    if (query.isEmpty) return media;
    return media
        .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  List<MediaEntity> _applySearch(List<MediaEntity> media, String query) {
    if (query.isEmpty) {
      return List<MediaEntity>.from(media);
    }
    return _searchMedia(media, query);
  }

  List<MediaEntity> _applyFavoritesFilter(List<MediaEntity> media) {
    if (!_showFavoritesOnly) {
      return List<MediaEntity>.from(media);
    }
    if (_favoriteMediaIds.isEmpty) {
      return const <MediaEntity>[];
    }
    final favoritesSet = _favoriteMediaIds.toSet();
    return media
        .where((item) => favoritesSet.contains(item.id))
        .toList(growable: false);
  }

  List<MediaEntity> _applyMediaTypeFilter(List<MediaEntity> media) {
    if (_visibleMediaTypes.length == MediaType.values.length) {
      return List<MediaEntity>.from(media);
    }

    return media
        .where((item) => _visibleMediaTypes.contains(item.type))
        .toList(growable: false);
  }

  List<MediaEntity> _applySearchFilters(
    List<MediaEntity> media,
    String query,
  ) {
    final typeFiltered = _applyMediaTypeFilter(media);
    final favoritesFiltered = _applyFavoritesFilter(typeFiltered);
    return _applySearch(favoritesFiltered, query);
  }

  void _emitLoadedStateFromCache() {
    if (state case MediaLoaded(
      :final searchQuery,
      :final selectedTagIds,
      :final columns,
      :final currentDirectoryPath,
      :final currentDirectoryName,
    )) {
      _synchronizeSelectionWithCache();
      final selectionSnapshot = Set<String>.unmodifiable(_selectedMediaIds);
      final selectionMode = selectionSnapshot.isNotEmpty && _isSelectionMode;
      _isSelectionMode = selectionMode;
      final results = _applySearchFilters(_cachedMedia, searchQuery);
      state = MediaLoaded(
        media: results,
        searchQuery: searchQuery,
        selectedTagIds: selectedTagIds,
        columns: columns,
        currentDirectoryPath: currentDirectoryPath,
        currentDirectoryName: currentDirectoryName,
        sortOption: _currentSortOption,
        selectedMediaIds: selectionSnapshot,
        isSelectionMode: selectionMode,
        showFavoritesOnly: _showFavoritesOnly,
        visibleMediaTypes: _visibleMediaTypes,
      );
    } else if (state is MediaEmpty && _selectedMediaIds.isNotEmpty) {
      _clearSelectionInternal();
    }
  }

  /// Helper method to check if an error is permission-related.
  bool _isPermissionError(String errorMessage) {
    return errorMessage.contains('Operation not permitted') ||
        errorMessage.contains('errno = 1') ||
        errorMessage.contains('Permission denied') ||
        errorMessage.contains('FileSystemError');
  }

  void _applyColumnUpdate(int columns) {
    if (state case MediaLoaded(:final media,
        :final searchQuery,
        :final selectedTagIds,
        :final currentDirectoryPath,
        :final currentDirectoryName,
        :final sortOption)) {
      _synchronizeSelectionWithCache();
      final selectionSnapshot = Set<String>.unmodifiable(_selectedMediaIds);
      final selectionMode = selectionSnapshot.isNotEmpty && _isSelectionMode;
      _isSelectionMode = selectionMode;
      state = MediaLoaded(
        media: media,
        searchQuery: searchQuery,
        selectedTagIds: selectedTagIds,
        columns: columns,
        currentDirectoryPath: currentDirectoryPath,
        currentDirectoryName: currentDirectoryName,
        sortOption: sortOption,
        selectedMediaIds: selectionSnapshot,
        isSelectionMode: selectionMode,
        showFavoritesOnly: _showFavoritesOnly,
        visibleMediaTypes: _visibleMediaTypes,
      );
    }
  }

  /// Updates the active sort option and reapplies sorting and filtering.
  void changeSortOption(MediaSortOption option) {
    if (_currentSortOption == option) {
      return;
    }

    _currentSortOption = option;
    _cachedMedia = _sortMedia(_cachedMedia, _currentSortOption);

    if (state case MediaLoaded(
      :final searchQuery,
      :final selectedTagIds,
      :final columns,
      :final currentDirectoryPath,
      :final currentDirectoryName,
    )) {
      final results = _applySearchFilters(_cachedMedia, searchQuery);
      _synchronizeSelectionWithCache();
      final selectionSnapshot = Set<String>.unmodifiable(_selectedMediaIds);
      final selectionMode = selectionSnapshot.isNotEmpty && _isSelectionMode;
      _isSelectionMode = selectionMode;
      state = MediaLoaded(
        media: results,
        searchQuery: searchQuery,
        selectedTagIds: selectedTagIds,
        columns: columns,
        currentDirectoryPath: currentDirectoryPath,
        currentDirectoryName: currentDirectoryName,
        sortOption: _currentSortOption,
        selectedMediaIds: selectionSnapshot,
        isSelectionMode: selectionMode,
        showFavoritesOnly: _showFavoritesOnly,
        visibleMediaTypes: _visibleMediaTypes,
      );
    }
  }

  List<MediaEntity> _sortMedia(
    List<MediaEntity> media,
    MediaSortOption option,
  ) {
    final sorted = List<MediaEntity>.from(media);
    switch (option) {
      case MediaSortOption.nameAscending:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case MediaSortOption.nameDescending:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case MediaSortOption.lastModifiedDescending:
        sorted.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case MediaSortOption.lastModifiedAscending:
        sorted.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
      case MediaSortOption.sizeDescending:
        sorted.sort((a, b) => b.size.compareTo(a.size));
        break;
    }
    return sorted;
  }
}

/// Provider for MediaViewModel with auto-dispose.
final mediaViewModelProvider = StateNotifierProvider.autoDispose
    .family<MediaViewModel, MediaState, MediaViewModelParams>(
      (ref, params) => MediaViewModel(
        ref,
        params,
        getMediaUseCase: ref.watch(getMediaUseCaseProvider),
        mediaDataSource: ref.watch(isarMediaDataSourceProvider),
        updateDirectoryAccessUseCase:
            ref.watch(updateDirectoryAccessUseCaseProvider),
      ),
    );

Set<String> _extractMediaSelection(MediaState state) => switch (state) {
      MediaLoaded(selectedMediaIds: final ids) => ids,
      _ => const <String>{},
    };

bool _extractMediaSelectionMode(MediaState state) => switch (state) {
      MediaLoaded(isSelectionMode: final mode) => mode,
      _ => false,
    };

/// Provider exposing the current set of selected media IDs.
final selectedMediaIdsProvider =
    Provider.autoDispose.family<Set<String>, MediaViewModelParams>((ref, params) {
  final state = ref.watch(mediaViewModelProvider(params));
  return _extractMediaSelection(state);
});

/// Provider exposing whether selection mode is active for the current media grid.
final mediaSelectionModeProvider =
    Provider.autoDispose.family<bool, MediaViewModelParams>((ref, params) {
  final state = ref.watch(mediaViewModelProvider(params));
  return _extractMediaSelectionMode(state);
});

/// Provider exposing the number of selected media items for the given grid.
final selectedMediaCountProvider =
    Provider.autoDispose.family<int, MediaViewModelParams>((ref, params) {
  final state = ref.watch(mediaViewModelProvider(params));
  return _extractMediaSelection(state).length;
});

/// Parameters for the media view model provider.
class MediaViewModelParams {
  const MediaViewModelParams({
    required this.directoryPath,
    required this.directoryName,
    this.bookmarkData,
    this.navigateToDirectory,
    this.onPermissionRecoveryNeeded,
  });

  final String directoryPath;
  final String directoryName;
  final String? bookmarkData;
  final void Function(
    String path,
    String name,
    String? bookmarkData,
    List<DirectoryNavigationTarget>? siblingDirectories,
    int? currentIndex,
  )?
  navigateToDirectory;
  final Future<String?> Function()? onPermissionRecoveryNeeded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaViewModelParams &&
          runtimeType == other.runtimeType &&
          directoryPath == other.directoryPath &&
          directoryName == other.directoryName &&
          bookmarkData == other.bookmarkData;

  @override
  int get hashCode =>
      directoryPath.hashCode ^ directoryName.hashCode ^ bookmarkData.hashCode;
}

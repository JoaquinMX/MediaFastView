import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_error.dart';
import '../../../../core/error/error_handler.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/providers/grid_columns_provider.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../data/data_sources/local_directory_data_source.dart';
import '../../domain/entities/directory_entity.dart';
import '../../domain/use_cases/add_directory_use_case.dart';
import '../../domain/use_cases/clear_directories_use_case.dart';
import '../../domain/use_cases/get_directories_use_case.dart';
import '../../domain/use_cases/remove_directory_use_case.dart';
import '../../domain/use_cases/search_directories_use_case.dart';

/// Defines the available sort options for directory listings.
enum DirectorySortOption {
  nameAscending,
  nameDescending,
  lastModifiedDescending,
  lastModifiedAscending,
}

extension DirectorySortOptionX on DirectorySortOption {
  String get label => switch (this) {
    DirectorySortOption.nameAscending => 'Name (A-Z)',
    DirectorySortOption.nameDescending => 'Name (Z-A)',
    DirectorySortOption.lastModifiedDescending => 'Last Modified (Newest)',
    DirectorySortOption.lastModifiedAscending => 'Last Modified (Oldest)',
  };
}

/// Sealed class representing the state of the directory grid.
sealed class DirectoryState {
  const DirectoryState();
}

/// Loading state when directories are being fetched.
class DirectoryLoading extends DirectoryState {
  const DirectoryLoading();
}

/// Loaded state with directories data.
class DirectoryLoaded extends DirectoryState {
  const DirectoryLoaded({
    required this.directories,
    required this.searchQuery,
    required this.selectedTagIds,
    required this.columns,
    required this.sortOption,
    required this.selectedDirectoryIds,
    required this.isSelectionMode,
  });

  final List<DirectoryEntity> directories;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;
  final DirectorySortOption sortOption;
  final Set<String> selectedDirectoryIds;
  final bool isSelectionMode;

  DirectoryLoaded copyWith({
    List<DirectoryEntity>? directories,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
    DirectorySortOption? sortOption,
    Set<String>? selectedDirectoryIds,
    bool? isSelectionMode,
  }) {
    return DirectoryLoaded(
      directories: directories ?? this.directories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
      sortOption: sortOption ?? this.sortOption,
      selectedDirectoryIds:
          selectedDirectoryIds ?? this.selectedDirectoryIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

/// Error state when an operation fails.
class DirectoryError extends DirectoryState {
  const DirectoryError(this.message);

  final String message;
}

/// Empty state when no directories are available.
class DirectoryEmpty extends DirectoryState {
  const DirectoryEmpty();
}

/// Permission revoked state when directories are inaccessible.
class DirectoryPermissionRevoked extends DirectoryState {
  const DirectoryPermissionRevoked({
    required this.inaccessibleDirectories,
    required this.accessibleDirectories,
    required this.searchQuery,
    required this.selectedTagIds,
    required this.columns,
    required this.sortOption,
    required this.selectedDirectoryIds,
    required this.isSelectionMode,
  });

  final List<DirectoryEntity> inaccessibleDirectories;
  final List<DirectoryEntity> accessibleDirectories;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;
  final DirectorySortOption sortOption;
  final Set<String> selectedDirectoryIds;
  final bool isSelectionMode;

  DirectoryPermissionRevoked copyWith({
    List<DirectoryEntity>? inaccessibleDirectories,
    List<DirectoryEntity>? accessibleDirectories,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
    DirectorySortOption? sortOption,
    Set<String>? selectedDirectoryIds,
    bool? isSelectionMode,
  }) {
    return DirectoryPermissionRevoked(
      inaccessibleDirectories:
          inaccessibleDirectories ?? this.inaccessibleDirectories,
      accessibleDirectories:
          accessibleDirectories ?? this.accessibleDirectories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
      sortOption: sortOption ?? this.sortOption,
      selectedDirectoryIds:
          selectedDirectoryIds ?? this.selectedDirectoryIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

/// Bookmark invalid state when directories have invalid bookmarks requiring re-selection.
class DirectoryBookmarkInvalid extends DirectoryState {
  const DirectoryBookmarkInvalid({
    required this.invalidDirectories,
    required this.accessibleDirectories,
    required this.searchQuery,
    required this.selectedTagIds,
    required this.columns,
    required this.sortOption,
    required this.selectedDirectoryIds,
    required this.isSelectionMode,
  });

  final List<DirectoryEntity> invalidDirectories;
  final List<DirectoryEntity> accessibleDirectories;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;
  final DirectorySortOption sortOption;
  final Set<String> selectedDirectoryIds;
  final bool isSelectionMode;

  DirectoryBookmarkInvalid copyWith({
    List<DirectoryEntity>? invalidDirectories,
    List<DirectoryEntity>? accessibleDirectories,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
    DirectorySortOption? sortOption,
    Set<String>? selectedDirectoryIds,
    bool? isSelectionMode,
  }) {
    return DirectoryBookmarkInvalid(
      invalidDirectories: invalidDirectories ?? this.invalidDirectories,
      accessibleDirectories:
          accessibleDirectories ?? this.accessibleDirectories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
      sortOption: sortOption ?? this.sortOption,
      selectedDirectoryIds:
          selectedDirectoryIds ?? this.selectedDirectoryIds,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
    );
  }
}

/// ViewModel for managing directory grid state and operations.
class DirectoryViewModel extends StateNotifier<DirectoryState> {
  DirectoryViewModel(
    this._ref,
    this._getDirectoriesUseCase,
    this._searchDirectoriesUseCase,
    this._addDirectoryUseCase,
    this._removeDirectoryUseCase,
    this._clearDirectoriesUseCase,
    this._localDirectoryDataSource,
    this._permissionService,
  ) : super(const DirectoryLoading()) {
    _currentColumns = _ref.read(gridColumnsProvider);
    _gridColumnsSubscription = _ref.listen<int>(gridColumnsProvider, (_, next) {
      _currentColumns = next;
      if (state
          case DirectoryLoaded() ||
              DirectoryPermissionRevoked() ||
              DirectoryBookmarkInvalid()) {
        _emitFilteredState();
      }
    });
    loadDirectories();
  }

  final Ref _ref;
  final GetDirectoriesUseCase _getDirectoriesUseCase;
  final SearchDirectoriesUseCase _searchDirectoriesUseCase;
  final AddDirectoryUseCase _addDirectoryUseCase;
  final RemoveDirectoryUseCase _removeDirectoryUseCase;
  final ClearDirectoriesUseCase _clearDirectoriesUseCase;
  final LocalDirectoryDataSource _localDirectoryDataSource;
  final PermissionService _permissionService;
  late final ProviderSubscription<int> _gridColumnsSubscription;

  List<DirectoryEntity> _cachedAccessibleDirectories = const [];
  List<DirectoryEntity> _cachedInaccessibleDirectories = const [];
  List<DirectoryEntity> _cachedInvalidDirectories = const [];
  String _currentSearchQuery = '';
  List<String> _currentSelectedTagIds = const <String>[];
  late int _currentColumns;
  DirectorySortOption _currentSortOption = DirectorySortOption.nameAscending;
  Set<String> _selectedDirectoryIds = <String>{};
  bool _isSelectionMode = false;

  DirectorySortOption get currentSortOption => _currentSortOption;
  Set<String> get selectedDirectoryIds => Set<String>.unmodifiable(_selectedDirectoryIds);
  bool get isSelectionMode => _isSelectionMode;
  int get selectedDirectoryCount => _selectedDirectoryIds.length;

  /// Returns the collection of tag IDs that are common to every selected
  /// directory. When no directories are selected the list will be empty.
  List<String> commonTagIdsForSelection() {
    if (_selectedDirectoryIds.isEmpty) {
      return const <String>[];
    }

    LinkedHashSet<String>? common;

    void intersectWith(List<DirectoryEntity> directories) {
      for (final directory in directories) {
        if (!_selectedDirectoryIds.contains(directory.id)) {
          continue;
        }
        final tagSet = LinkedHashSet<String>.from(directory.tagIds);
        common = common == null
            ? tagSet
            : LinkedHashSet<String>.from(
                common!.where(tagSet.contains),
              );
      }
    }

    intersectWith(_cachedAccessibleDirectories);
    intersectWith(_cachedInaccessibleDirectories);
    intersectWith(_cachedInvalidDirectories);

    return common == null
        ? const <String>[]
        : List<String>.unmodifiable(common!);
  }

  @override
  void dispose() {
    _gridColumnsSubscription.close();
    super.dispose();
  }

  /// Toggles the selection state for a single directory.
  void toggleDirectorySelection(String directoryId) {
    final updated = Set<String>.from(_selectedDirectoryIds);
    if (!updated.remove(directoryId)) {
      updated.add(directoryId);
    }
    _applySelectionUpdate(updated);
  }

  /// Selects a specific set of directory IDs. When [append] is true the IDs
  /// are merged with the existing selection, otherwise the selection is
  /// replaced entirely.
  void selectDirectoryRange(Iterable<String> directoryIds, {bool append = false}) {
    Set<String> updated = Set<String>.from(_selectedDirectoryIds);
    if (append) {
      updated.addAll(directoryIds);
    } 
    else {
      updated = Set<String>.from(directoryIds);
    }
    _applySelectionUpdate(updated);
  }

  /// Clears all selected directories and exits selection mode.
  void clearDirectorySelection() {
    if (_selectedDirectoryIds.isEmpty && !_isSelectionMode) {
      return;
    }
    _selectedDirectoryIds = <String>{};
    _isSelectionMode = false;
    _emitFilteredState();
  }

  /// Applies the provided [tagIds] to every selected directory. Existing tags
  /// are replaced with the provided collection.
  Future<void> applyTagsToSelection(List<String> tagIds) async {
    if (_selectedDirectoryIds.isEmpty) {
      return;
    }

    final assignTagUseCase = _ref.read(assignTagUseCaseProvider);
    final sanitizedTags = List<String>.unmodifiable(
      LinkedHashSet<String>.from(tagIds),
    );

    final result = await assignTagUseCase.setTagsForDirectories(
      _selectedDirectoryIds.toList(),
      sanitizedTags,
    );

    if (result.successfulIds.isNotEmpty) {
      final updatedIds = result.successfulIds.toSet();
      _cachedAccessibleDirectories = _updateTagsForSelection(
        _cachedAccessibleDirectories,
        updatedIds,
        sanitizedTags,
      );
      _cachedInaccessibleDirectories = _updateTagsForSelection(
        _cachedInaccessibleDirectories,
        updatedIds,
        sanitizedTags,
      );
      _cachedInvalidDirectories = _updateTagsForSelection(
        _cachedInvalidDirectories,
        updatedIds,
        sanitizedTags,
      );
    }

    if (result.hasFailures) {
      LoggingService.instance.warning(
        'Failed to update tags for directories: ${result.failureReasons}',
      );
    }

    _emitFilteredState();
  }

  void _applySelectionUpdate(Set<String> updatedSelection) {
    final sanitized = updatedSelection..removeWhere((id) => id.isEmpty);
    _selectedDirectoryIds = sanitized;
    _isSelectionMode = _selectedDirectoryIds.isNotEmpty;
    _emitFilteredState();
  }

  void _clearSelectionInternal() {
    _selectedDirectoryIds = <String>{};
    _isSelectionMode = false;
  }

  List<DirectoryEntity> _updateTagsForSelection(
    List<DirectoryEntity> directories,
    Set<String> targetDirectoryIds,
    List<String> tagIds,
  ) {
    if (directories.isEmpty || targetDirectoryIds.isEmpty) {
      return List<DirectoryEntity>.from(directories);
    }
    return directories
        .map(
          (directory) => targetDirectoryIds.contains(directory.id)
              ? directory.copyWith(tagIds: tagIds)
              : directory,
        )
        .toList();
  }

  void _synchronizeSelectionWithCaches() {
    if (_selectedDirectoryIds.isEmpty) {
      _isSelectionMode = false;
      return;
    }

    final availableIds = <String>{
      for (final directory in _cachedAccessibleDirectories) directory.id,
      for (final directory in _cachedInaccessibleDirectories) directory.id,
      for (final directory in _cachedInvalidDirectories) directory.id,
    };

    final sanitized = _selectedDirectoryIds
        .where(availableIds.contains)
        .toSet();

    if (sanitized.length != _selectedDirectoryIds.length) {
      _selectedDirectoryIds = sanitized;
    }
    _isSelectionMode = _selectedDirectoryIds.isNotEmpty;
  }

  /// Loads all directories.
  Future<void> loadDirectories() async {
    LoggingService.instance.debug('Starting loadDirectories operation');
    state = const DirectoryLoading();
    try {
      LoggingService.instance.debug('Fetching directories from use case');
      final directories = await _getDirectoriesUseCase();
      LoggingService.instance.debug(
        'Retrieved ${directories.length} directories from use case',
      );

      // Separate accessible and inaccessible directories
      final accessibleDirectories = <DirectoryEntity>[];
      final inaccessibleDirectories = <DirectoryEntity>[];

      LoggingService.instance.debug(
        'Checking directory accessibility for ${directories.length} directories',
      );
      for (final directory in directories) {
        try {
          if (await _isDirectoryAccessible(directory)) {
            accessibleDirectories.add(directory);
            LoggingService.instance.debug(
              'Directory ${directory.path} is accessible',
            );
          } else {
            inaccessibleDirectories.add(directory);
            LoggingService.instance.debug(
              'Directory ${directory.path} is not accessible',
            );
          }
        } catch (e) {
          LoggingService.instance.warning(
            'Error checking accessibility for directory ${directory.path}: $e',
          );
          inaccessibleDirectories.add(directory);
        }
      }

      LoggingService.instance.debug(
        'Accessibility check complete: ${accessibleDirectories.length} accessible, ${inaccessibleDirectories.length} inaccessible',
      );

      if (accessibleDirectories.isEmpty && inaccessibleDirectories.isEmpty) {
        LoggingService.instance.info('Setting state to DirectoryEmpty');
        _updateDirectoryCaches(
          accessible: const [],
          inaccessible: const [],
          invalid: const [],
        );
        _clearSelectionInternal();
        _resetFilters();
        state = const DirectoryEmpty();
      } else {
        if (accessibleDirectories.isNotEmpty &&
            inaccessibleDirectories.isEmpty) {
          LoggingService.instance.info(
            'Setting state to DirectoryLoaded with ${accessibleDirectories.length} directories',
          );
          LoggingService.instance.debug('Directory details:');
          for (final dir in accessibleDirectories) {
            LoggingService.instance.debug(
              '  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}',
            );
          }
          _updateDirectoryCaches(
            accessible: accessibleDirectories,
            inaccessible: const [],
            invalid: const [],
          );
        } else {
          LoggingService.instance.info(
            'Setting state to DirectoryPermissionRevoked: ${accessibleDirectories.length} accessible, ${inaccessibleDirectories.length} inaccessible',
          );
          LoggingService.instance.debug('Accessible directory details:');
          for (final dir in accessibleDirectories) {
            LoggingService.instance.debug(
              '  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}',
            );
          }
          LoggingService.instance.debug('Inaccessible directory details:');
          for (final dir in inaccessibleDirectories) {
            LoggingService.instance.debug(
              '  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}',
            );
          }
          _updateDirectoryCaches(
            accessible: accessibleDirectories,
            inaccessible: inaccessibleDirectories,
            invalid: const [],
          );
        }
        _clearSelectionInternal();
        _resetFilters();
        _emitFilteredState();
      }
    } catch (e) {
      LoggingService.instance.error('Error in loadDirectories: $e');
      if (e is BookmarkInvalidError) {
        LoggingService.instance.info(
          'Handling BookmarkInvalidError for directory ${e.directoryPath}',
        );
        // Set to bookmark invalid state
        final invalidDirectory = DirectoryEntity(
          id: e.directoryId,
          path: e.directoryPath,
          name: e.directoryPath.split('/').last,
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime.now(),
          bookmarkData: null,
        );
        _updateDirectoryCaches(
          accessible: const [],
          inaccessible: const [],
          invalid: [invalidDirectory],
        );
        _clearSelectionInternal();
        _resetFilters();
        _emitFilteredState();
      } else {
        LoggingService.instance.error(
          'Setting state to DirectoryError: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}',
        );
        _updateDirectoryCaches(
          accessible: const [],
          inaccessible: const [],
          invalid: const [],
        );
        _clearSelectionInternal();
        state = DirectoryError(ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e)));
      }
    }
  }

  /// Searches directories by query.
  void searchDirectories(String query) {
    if (query == _currentSearchQuery) {
      return;
    }
    final previousColumns = switch (state) {
      DirectoryLoaded(columns: final columns) => columns,
      DirectoryPermissionRevoked(columns: final columns) => columns,
      DirectoryBookmarkInvalid(columns: final columns) => columns,
      _ => _currentColumns,
    };
    _currentColumns = previousColumns;
    _currentSearchQuery = query;
    if (state
        case DirectoryLoaded() ||
            DirectoryPermissionRevoked() ||
            DirectoryBookmarkInvalid()) {
      _emitFilteredState();
    }
  }

  /// Filters directories by tag IDs.
  void filterByTags(List<String> tagIds) {
    LoggingService.instance.info('filterByTags called with tagIds: $tagIds');
    LoggingService.instance.debug('Current state type: ${state.runtimeType}');

    final previousColumns = switch (state) {
      DirectoryLoaded(columns: final columns) => columns,
      DirectoryPermissionRevoked(columns: final columns) => columns,
      DirectoryBookmarkInvalid(columns: final columns) => columns,
      _ => _currentColumns,
    };
    _currentColumns = previousColumns;
    _currentSelectedTagIds = List<String>.unmodifiable(tagIds);
    LoggingService.instance.info(
      'filterByTags completed. New selectedTagIds: $tagIds',
    );
    _emitFilteredState();
  }

  void _updateDirectoryCaches({
    List<DirectoryEntity>? accessible,
    List<DirectoryEntity>? inaccessible,
    List<DirectoryEntity>? invalid,
  }) {
    if (accessible != null) {
      _cachedAccessibleDirectories = List<DirectoryEntity>.from(accessible);
    }
    if (inaccessible != null) {
      _cachedInaccessibleDirectories = List<DirectoryEntity>.from(inaccessible);
    }
    if (invalid != null) {
      _cachedInvalidDirectories = List<DirectoryEntity>.from(invalid);
    }
  }

  void _resetFilters() {
    _currentSearchQuery = '';
    _currentSelectedTagIds = const <String>[];
    _currentColumns = _ref.read(gridColumnsProvider);
  }

  void _emitFilteredState() {
    final filteredAccessible = _applySearchIfNeeded(
      _filterDirectoriesByTags(
        _cachedAccessibleDirectories,
        _currentSelectedTagIds,
      ),
      _currentSearchQuery,
    );
    final filteredInaccessible = _applySearchIfNeeded(
      _filterDirectoriesByTags(
        _cachedInaccessibleDirectories,
        _currentSelectedTagIds,
      ),
      _currentSearchQuery,
    );
    final filteredInvalid = _applySearchIfNeeded(
      _filterDirectoriesByTags(
        _cachedInvalidDirectories,
        _currentSelectedTagIds,
      ),
      _currentSearchQuery,
    );

    final sortedAccessible = _sortDirectories(filteredAccessible);
    final sortedInaccessible = _sortDirectories(filteredInaccessible);
    final sortedInvalid = _sortDirectories(filteredInvalid);

    _synchronizeSelectionWithCaches();
    final selectionSnapshot = Set<String>.unmodifiable(_selectedDirectoryIds);
    final selectionMode = selectionSnapshot.isNotEmpty && _isSelectionMode;
    _isSelectionMode = selectionMode;

    if (_cachedAccessibleDirectories.isEmpty &&
        _cachedInaccessibleDirectories.isEmpty &&
        _cachedInvalidDirectories.isEmpty) {
      _clearSelectionInternal();
      state = const DirectoryEmpty();
      return;
    }

    if (_cachedInvalidDirectories.isNotEmpty) {
      state = DirectoryBookmarkInvalid(
        invalidDirectories: sortedInvalid,
        accessibleDirectories: sortedAccessible,
        searchQuery: _currentSearchQuery,
        selectedTagIds: _currentSelectedTagIds,
        columns: _currentColumns,
        sortOption: _currentSortOption,
        selectedDirectoryIds: selectionSnapshot,
        isSelectionMode: selectionMode,
      );
      return;
    }

    if (_cachedInaccessibleDirectories.isNotEmpty) {
      state = DirectoryPermissionRevoked(
        inaccessibleDirectories: sortedInaccessible,
        accessibleDirectories: sortedAccessible,
        searchQuery: _currentSearchQuery,
        selectedTagIds: _currentSelectedTagIds,
        columns: _currentColumns,
        sortOption: _currentSortOption,
        selectedDirectoryIds: selectionSnapshot,
        isSelectionMode: selectionMode,
      );
      return;
    }

    state = DirectoryLoaded(
      directories: sortedAccessible,
      searchQuery: _currentSearchQuery,
      selectedTagIds: _currentSelectedTagIds,
      columns: _currentColumns,
      sortOption: _currentSortOption,
      selectedDirectoryIds: selectionSnapshot,
      isSelectionMode: selectionMode,
    );
  }

  List<DirectoryEntity> _applySearchIfNeeded(
    List<DirectoryEntity> directories,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) {
      return directories;
    }
    return _searchDirectoriesUseCase(directories, searchQuery);
  }

  /// Sets the number of columns for the grid.
  void setColumns(int columns) {
    final clampedColumns = columns.clamp(2, 12);
    final newColumns = clampedColumns is int
        ? clampedColumns
        : clampedColumns.toInt();
    _ref.read(gridColumnsProvider.notifier).setColumns(newColumns);
  }

  /// Adds a new directory.
  /// [silent] if true, skips recovery dialogs for bookmark failures (used for drag-and-drop).
  Future<void> addDirectory(String path, {bool silent = false}) async {
    try {
      await _addDirectoryUseCase(path, silent: silent);
      await loadDirectories(); // Reload to show the new directory
    } catch (e) {
      state = DirectoryError(
        ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e)),
      );
    }
  }

  /// Removes a directory.
  Future<void> removeDirectory(String id) async {
    try {
      await _removeDirectoryUseCase(id);
      await loadDirectories(); // Reload to reflect the removal
    } catch (e) {
      state = DirectoryError(e.toString());
    }
  }

  /// Re-grants permissions for a directory by re-adding it.
  /// This is used when a directory becomes inaccessible due to permission revocation.
  Future<void> reGrantDirectoryPermissions(String directoryPath) async {
    try {
      await _addDirectoryUseCase(directoryPath);
      await loadDirectories(); // Reload to show the re-added directory
    } catch (e) {
      state = DirectoryError(
        'Failed to re-grant permissions: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}',
      );
    }
  }

  /// Recovers access to a directory with invalid bookmark by prompting user to re-select.
  Future<void> recoverDirectoryBookmark(
    String directoryId,
    String directoryPath,
  ) async {
    try {
      final recoveryResult = await _permissionService.recoverDirectoryAccess(
        directoryPath,
      );
      if (recoveryResult != null) {
        // Remove the old directory entry
        await _removeDirectoryUseCase(directoryId);
        // Add the new directory with the recovered path
        await _addDirectoryUseCase(recoveryResult.directoryPath);
        await loadDirectories(); // Reload to reflect the changes
      }
    } catch (e) {
      state = DirectoryError(
        'Failed to recover directory access: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}',
      );
    }
  }

  /// Clears all directory cache and stored data.
  Future<void> clearDirectories() async {
    LoggingService.instance.info('Starting directory cache clear operation');
    try {
      LoggingService.instance.debug('Calling clear directories use case');
      await _clearDirectoriesUseCase();
      LoggingService.instance.debug(
        'Clear directories use case completed, reloading directories',
      );
      await loadDirectories(); // Reload to show empty state
      LoggingService.instance.info(
        'Directory cache clear operation completed successfully',
      );
    } catch (e) {
      LoggingService.instance.error('Failed to clear directory cache: $e');
      state = DirectoryError(
        'Failed to clear directory cache: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}',
      );
    }
  }

  /// Helper method to filter directories by tags.
  List<DirectoryEntity> _filterDirectoriesByTags(
    List<DirectoryEntity> directories,
    List<String> tagIds,
  ) {
    LoggingService.instance.debug(
      '_filterDirectoriesByTags called with ${directories.length} directories and tagIds: $tagIds',
    );

    if (tagIds.isEmpty) {
      LoggingService.instance.debug(
        'tagIds is empty, returning all ${directories.length} directories (no filtering)',
      );
      return directories;
    }

    LoggingService.instance.debug('Filtering directories by tags...');
    final filtered = directories
        .where((dir) => dir.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();

    LoggingService.instance.debug(
      'Filtering result: ${filtered.length} directories match out of ${directories.length}',
    );
    LoggingService.instance.debug('Directories that passed filter:');
    for (final dir in filtered) {
      LoggingService.instance.debug(
        '  ${dir.name}: tagIds=${dir.tagIds}, matched tagIds=${tagIds.where((tagId) => dir.tagIds.contains(tagId)).toList()}',
      );
    }

    LoggingService.instance.debug('Directories that were filtered out:');
    final filteredOut = directories
        .where((dir) => !dir.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();
    for (final dir in filteredOut) {
      LoggingService.instance.debug(
        '  ${dir.name}: tagIds=${dir.tagIds}, no match with selected tagIds=$tagIds',
      );
    }

    return filtered;
  }

  /// Helper method to check if a directory is accessible.
  Future<bool> _isDirectoryAccessible(DirectoryEntity directory) async {
    try {
      LoggingService.instance.debug('Validating directory: ${directory.path}');
      final result = await _localDirectoryDataSource.validateDirectory(
        directory,
      );
      LoggingService.instance.debug(
        'Directory validation result for ${directory.path}: $result',
      );
      return result;
    } catch (e) {
      LoggingService.instance.error(
        'Error validating directory ${directory.path}: $e',
      );
      rethrow;
    }
  }

  /// Updates the sort option and reapplies sorting to the current state.
  void changeSortOption(DirectorySortOption option) {
    if (_currentSortOption == option) {
      return;
    }
    _currentSortOption = option;
    _emitFilteredState();
  }

  List<DirectoryEntity> _sortDirectories(List<DirectoryEntity> directories) {
    final sorted = List<DirectoryEntity>.from(directories);
    switch (_currentSortOption) {
      case DirectorySortOption.nameAscending:
        sorted.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case DirectorySortOption.nameDescending:
        sorted.sort(
          (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
        );
        break;
      case DirectorySortOption.lastModifiedDescending:
        sorted.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        break;
      case DirectorySortOption.lastModifiedAscending:
        sorted.sort((a, b) => a.lastModified.compareTo(b.lastModified));
        break;
    }
    return sorted;
  }
}

/// Provider for DirectoryViewModel with auto-dispose.
final directoryViewModelProvider =
    StateNotifierProvider.autoDispose<DirectoryViewModel, DirectoryState>(
      (ref) => DirectoryViewModel(
        ref,
        ref.watch(getDirectoriesUseCaseProvider),
        ref.watch(searchDirectoriesUseCaseProvider),
        ref.watch(addDirectoryUseCaseProvider),
        ref.watch(removeDirectoryUseCaseProvider),
        ref.watch(clearDirectoriesUseCaseProvider),
        ref.watch(localDirectoryDataSourceProvider),
        ref.watch(permissionServiceProvider),
      ),
    );

Set<String> _extractDirectorySelection(DirectoryState state) => switch (state) {
      DirectoryLoaded(selectedDirectoryIds: final ids) => ids,
      DirectoryPermissionRevoked(selectedDirectoryIds: final ids) => ids,
      DirectoryBookmarkInvalid(selectedDirectoryIds: final ids) => ids,
      _ => const <String>{},
    };

bool _extractDirectorySelectionMode(DirectoryState state) => switch (state) {
      DirectoryLoaded(isSelectionMode: final mode) => mode,
      DirectoryPermissionRevoked(isSelectionMode: final mode) => mode,
      DirectoryBookmarkInvalid(isSelectionMode: final mode) => mode,
      _ => false,
    };

/// Provider exposing the current set of selected directory IDs.
final selectedDirectoryIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final state = ref.watch(directoryViewModelProvider);
  return _extractDirectorySelection(state);
});

/// Provider exposing whether selection mode is currently enabled for directories.
final directorySelectionModeProvider = Provider.autoDispose<bool>((ref) {
  final state = ref.watch(directoryViewModelProvider);
  return _extractDirectorySelectionMode(state);
});

/// Provider exposing the current directory selection count.
final selectedDirectoryCountProvider = Provider.autoDispose<int>((ref) {
  final state = ref.watch(directoryViewModelProvider);
  return _extractDirectorySelection(state).length;
});

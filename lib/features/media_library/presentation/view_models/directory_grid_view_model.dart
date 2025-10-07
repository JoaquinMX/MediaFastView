import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/error_handler.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../data/data_sources/local_directory_data_source.dart';
import '../../domain/entities/directory_entity.dart';
import '../../domain/use_cases/add_directory_use_case.dart';
import '../../domain/use_cases/clear_directories_use_case.dart';
import '../../domain/use_cases/get_directories_use_case.dart';
import '../../domain/use_cases/remove_directory_use_case.dart';
import '../../domain/use_cases/search_directories_use_case.dart';

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
  });

  final List<DirectoryEntity> directories;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;

  DirectoryLoaded copyWith({
    List<DirectoryEntity>? directories,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
  }) {
    return DirectoryLoaded(
      directories: directories ?? this.directories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
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
  });

  final List<DirectoryEntity> inaccessibleDirectories;
  final List<DirectoryEntity> accessibleDirectories;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;

  DirectoryPermissionRevoked copyWith({
    List<DirectoryEntity>? inaccessibleDirectories,
    List<DirectoryEntity>? accessibleDirectories,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
  }) {
    return DirectoryPermissionRevoked(
      inaccessibleDirectories: inaccessibleDirectories ?? this.inaccessibleDirectories,
      accessibleDirectories: accessibleDirectories ?? this.accessibleDirectories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
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
  });

  final List<DirectoryEntity> invalidDirectories;
  final List<DirectoryEntity> accessibleDirectories;
  final String searchQuery;
  final List<String> selectedTagIds;
  final int columns;

  DirectoryBookmarkInvalid copyWith({
    List<DirectoryEntity>? invalidDirectories,
    List<DirectoryEntity>? accessibleDirectories,
    String? searchQuery,
    List<String>? selectedTagIds,
    int? columns,
  }) {
    return DirectoryBookmarkInvalid(
      invalidDirectories: invalidDirectories ?? this.invalidDirectories,
      accessibleDirectories: accessibleDirectories ?? this.accessibleDirectories,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      columns: columns ?? this.columns,
    );
  }
}

/// ViewModel for managing directory grid state and operations.
class DirectoryViewModel extends StateNotifier<DirectoryState> {
  DirectoryViewModel(
    this._getDirectoriesUseCase,
    this._searchDirectoriesUseCase,
    this._addDirectoryUseCase,
    this._removeDirectoryUseCase,
    this._clearDirectoriesUseCase,
    this._localDirectoryDataSource,
    this._permissionService,
  ) : super(const DirectoryLoading()) {
    loadDirectories();
  }

  final GetDirectoriesUseCase _getDirectoriesUseCase;
  final SearchDirectoriesUseCase _searchDirectoriesUseCase;
  final AddDirectoryUseCase _addDirectoryUseCase;
  final RemoveDirectoryUseCase _removeDirectoryUseCase;
  final ClearDirectoriesUseCase _clearDirectoriesUseCase;
  final LocalDirectoryDataSource _localDirectoryDataSource;
  final PermissionService _permissionService;

  /// Loads all directories.
  Future<void> loadDirectories() async {
    LoggingService.instance.debug('Starting loadDirectories operation');
    state = const DirectoryLoading();
    try {
      LoggingService.instance.debug('Fetching directories from use case');
      final directories = await _getDirectoriesUseCase();
      LoggingService.instance.debug('Retrieved ${directories.length} directories from use case');

      // Separate accessible and inaccessible directories
      final accessibleDirectories = <DirectoryEntity>[];
      final inaccessibleDirectories = <DirectoryEntity>[];

      LoggingService.instance.debug('Checking directory accessibility for ${directories.length} directories');
      for (final directory in directories) {
        try {
          if (await _isDirectoryAccessible(directory)) {
            accessibleDirectories.add(directory);
            LoggingService.instance.debug('Directory ${directory.path} is accessible');
          } else {
            inaccessibleDirectories.add(directory);
            LoggingService.instance.debug('Directory ${directory.path} is not accessible');
          }
        } catch (e) {
          LoggingService.instance.warning('Error checking accessibility for directory ${directory.path}: $e');
          inaccessibleDirectories.add(directory);
        }
      }

      LoggingService.instance.debug('Accessibility check complete: ${accessibleDirectories.length} accessible, ${inaccessibleDirectories.length} inaccessible');

      if (accessibleDirectories.isEmpty && inaccessibleDirectories.isEmpty) {
        LoggingService.instance.info('Setting state to DirectoryEmpty');
        state = const DirectoryEmpty();
      } else if (accessibleDirectories.isNotEmpty && inaccessibleDirectories.isEmpty) {
        // All directories are accessible
        LoggingService.instance.info('Setting state to DirectoryLoaded with ${accessibleDirectories.length} directories');
        LoggingService.instance.debug('Directory details:');
        for (final dir in accessibleDirectories) {
          LoggingService.instance.debug('  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}');
        }
        state = DirectoryLoaded(
          directories: accessibleDirectories,
          searchQuery: '',
          selectedTagIds: const [],
          columns: 3, // Default to 3 columns
        );
      } else {
        // Some directories are inaccessible
        LoggingService.instance.info('Setting state to DirectoryPermissionRevoked: ${accessibleDirectories.length} accessible, ${inaccessibleDirectories.length} inaccessible');
        LoggingService.instance.debug('Accessible directory details:');
        for (final dir in accessibleDirectories) {
          LoggingService.instance.debug('  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}');
        }
        LoggingService.instance.debug('Inaccessible directory details:');
        for (final dir in inaccessibleDirectories) {
          LoggingService.instance.debug('  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}');
        }
        state = DirectoryPermissionRevoked(
          inaccessibleDirectories: inaccessibleDirectories,
          accessibleDirectories: accessibleDirectories,
          searchQuery: '',
          selectedTagIds: const [],
          columns: 3, // Default to 3 columns
        );
      }
    } catch (e) {
      LoggingService.instance.error('Error in loadDirectories: $e');
      if (e is BookmarkInvalidError) {
        LoggingService.instance.info('Handling BookmarkInvalidError for directory ${e.directoryPath}');
        // Set to bookmark invalid state
        state = DirectoryBookmarkInvalid(
          invalidDirectories: [DirectoryEntity(
            id: e.directoryId,
            path: e.directoryPath,
            name: e.directoryPath.split('/').last,
            thumbnailPath: null,
            tagIds: const [],
            lastModified: DateTime.now(),
            bookmarkData: null,
          )],
          accessibleDirectories: const [],
          searchQuery: '',
          selectedTagIds: const [],
          columns: 3,
        );
      } else {
        LoggingService.instance.error('Setting state to DirectoryError: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}');
        state = DirectoryError(ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e)));
      }
    }
  }

  /// Searches directories by query.
  void searchDirectories(String query) {
    state = switch (state) {
      DirectoryLoaded(
        :final directories,
        :final selectedTagIds,
        :final columns,
      ) =>
        DirectoryLoaded(
          directories: _searchDirectoriesUseCase(directories, query),
          searchQuery: query,
          selectedTagIds: selectedTagIds,
          columns: columns,
        ),
      DirectoryPermissionRevoked(
        :final inaccessibleDirectories,
        :final accessibleDirectories,
        :final selectedTagIds,
        :final columns,
      ) =>
        DirectoryPermissionRevoked(
          inaccessibleDirectories: _searchDirectoriesUseCase(inaccessibleDirectories, query),
          accessibleDirectories: _searchDirectoriesUseCase(accessibleDirectories, query),
          searchQuery: query,
          selectedTagIds: selectedTagIds,
          columns: columns,
        ),
      _ => state,
    };
  }

  /// Filters directories by tag IDs.
  void filterByTags(List<String> tagIds) {
    LoggingService.instance.info('filterByTags called with tagIds: $tagIds');
    LoggingService.instance.debug('Current state type: ${state.runtimeType}');

    final filteredState = switch (state) {
      DirectoryLoaded(:final directories, :final searchQuery, :final columns) => () {
        LoggingService.instance.debug('Filtering DirectoryLoaded state with ${directories.length} directories');
        final filteredDirectories = _filterDirectoriesByTags(directories, tagIds);
        LoggingService.instance.info('Filtered directories: ${filteredDirectories.length} out of ${directories.length}');
        LoggingService.instance.debug('Filtered directory details:');
        for (final dir in filteredDirectories) {
          LoggingService.instance.debug('  Directory: ${dir.name} (id: ${dir.id}), tagIds: ${dir.tagIds}');
        }
        return DirectoryLoaded(
          directories: filteredDirectories,
          searchQuery: searchQuery,
          selectedTagIds: tagIds,
          columns: columns,
        );
      }(),
      DirectoryPermissionRevoked(
        :final inaccessibleDirectories,
        :final accessibleDirectories,
        :final searchQuery,
        :final columns,
      ) => () {
        LoggingService.instance.debug('Filtering DirectoryPermissionRevoked state');
        LoggingService.instance.debug('  Accessible directories: ${accessibleDirectories.length}');
        LoggingService.instance.debug('  Inaccessible directories: ${inaccessibleDirectories.length}');
        final filteredAccessible = _filterDirectoriesByTags(accessibleDirectories, tagIds);
        final filteredInaccessible = _filterDirectoriesByTags(inaccessibleDirectories, tagIds);
        LoggingService.instance.info('Filtered accessible: ${filteredAccessible.length}/${accessibleDirectories.length}, inaccessible: ${filteredInaccessible.length}/${inaccessibleDirectories.length}');
        return DirectoryPermissionRevoked(
          inaccessibleDirectories: filteredInaccessible,
          accessibleDirectories: filteredAccessible,
          searchQuery: searchQuery,
          selectedTagIds: tagIds,
          columns: columns,
        );
      }(),
      DirectoryBookmarkInvalid(
        :final invalidDirectories,
        :final accessibleDirectories,
        :final searchQuery,
        :final columns,
      ) => () {
        LoggingService.instance.debug('Filtering DirectoryBookmarkInvalid state');
        LoggingService.instance.debug('  Accessible directories: ${accessibleDirectories.length}');
        LoggingService.instance.debug('  Invalid directories: ${invalidDirectories.length}');
        final filteredAccessible = _filterDirectoriesByTags(accessibleDirectories, tagIds);
        final filteredInvalid = _filterDirectoriesByTags(invalidDirectories, tagIds);
        LoggingService.instance.info('Filtered accessible: ${filteredAccessible.length}/${accessibleDirectories.length}, invalid: ${filteredInvalid.length}/${invalidDirectories.length}');
        return DirectoryBookmarkInvalid(
          invalidDirectories: filteredInvalid,
          accessibleDirectories: filteredAccessible,
          searchQuery: searchQuery,
          selectedTagIds: tagIds,
          columns: columns,
        );
      }(),
      _ => () {
        LoggingService.instance.warning('filterByTags called on unsupported state: ${state.runtimeType}');
        return state;
      }(),
    };

    state = filteredState;
    LoggingService.instance.info('filterByTags completed. New selectedTagIds: $tagIds');
  }

  /// Sets the number of columns for the grid.
  void setColumns(int columns) {
    state = switch (state) {
      DirectoryLoaded(
        :final directories,
        :final searchQuery,
        :final selectedTagIds,
      ) =>
        DirectoryLoaded(
          directories: directories,
          searchQuery: searchQuery,
          selectedTagIds: selectedTagIds,
          columns: columns,
        ),
      DirectoryPermissionRevoked(
        :final inaccessibleDirectories,
        :final accessibleDirectories,
        :final searchQuery,
        :final selectedTagIds,
      ) =>
        DirectoryPermissionRevoked(
          inaccessibleDirectories: inaccessibleDirectories,
          accessibleDirectories: accessibleDirectories,
          searchQuery: searchQuery,
          selectedTagIds: selectedTagIds,
          columns: columns,
        ),
      _ => state,
    };
  }

  /// Adds a new directory.
  /// [silent] if true, skips recovery dialogs for bookmark failures (used for drag-and-drop).
  Future<void> addDirectory(String path, {bool silent = false}) async {
    try {
      await _addDirectoryUseCase(path, silent: silent);
      await loadDirectories(); // Reload to show the new directory
    } catch (e) {
      state = DirectoryError(ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e)));
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
      state = DirectoryError('Failed to re-grant permissions: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}');
    }
  }

  /// Recovers access to a directory with invalid bookmark by prompting user to re-select.
  Future<void> recoverDirectoryBookmark(String directoryId, String directoryPath) async {
    try {
      final recoveryResult = await _permissionService.recoverDirectoryAccess(directoryPath);
      if (recoveryResult != null) {
        // Remove the old directory entry
        await _removeDirectoryUseCase(directoryId);
        // Add the new directory with the recovered path
        await _addDirectoryUseCase(recoveryResult.directoryPath);
        await loadDirectories(); // Reload to reflect the changes
      }
    } catch (e) {
      state = DirectoryError('Failed to recover directory access: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}');
    }
  }

  /// Clears all directory cache and stored data.
  Future<void> clearDirectories() async {
    LoggingService.instance.info('Starting directory cache clear operation');
    try {
      LoggingService.instance.debug('Calling clear directories use case');
      await _clearDirectoriesUseCase();
      LoggingService.instance.debug('Clear directories use case completed, reloading directories');
      await loadDirectories(); // Reload to show empty state
      LoggingService.instance.info('Directory cache clear operation completed successfully');
    } catch (e) {
      LoggingService.instance.error('Failed to clear directory cache: $e');
      state = DirectoryError('Failed to clear directory cache: ${ErrorHandler.getErrorMessage(ErrorHandler.toAppError(e))}');
    }
  }

  /// Helper method to filter directories by tags.
  List<DirectoryEntity> _filterDirectoriesByTags(
    List<DirectoryEntity> directories,
    List<String> tagIds,
  ) {
    LoggingService.instance.debug('_filterDirectoriesByTags called with ${directories.length} directories and tagIds: $tagIds');

    if (tagIds.isEmpty) {
      LoggingService.instance.debug('tagIds is empty, returning all ${directories.length} directories (no filtering)');
      return directories;
    }

    LoggingService.instance.debug('Filtering directories by tags...');
    final filtered = directories
        .where((dir) => dir.tagIds.any((tagId) => tagIds.contains(tagId)))
        .toList();

    LoggingService.instance.debug('Filtering result: ${filtered.length} directories match out of ${directories.length}');
    LoggingService.instance.debug('Directories that passed filter:');
    for (final dir in filtered) {
      LoggingService.instance.debug('  ${dir.name}: tagIds=${dir.tagIds}, matched tagIds=${tagIds.where((tagId) => dir.tagIds.contains(tagId)).toList()}');
    }

    LoggingService.instance.debug('Directories that were filtered out:');
    final filteredOut = directories.where((dir) => !dir.tagIds.any((tagId) => tagIds.contains(tagId))).toList();
    for (final dir in filteredOut) {
      LoggingService.instance.debug('  ${dir.name}: tagIds=${dir.tagIds}, no match with selected tagIds=$tagIds');
    }

    return filtered;
  }

  /// Helper method to check if a directory is accessible.
  Future<bool> _isDirectoryAccessible(DirectoryEntity directory) async {
    try {
      LoggingService.instance.debug('Validating directory: ${directory.path}');
      final result = await _localDirectoryDataSource.validateDirectory(directory);
      LoggingService.instance.debug('Directory validation result for ${directory.path}: $result');
      return result;
    } catch (e) {
      LoggingService.instance.error('Error validating directory ${directory.path}: $e');
      rethrow;
    }
  }
}

/// Provider for DirectoryViewModel with auto-dispose.
final directoryViewModelProvider =
    StateNotifierProvider.autoDispose<DirectoryViewModel, DirectoryState>(
      (ref) => DirectoryViewModel(
        ref.watch(getDirectoriesUseCaseProvider),
        ref.watch(searchDirectoriesUseCaseProvider),
        ref.watch(addDirectoryUseCaseProvider),
        ref.watch(removeDirectoryUseCaseProvider),
        ref.watch(clearDirectoriesUseCaseProvider),
        ref.watch(localDirectoryDataSourceProvider),
        ref.watch(permissionServiceProvider),
      ),
    );

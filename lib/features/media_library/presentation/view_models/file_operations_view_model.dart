import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/entities/file_rename_request.dart';
import '../../domain/entities/trashed_item_entity.dart';
import '../../domain/use_cases/bulk_rename_use_case.dart';
import '../../domain/use_cases/delete_directory_use_case.dart';
import '../../domain/use_cases/delete_file_use_case.dart';
import '../../domain/use_cases/move_to_folder_use_case.dart';
import '../../domain/use_cases/move_to_trash_use_case.dart';
import '../../domain/use_cases/restore_from_trash_use_case.dart';
import '../../domain/use_cases/validate_path_use_case.dart';

/// State for file operations
sealed class FileOperationsState {
  const FileOperationsState();
}

class FileOperationsInitial extends FileOperationsState {
  const FileOperationsInitial();
}

class FileOperationsLoading extends FileOperationsState {
  const FileOperationsLoading();
}

class FileOperationsSuccess extends FileOperationsState {
  const FileOperationsSuccess(this.message);

  final String message;
}

class FileOperationsError extends FileOperationsState {
  const FileOperationsError(this.message);

  final String message;
}

/// ViewModel for file operations
class FileOperationsViewModel extends StateNotifier<FileOperationsState> {
  FileOperationsViewModel(
    this._deleteFileUseCase,
    this._deleteDirectoryUseCase,
    this._validatePathUseCase,
    this._bulkRenameUseCase,
    this._moveToFolderUseCase,
    this._moveToTrashUseCase,
    this._restoreFromTrashUseCase,
  ) : super(const FileOperationsInitial());

  final DeleteFileUseCase _deleteFileUseCase;
  final DeleteDirectoryUseCase _deleteDirectoryUseCase;
  final ValidatePathUseCase _validatePathUseCase;
  final BulkRenameUseCase _bulkRenameUseCase;
  final MoveToFolderUseCase _moveToFolderUseCase;
  final MoveToTrashUseCase _moveToTrashUseCase;
  final RestoreFromTrashUseCase _restoreFromTrashUseCase;

  /// Deletes a file
  Future<void> deleteFile(String filePath, {String? bookmarkData}) async {
    state = const FileOperationsLoading();
    try {
      await _deleteFileUseCase(filePath, bookmarkData: bookmarkData);
      state = FileOperationsSuccess('File deleted successfully');
    } catch (e) {
      state = FileOperationsError(e.toString());
    }
  }

  /// Deletes a directory recursively
  Future<void> deleteDirectory(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    state = const FileOperationsLoading();
    try {
      await _deleteDirectoryUseCase(
        directoryPath,
        bookmarkData: bookmarkData,
      );
      state = FileOperationsSuccess('Directory deleted successfully');
    } catch (e) {
      state = FileOperationsError(e.toString());
    }
  }

  /// Validates if a path is accessible
  Future<bool> validatePath(String path) async {
    try {
      return await _validatePathUseCase(path);
    } catch (e) {
      return false;
    }
  }

  /// Renames multiple files or directories.
  Future<List<String>> bulkRename(
    List<FileRenameRequest> requests, {
    Map<String, String?>? bookmarkDataMap,
  }) async {
    if (requests.isEmpty) {
      return const [];
    }
    state = const FileOperationsLoading();
    try {
      final result = await _bulkRenameUseCase(
        requests,
        bookmarkDataMap: bookmarkDataMap,
      );
      state = FileOperationsSuccess('Renamed ${result.length} item(s)');
      return result;
    } catch (e) {
      state = FileOperationsError(e.toString());
      rethrow;
    }
  }

  /// Moves items to a destination folder.
  Future<List<String>> moveToFolder(
    List<String> paths,
    String destinationDirectory, {
    Map<String, String?>? bookmarkDataMap,
    bool createIfMissing = true,
  }) async {
    if (paths.isEmpty) {
      return const [];
    }
    state = const FileOperationsLoading();
    try {
      final result = await _moveToFolderUseCase(
        paths,
        destinationDirectory,
        bookmarkDataMap: bookmarkDataMap,
        createIfMissing: createIfMissing,
      );
      state = FileOperationsSuccess('Moved ${result.length} item(s)');
      return result;
    } catch (e) {
      state = FileOperationsError(e.toString());
      rethrow;
    }
  }

  /// Moves items to the reversible trash.
  Future<List<TrashedItemEntity>> moveToTrash(
    List<String> paths, {
    Map<String, String?>? bookmarkDataMap,
    String? trashDirectory,
  }) async {
    if (paths.isEmpty) {
      return const [];
    }
    state = const FileOperationsLoading();
    try {
      final result = await _moveToTrashUseCase(
        paths,
        bookmarkDataMap: bookmarkDataMap,
        trashDirectory: trashDirectory,
      );
      state = FileOperationsSuccess('Trashed ${result.length} item(s)');
      return result;
    } catch (e) {
      state = FileOperationsError(e.toString());
      rethrow;
    }
  }

  /// Restores items from the reversible trash.
  Future<void> restoreFromTrash(
    List<TrashedItemEntity> items, {
    Map<String, String?>? bookmarkDataMap,
  }) async {
    if (items.isEmpty) {
      return;
    }
    state = const FileOperationsLoading();
    try {
      await _restoreFromTrashUseCase(
        items,
        bookmarkDataMap: bookmarkDataMap,
      );
      state = FileOperationsSuccess('Restored ${items.length} item(s)');
    } catch (e) {
      state = FileOperationsError(e.toString());
      rethrow;
    }
  }

  /// Resets the state to initial
  void reset() {
    state = const FileOperationsInitial();
  }
}

/// Provider for FileOperationsViewModel with auto-dispose
final fileOperationsViewModelProvider =
    StateNotifierProvider.autoDispose<
      FileOperationsViewModel,
      FileOperationsState
    >(
      (ref) => FileOperationsViewModel(
        ref.watch(deleteFileUseCaseProvider),
        ref.watch(deleteDirectoryUseCaseProvider),
        ref.watch(validatePathUseCaseProvider),
        ref.watch(bulkRenameUseCaseProvider),
        ref.watch(moveToFolderUseCaseProvider),
        ref.watch(moveToTrashUseCaseProvider),
        ref.watch(restoreFromTrashUseCaseProvider),
      ),
    );

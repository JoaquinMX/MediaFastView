import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../domain/use_cases/delete_directory_use_case.dart';
import '../../domain/use_cases/delete_file_use_case.dart';
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
  ) : super(const FileOperationsInitial());

  final DeleteFileUseCase _deleteFileUseCase;
  final DeleteDirectoryUseCase _deleteDirectoryUseCase;
  final ValidatePathUseCase _validatePathUseCase;

  /// Deletes a file
  Future<void> deleteFile(
    String filePath, {
    required bool deleteFromSource,
  }) async {
    if (!deleteFromSource) {
      _emitState(
        const FileOperationsError(
          'Delete from source is disabled in settings.',
        ),
      );
      return;
    }

    _emitState(const FileOperationsLoading());
    try {
      await _deleteFileUseCase(filePath);
      _emitState(const FileOperationsSuccess('File deleted successfully'));
    } catch (e) {
      _emitState(FileOperationsError(e.toString()));
    }
  }

  /// Deletes a directory recursively
  Future<void> deleteDirectory(
    String directoryPath, {
    required bool deleteFromSource,
  }) async {
    if (!deleteFromSource) {
      _emitState(
        const FileOperationsError(
          'Delete from source is disabled in settings.',
        ),
      );
      return;
    }

    _emitState(const FileOperationsLoading());
    try {
      await _deleteDirectoryUseCase(directoryPath);
      _emitState(
        const FileOperationsSuccess('Directory deleted successfully'),
      );
    } catch (e) {
      _emitState(FileOperationsError(e.toString()));
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

  /// Resets the state to initial
  void reset() {
    _emitState(const FileOperationsInitial());
  }

  void _emitState(FileOperationsState newState) {
    if (!mounted) {
      return;
    }
    state = newState;
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
      ),
    );

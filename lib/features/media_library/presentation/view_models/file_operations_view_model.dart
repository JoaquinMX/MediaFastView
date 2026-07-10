import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/services/logging_service.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../domain/entities/directory_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/directory_repository.dart';
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
    this._directoryRepository,
    this._favoritesRepository,
  ) : super(const FileOperationsInitial());

  final DeleteFileUseCase _deleteFileUseCase;
  final DeleteDirectoryUseCase _deleteDirectoryUseCase;
  final ValidatePathUseCase _validatePathUseCase;
  final DirectoryRepository _directoryRepository;
  final FavoritesRepository _favoritesRepository;

  static const String _unsupportedMessage =
      'Deleting files from the device is only supported on macOS.';

  /// Moves a media item (file or directory) to the Trash.
  Future<void> deleteMedia(
    MediaEntity media, {
    required bool deleteFromSource,
  }) async {
    if (media.type == MediaType.directory) {
      await _delete(
        media,
        deleteFromSource: deleteFromSource,
        successMessage: 'Directory moved to Trash',
        action: (path, bookmarkData) =>
            _deleteDirectoryUseCase(path, bookmarkData: bookmarkData),
      );
    } else {
      await _delete(
        media,
        deleteFromSource: deleteFromSource,
        successMessage: 'Moved to Trash',
        action: (path, bookmarkData) =>
            _deleteFileUseCase(path, bookmarkData: bookmarkData),
      );
    }
  }

  Future<void> _delete(
    MediaEntity media, {
    required bool deleteFromSource,
    required String successMessage,
    required Future<void> Function(String path, String? bookmarkData) action,
  }) async {
    if (!deleteFromSource) {
      state = const FileOperationsError(
        'Delete from source is disabled in settings.',
      );
      return;
    }

    if (!Platform.isMacOS) {
      state = const FileOperationsError(_unsupportedMessage);
      return;
    }

    state = const FileOperationsLoading();
    try {
      final bookmarkData = await _resolveDirectoryBookmark(media);
      await action(media.path, bookmarkData);
      await _cleanupAfterDelete(media);
      state = FileOperationsSuccess(successMessage);
    } catch (e) {
      state = FileOperationsError(e.toString());
    }
  }

  /// Resolves the security-scoped bookmark that grants sandboxed write access
  /// to [media]'s location.
  ///
  /// Prefers the tracked directory referenced by [MediaEntity.directoryId]
  /// (the common case for files and root directories). For nested items whose
  /// directory isn't tracked directly (e.g. a subdirectory being deleted), it
  /// falls back to the deepest tracked library root that contains the path,
  /// whose bookmark also covers descendants.
  Future<String?> _resolveDirectoryBookmark(MediaEntity media) async {
    final direct = await _directoryRepository.getDirectoryById(
      media.directoryId,
    );
    if (direct?.bookmarkData != null) {
      return direct!.bookmarkData;
    }

    final directories = await _directoryRepository.getDirectories();
    DirectoryEntity? enclosing;
    for (final dir in directories) {
      if (dir.bookmarkData == null) continue;
      final coversPath =
          media.path == dir.path || p.isWithin(dir.path, media.path);
      if (!coversPath) continue;
      if (enclosing == null || dir.path.length > enclosing.path.length) {
        enclosing = dir;
      }
    }

    return enclosing?.bookmarkData ?? media.bookmarkData;
  }

  /// Removes state that would otherwise be orphaned once the underlying file is
  /// gone (the favorites collection is keyed by media id and is not touched by
  /// a directory rescan).
  Future<void> _cleanupAfterDelete(MediaEntity media) async {
    try {
      if (await _favoritesRepository.isFavorite(media.id)) {
        await _favoritesRepository.removeFavorite(media.id);
      }
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to clean up favorite for deleted media ${media.id}: $e',
      );
      // Non-fatal: the delete itself succeeded.
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
        ref.watch(directoryRepositoryProvider),
        ref.watch(favoritesRepositoryProvider),
      ),
    );

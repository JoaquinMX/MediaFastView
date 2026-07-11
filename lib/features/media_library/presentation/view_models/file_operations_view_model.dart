import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/app_error.dart';
import '../../../../core/services/file_transfer_result.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../core/utils/batch_update_result.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/utils/bookmark_resolver.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../data/isar/isar_media_data_source.dart';
import '../../domain/entities/directory_entity.dart';
import '../../domain/entities/media_entity.dart';
import '../../domain/repositories/directory_repository.dart';
import '../../domain/use_cases/delete_directory_use_case.dart';
import '../../domain/use_cases/delete_file_use_case.dart';
import '../../domain/use_cases/reconcile_transferred_media_use_case.dart';
import '../../domain/use_cases/transfer_media_use_case.dart';
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

/// A transfer stopped because the destination name is already taken.
///
/// [suggestedPath] is the name the item would take under "keep both", so the
/// prompt can show the exact result before the user commits to it.
class FileOperationsConflict extends FileOperationsState {
  const FileOperationsConflict({
    required this.media,
    required this.destinationPath,
    required this.suggestedPath,
  });

  final MediaEntity media;
  final String destinationPath;
  final String suggestedPath;
}

/// A move or copy that landed, carrying the item as it now exists.
class FileOperationsTransferSuccess extends FileOperationsSuccess {
  const FileOperationsTransferSuccess(
    super.message, {
    required this.media,
    required this.transfer,
  });

  /// The item at its destination, after the cache was reconciled.
  final MediaEntity media;
  final FileTransferResult transfer;
}

/// ViewModel for file operations
class FileOperationsViewModel extends StateNotifier<FileOperationsState> {
  FileOperationsViewModel(
    this._deleteFileUseCase,
    this._deleteDirectoryUseCase,
    this._validatePathUseCase,
    this._directoryRepository,
    this._favoritesRepository,
    this._moveMediaUseCase,
    this._copyMediaUseCase,
    this._reconcileUseCase,
    this._mediaDataSource,
  ) : super(const FileOperationsInitial());

  final DeleteFileUseCase _deleteFileUseCase;
  final DeleteDirectoryUseCase _deleteDirectoryUseCase;
  final ValidatePathUseCase _validatePathUseCase;
  final DirectoryRepository _directoryRepository;
  final FavoritesRepository _favoritesRepository;
  final MoveMediaUseCase _moveMediaUseCase;
  final CopyMediaUseCase _copyMediaUseCase;
  final ReconcileTransferredMediaUseCase _reconcileUseCase;
  final IsarMediaDataSource _mediaDataSource;

  static const String _unsupportedMessage =
      'Deleting files from the device is only supported on macOS.';

  static const String _unsupportedTransferMessage =
      'Moving and copying files is only supported on macOS.';

  /// Moves or copies [media] into [destinationDirectoryPath].
  ///
  /// The cache is reconciled before this returns, so callers are free to
  /// invalidate providers immediately afterwards without losing the item's tags.
  Future<void> transferMedia(
    MediaEntity media, {
    required String destinationDirectoryPath,
    required TransferMode mode,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) async {
    if (!Platform.isMacOS) {
      state = const FileOperationsError(_unsupportedTransferMessage);
      return;
    }

    state = const FileOperationsLoading();
    try {
      final sourceBookmark = await _resolveDirectoryBookmark(media);
      final destinationBookmark =
          destinationBookmarkData ??
          await _resolveBookmarkForPath(destinationDirectoryPath);

      // Without a bookmark covering the destination the sandbox will refuse the
      // write. Say so plainly rather than letting it fail as a permission error.
      if (destinationBookmark == null) {
        state = const FileOperationsError(
          'This app has no access to that folder. Pick it with "Choose Folder…" '
          'to grant access.',
        );
        return;
      }

      final isMove = mode == TransferMode.move;
      final transfer = isMove
          ? await _moveMediaUseCase(
              media.path,
              destinationDirectoryPath: destinationDirectoryPath,
              sourceBookmarkData: sourceBookmark,
              destinationBookmarkData: destinationBookmark,
              conflictStrategy: conflictStrategy,
            )
          : await _copyMediaUseCase(
              media.path,
              destinationDirectoryPath: destinationDirectoryPath,
              sourceBookmarkData: sourceBookmark,
              destinationBookmarkData: destinationBookmark,
              conflictStrategy: conflictStrategy,
            );

      final reconciled = await _reconcileUseCase(
        source: media,
        transfer: transfer,
        destinationDirectoryPath: destinationDirectoryPath,
        mode: mode,
        destinationBookmarkData: destinationBookmark,
      );

      final destinationName = p.basename(destinationDirectoryPath);
      state = FileOperationsTransferSuccess(
        '${isMove ? 'Moved' : 'Copied'} to $destinationName',
        media: reconciled.media,
        transfer: transfer,
      );
    } on DestinationExistsError catch (e) {
      state = FileOperationsConflict(
        media: media,
        destinationPath: e.destinationPath,
        suggestedPath: e.suggestedPath,
      );
    } catch (e) {
      state = FileOperationsError(e.toString());
    }
  }

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

  /// Moves several media items (files and/or directories) to the Trash.
  ///
  /// Items nested inside another selected directory are not deleted
  /// individually — they go to the Trash with their parent — but they are still
  /// reported as successful and still get their orphaned state cleaned up.
  ///
  /// [onProgress] reports `(completed, total)` after every item so callers can
  /// drive a determinate progress indicator. Deletes run sequentially because
  /// the native Trash call blocks the platform thread.
  Future<BatchUpdateResult> deleteMediaBatch(
    List<MediaEntity> items, {
    required bool deleteFromSource,
    void Function(int completed, int total)? onProgress,
  }) async {
    if (items.isEmpty) {
      return BatchUpdateResult.empty;
    }

    final blockedReason = _deleteBlockedReason(deleteFromSource);
    if (blockedReason != null) {
      state = FileOperationsError(blockedReason);
      return BatchUpdateResult(
        failureReasons: {
          for (final item in items) item.id: blockedReason,
        },
      );
    }

    state = const FileOperationsLoading();

    final coveredByParent = <MediaEntity>[];
    final roots = <MediaEntity>[];
    for (final item in items) {
      if (_isCoveredBySelectedDirectory(item, items)) {
        coveredByParent.add(item);
      } else {
        roots.add(item);
      }
    }

    // Read the tracked directories once for the whole batch instead of per
    // item. Without them the items can still fall back to their own bookmark,
    // so a lookup failure degrades rather than aborting the delete.
    List<DirectoryEntity> directories;
    try {
      directories = await _directoryRepository.getDirectories();
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to load directories while resolving delete bookmarks: $e',
      );
      directories = const [];
    }

    final successfulIds = <String>[];
    final failureReasons = <String, String>{};
    final deletedItems = <MediaEntity>[];
    final trashedDirectoryPaths = <String>[];

    var completed = 0;
    for (final item in roots) {
      try {
        final bookmarkData = _resolveBookmarkFrom(item, directories);
        if (item.type == MediaType.directory) {
          await _deleteDirectoryUseCase(item.path, bookmarkData: bookmarkData);
          trashedDirectoryPaths.add(item.path);
        } else {
          await _deleteFileUseCase(item.path, bookmarkData: bookmarkData);
        }
        successfulIds.add(item.id);
        deletedItems.add(item);
      } catch (e) {
        failureReasons[item.id] = e.toString();
      }
      completed++;
      onProgress?.call(completed, roots.length);
    }

    // A nested item is only gone if the parent that covers it was actually
    // trashed; a parent whose delete failed leaves its contents in place.
    for (final item in coveredByParent) {
      final parentTrashed = trashedDirectoryPaths.any(
        (dirPath) => p.isWithin(dirPath, item.path),
      );
      if (parentTrashed) {
        successfulIds.add(item.id);
        deletedItems.add(item);
      } else {
        failureReasons[item.id] =
            'The enclosing directory could not be moved to Trash.';
      }
    }

    for (final item in deletedItems) {
      await _cleanupAfterDelete(item);
    }

    final result = BatchUpdateResult(
      successfulIds: successfulIds,
      failureReasons: failureReasons,
    );

    final summary = _batchSummary(result);
    state = result.hasSuccesses
        ? FileOperationsSuccess(summary)
        : FileOperationsError(summary);

    return result;
  }

  /// Whether [item] lives inside a different directory that is also being
  /// deleted, in which case trashing the parent already removes it.
  bool _isCoveredBySelectedDirectory(
    MediaEntity item,
    List<MediaEntity> selection,
  ) {
    return selection.any(
      (other) =>
          other.type == MediaType.directory &&
          other.path != item.path &&
          p.isWithin(other.path, item.path),
    );
  }

  String _batchSummary(BatchUpdateResult result) {
    final moved = result.successfulIds.length;
    final failed = result.failureReasons.length;

    if (moved == 0) {
      return 'Failed to move $failed item${failed == 1 ? '' : 's'} to Trash';
    }

    final movedText = 'Moved $moved item${moved == 1 ? '' : 's'} to Trash';
    return failed == 0 ? movedText : '$movedText, $failed failed';
  }

  /// Returns the reason deleting is not allowed right now, or `null` when it is.
  String? _deleteBlockedReason(bool deleteFromSource) {
    if (!deleteFromSource) {
      return 'Delete from source is disabled in settings.';
    }
    if (!Platform.isMacOS) {
      return _unsupportedMessage;
    }
    return null;
  }

  Future<void> _delete(
    MediaEntity media, {
    required bool deleteFromSource,
    required String successMessage,
    required Future<void> Function(String path, String? bookmarkData) action,
  }) async {
    final blockedReason = _deleteBlockedReason(deleteFromSource);
    if (blockedReason != null) {
      state = FileOperationsError(blockedReason);
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
    return _resolveBookmarkFrom(media, directories);
  }

  /// Finds the bookmark granting sandboxed access to an arbitrary [path].
  ///
  /// A transfer's destination has no [MediaEntity] to look up by directory id,
  /// so this goes straight to the deepest tracked root containing the path —
  /// whose bookmark also covers everything beneath it.
  Future<String?> _resolveBookmarkForPath(String path) async {
    final directories = await _directoryRepository.getDirectories();
    return resolveBookmarkForPath(path, directories);
  }

  /// Same resolution as [_resolveDirectoryBookmark] against an already-loaded
  /// directory list, so a batch reads the directories once instead of per item.
  String? _resolveBookmarkFrom(
    MediaEntity media,
    List<DirectoryEntity> directories,
  ) {
    for (final dir in directories) {
      if (dir.id == media.directoryId && dir.bookmarkData != null) {
        return dir.bookmarkData;
      }
    }

    return resolveBookmarkForPath(media.path, directories) ??
        media.bookmarkData;
  }

  /// Removes state that would otherwise be orphaned once the underlying file is
  /// gone: the cached row itself, and the favorite keyed by its id.
  Future<void> _cleanupAfterDelete(MediaEntity media) async {
    await _purgeCachedMedia(media);

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

  /// Drops the cached row(s) for a trashed item.
  ///
  /// Nothing rescans the directory afterwards any more, so this is the only
  /// thing that removes the row. Left behind, it would keep inflating the
  /// directory count badges, keep matching tag filters, and keep the item listed
  /// on the tags screen.
  Future<void> _purgeCachedMedia(MediaEntity media) async {
    try {
      final ids = <String>[media.id];

      if (media.type == MediaType.directory) {
        // A directory's rows are reachable by path, not by the folder's own id:
        // its children were indexed under whichever directory last scanned them.
        final descendants = await _mediaDataSource.getMediaUnderPath(media.path);
        ids.addAll(descendants.map((descendant) => descendant.id));
      }

      await _mediaDataSource.removeMediaByIds(ids);

      if (media.type == MediaType.directory) {
        await _mediaDataSource.removeMediaForDirectory(
          generateDirectoryId(media.path),
        );
      }
    } catch (e) {
      LoggingService.instance.warning(
        'Failed to purge the cached row for deleted media ${media.id}: $e',
      );
      // Non-fatal: the file is already gone, and Refresh recovers a stale row.
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
        ref.watch(moveMediaUseCaseProvider),
        ref.watch(copyMediaUseCaseProvider),
        ref.watch(reconcileTransferredMediaUseCaseProvider),
        ref.watch(isarMediaDataSourceProvider),
      ),
    );

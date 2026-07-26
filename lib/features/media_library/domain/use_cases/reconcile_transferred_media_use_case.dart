import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/file_transfer_result.dart';
import '../../../../core/services/logging_service.dart';
import '../../../../shared/utils/directory_id_utils.dart';
import '../../../../shared/utils/media_id_utils.dart';
import '../../../favorites/domain/entities/favorite_entity.dart';
import '../../../favorites/domain/entities/favorite_item_type.dart';
import '../../../favorites/domain/repositories/favorites_repository.dart';
import '../../data/isar/isar_media_data_source.dart';
import '../../data/models/media_model.dart';
import '../entities/media_entity.dart';
import '../repositories/directory_repository.dart';
import '../repositories/directory_cover_repository.dart';

/// What the reconciler did, from the caller's point of view.
class ReconciledTransfer {
  const ReconciledTransfer({
    required this.media,
    required this.identityChanged,
  });

  /// The item as it now exists at the destination.
  final MediaEntity media;

  /// Whether the media id changed. When it did, anything keyed by the old id
  /// (favorites, the favorites view models) has been re-keyed and needs a
  /// refresh.
  final bool identityChanged;
}

/// Brings the cache back in line with the filesystem after a move or copy.
///
/// This exists because the cache would otherwise silently lose data. A rescan of
/// the destination merges tags by media id from *that directory's* rows only, so
/// a file arriving from elsewhere would be found with no matching row and have
/// its tags reset to empty; a rescan of the source would delete its row
/// outright. Reconciling the row first — id, path, directory, tags and favorite
/// — makes every later rescan a no-op that preserves everything.
///
/// Callers must therefore run this **before** invalidating any provider.
class ReconcileTransferredMediaUseCase {
  const ReconcileTransferredMediaUseCase(
    this._mediaDataSource,
    this._favoritesRepository,
    this._directoryRepository,
    this._bookmarkService, {
    DirectoryCoverRepository? directoryCoverRepository,
  }) : _directoryCoverRepository = directoryCoverRepository;

  final IsarMediaDataSource _mediaDataSource;
  final FavoritesRepository _favoritesRepository;
  final DirectoryRepository _directoryRepository;
  final BookmarkService _bookmarkService;
  final DirectoryCoverRepository? _directoryCoverRepository;

  Future<ReconciledTransfer> call({
    required MediaEntity source,
    required FileTransferResult transfer,
    required String destinationDirectoryPath,
    required TransferMode mode,
    String? destinationBookmarkData,
    bool copyInheritsTags = true,
  }) async {
    // Statting the destination needs sandboxed read access, and so does the
    // subtree pass below.
    final scopedPath = await _beginAccess(destinationBookmarkData);
    try {
      if (source.type == MediaType.directory) {
        final reconciled = await _reconcileDirectory(
          source: source,
          transfer: transfer,
          destinationDirectoryPath: destinationDirectoryPath,
        );
        await _directoryCoverRepository?.rebaseDirectoryTree(
          oldRootPath: source.path,
          newRootPath: transfer.destinationPath,
        );
        return reconciled;
      }
      final reconciled = await _reconcileFile(
        source: source,
        transfer: transfer,
        destinationDirectoryPath: destinationDirectoryPath,
        mode: mode,
        copyInheritsTags: copyInheritsTags,
      );
      if (mode == TransferMode.move) {
        await _directoryCoverRepository?.reconcileMediaMove(
          oldPath: source.path,
          newPath: transfer.destinationPath,
        );
      }
      return reconciled;
    } finally {
      await _endAccess(scopedPath);
    }
  }

  // MARK: files

  Future<ReconciledTransfer> _reconcileFile({
    required MediaEntity source,
    required FileTransferResult transfer,
    required String destinationDirectoryPath,
    required TransferMode mode,
    required bool copyInheritsTags,
  }) async {
    final newPath = transfer.destinationPath;
    final newName = p.basename(newPath);
    final newDirectoryId = generateDirectoryId(destinationDirectoryPath);
    final stat = await _statOrFallback(newPath, transfer);

    final newId = generateMediaIdFromMetadata(
      size: stat.size,
      lastModified: stat.modified,
      fileName: newName,
    );

    if (mode == TransferMode.copy) {
      // A copy must never reuse its source's id: the cache is keyed by it, so
      // persisting a colliding row would overwrite the source's own record. The
      // native copy stamps a fresh modification time to prevent exactly this, so
      // reaching here means that stamp failed — leave the cache alone and let
      // the destination's next scan index the copy from scratch.
      if (newId == source.id) {
        LoggingService.instance.error(
          'Copy of ${source.path} kept its source id; skipping cache write to '
          'avoid overwriting the original record',
        );
        return ReconciledTransfer(
          media: source.copyWith(path: newPath, name: newName),
          identityChanged: false,
        );
      }

      final copy = MediaModel(
        id: newId,
        path: newPath,
        name: newName,
        type: source.type,
        size: stat.size,
        lastModified: stat.modified,
        tagIds: copyInheritsTags ? List<String>.from(source.tagIds) : const [],
        directoryId: newDirectoryId,
      );
      // Upsert, not replace: the source's row has to survive.
      await _mediaDataSource.upsertMedia([copy]);

      // The copy deliberately does not inherit the favorite: a favorite is a
      // curated pointer to an item, and duplicating the item shouldn't duplicate
      // the entry in the favorites grid.
      return ReconciledTransfer(media: _toEntity(copy), identityChanged: false);
    }

    // A move keeps the id only when the size, modification time and name all
    // survive — so a cross-volume move changes it, and so does a move that was
    // renamed to dodge a collision, even on the same volume. Compare the ids
    // rather than trusting `sameVolume`.
    if (newId == source.id) {
      await _mediaDataSource.relocateMedia(
        mediaId: source.id,
        newPath: newPath,
        newName: newName,
        newDirectoryId: newDirectoryId,
        newSize: stat.size,
        newLastModified: stat.modified,
      );
      // The tags live on the row we just updated and the favorite is keyed by an
      // id that did not change, so both carry over untouched.
      return ReconciledTransfer(
        media: source.copyWith(
          path: newPath,
          name: newName,
          directoryId: newDirectoryId,
          size: stat.size,
          lastModified: stat.modified,
        ),
        identityChanged: false,
      );
    }

    final moved = MediaModel(
      id: newId,
      path: newPath,
      name: newName,
      type: source.type,
      size: stat.size,
      lastModified: stat.modified,
      tagIds: List<String>.from(source.tagIds),
      directoryId: newDirectoryId,
    );
    await _mediaDataSource.replaceMedia(oldMediaId: source.id, newMedia: moved);
    await _remapFavorite(
      oldId: source.id,
      newId: newId,
      type: FavoriteItemType.media,
    );

    return ReconciledTransfer(media: _toEntity(moved), identityChanged: true);
  }

  // MARK: directories

  Future<ReconciledTransfer> _reconcileDirectory({
    required MediaEntity source,
    required FileTransferResult transfer,
    required String destinationDirectoryPath,
  }) async {
    final oldPath = source.path;
    final newPath = transfer.destinationPath;
    final newName = p.basename(newPath);
    // A directory's id is its path, so a move always changes it.
    final newId = generateMediaIdFromPath(newPath);

    // Snapshot the subtree before anything is rewritten: these rows still carry
    // the tags and the old paths the remapping is built from.
    final descendants = await _mediaDataSource.getMediaUnderPath(oldPath);

    final trackedRoot = await _directoryRepository.getDirectoryById(source.id);
    if (trackedRoot != null) {
      // Re-keys the directory record onto its new path and migrates the media
      // rows that referenced the old directory id, preserving the tags,
      // bookmark and scan fingerprints on the record.
      await _directoryRepository.updateDirectoryMetadata(
        source.id,
        path: newPath,
        name: newName,
      );
      await _remapFavorite(
        oldId: source.id,
        newId: generateDirectoryId(newPath),
        type: FavoriteItemType.directory,
      );
    }

    // The directory's own row in its parent's grid, if the parent was scanned.
    final movedRow = MediaModel(
      id: newId,
      path: newPath,
      name: newName,
      type: MediaType.directory,
      size: 0,
      lastModified: transfer.lastModified,
      tagIds: List<String>.from(source.tagIds),
      directoryId: generateDirectoryId(destinationDirectoryPath),
    );
    await _mediaDataSource.replaceMedia(
      oldMediaId: source.id,
      newMedia: movedRow,
    );
    await _remapFavorite(
      oldId: source.id,
      newId: newId,
      type: FavoriteItemType.media,
    );

    await _reconcileSubtree(
      descendants: descendants,
      oldPath: oldPath,
      newPath: newPath,
    );

    return ReconciledTransfer(
      media: _toEntity(movedRow),
      identityChanged: true,
    );
  }

  /// Rewrites every cached row that lived under the moved directory.
  ///
  /// Their paths are all stale, and on a cross-volume move so are their ids
  /// (every file's modification time changed). Each row is re-stat'ed rather
  /// than branching on `sameVolume`, which collapses to a harmless in-place
  /// update when the ids turn out unchanged.
  Future<void> _reconcileSubtree({
    required List<MediaModel> descendants,
    required String oldPath,
    required String newPath,
  }) async {
    if (descendants.isEmpty) {
      return;
    }

    // A row's directoryId is the directory whose grid last scanned it. Those
    // that sit inside the moved subtree have moved too, so their ids are
    // remapped; a row scanned by a directory outside the subtree has lost that
    // association entirely and is re-attributed to the moved directory, which is
    // the nearest scanned ancestor that travelled with it.
    final directoryIdRemap = <String, String>{
      generateDirectoryId(oldPath): generateDirectoryId(newPath),
    };
    for (final row in descendants) {
      if (row.type != MediaType.directory) continue;
      directoryIdRemap[generateDirectoryId(row.path)] = generateDirectoryId(
        _rebase(row.path, oldPath, newPath),
      );
    }

    final entries = <({String oldMediaId, MediaModel newMedia})>[];
    final favoriteRemaps = <({String oldId, String newId})>[];

    for (final row in descendants) {
      final rebased = _rebase(row.path, oldPath, newPath);
      final name = p.basename(rebased);
      final directoryId =
          directoryIdRemap[row.directoryId] ?? generateDirectoryId(newPath);

      final String newId;
      int size = row.size;
      DateTime lastModified = row.lastModified;

      if (row.type == MediaType.directory) {
        newId = generateMediaIdFromPath(rebased);
      } else {
        final stat = await _statOrNull(rebased);
        if (stat != null) {
          size = stat.size;
          lastModified = stat.modified;
        }
        newId = generateMediaIdFromMetadata(
          size: size,
          lastModified: lastModified,
          fileName: name,
        );
      }

      entries.add((
        oldMediaId: row.id,
        newMedia: row.copyWith(
          id: newId,
          path: rebased,
          name: name,
          size: size,
          lastModified: lastModified,
          directoryId: directoryId,
        ),
      ));

      if (newId != row.id) {
        favoriteRemaps.add((oldId: row.id, newId: newId));
      }
    }

    await _mediaDataSource.replaceMediaBatch(entries);

    for (final remap in favoriteRemaps) {
      await _remapFavorite(
        oldId: remap.oldId,
        newId: remap.newId,
        type: FavoriteItemType.media,
      );
    }
  }

  String _rebase(String path, String oldRoot, String newRoot) {
    return p.join(newRoot, p.relative(path, from: oldRoot));
  }

  // MARK: favorites

  /// Carries a favorite over to a new id, keeping the original `addedAt` so the
  /// item does not jump to the top of the recently-favorited ordering.
  Future<void> _remapFavorite({
    required String oldId,
    required String newId,
    required FavoriteItemType type,
  }) async {
    if (oldId == newId) {
      return;
    }

    try {
      if (!await _favoritesRepository.isFavorite(oldId, type: type)) {
        return;
      }

      final existing = await _favoritesRepository.getFavorites();
      final favorite = existing
          .where((f) => f.itemId == oldId && f.itemType == type)
          .firstOrNull;

      await _favoritesRepository.removeFavorite(oldId);
      await _favoritesRepository.addFavorites([
        FavoriteEntity(
          itemId: newId,
          itemType: type,
          addedAt: favorite?.addedAt ?? DateTime.now(),
          metadata: favorite?.metadata,
        ),
      ]);
    } catch (e) {
      // Non-fatal: the transfer itself succeeded, and a stranded favorite is
      // recoverable by re-favoriting.
      LoggingService.instance.warning(
        'Failed to carry favorite $oldId over to $newId: $e',
      );
    }
  }

  // MARK: helpers

  Future<FileStat> _statOrFallback(
    String path,
    FileTransferResult transfer,
  ) async {
    final stat = await _statOrNull(path);
    if (stat != null) {
      return stat;
    }
    // Falling back to the native result keeps the reconcile going, but the id it
    // yields may not match what a scan later computes.
    LoggingService.instance.warning(
      'Could not stat $path after the transfer; falling back to the values '
      'reported by the native call',
    );
    return _SyntheticStat(transfer.size, transfer.lastModified);
  }

  Future<FileStat?> _statOrNull(String path) async {
    try {
      final stat = await FileStat.stat(path);
      if (stat.type == FileSystemEntityType.notFound) {
        return null;
      }
      return stat;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _beginAccess(String? bookmarkData) async {
    if (bookmarkData == null) {
      return null;
    }
    try {
      await _bookmarkService.startAccessingBookmark(bookmarkData);
      return bookmarkData;
    } catch (e) {
      LoggingService.instance.warning(
        'Could not open security scope for the destination: $e',
      );
      return null;
    }
  }

  Future<void> _endAccess(String? bookmarkData) async {
    if (bookmarkData == null) {
      return;
    }
    await _bookmarkService.stopAccessingBookmark(bookmarkData);
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

/// Stand-in for a [FileStat] we could not read, carrying only the two fields a
/// media id is derived from.
class _SyntheticStat implements FileStat {
  const _SyntheticStat(this.size, this.modified);

  @override
  final int size;

  @override
  final DateTime modified;

  @override
  DateTime get accessed => modified;

  @override
  DateTime get changed => modified;

  @override
  int get mode => 0;

  @override
  String modeString() => '';

  @override
  FileSystemEntityType get type => FileSystemEntityType.file;
}

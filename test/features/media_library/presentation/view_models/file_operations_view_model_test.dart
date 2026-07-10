import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/file_operations_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/delete_directory_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/delete_file_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/validate_path_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/file_operations_view_model.dart';

/// Records the delete calls routed through the repository so we can assert the
/// enclosing directory bookmark was threaded through.
class _RecordingFileOperationsRepository implements FileOperationsRepository {
  String? deletedFilePath;
  String? deletedFileBookmark;
  int deleteFileCalls = 0;

  String? deletedDirPath;
  String? deletedDirBookmark;
  int deleteDirCalls = 0;

  @override
  Future<void> deleteFile(String filePath, {String? bookmarkData}) async {
    deleteFileCalls++;
    deletedFilePath = filePath;
    deletedFileBookmark = bookmarkData;
  }

  @override
  Future<void> deleteDirectory(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    deleteDirCalls++;
    deletedDirPath = directoryPath;
    deletedDirBookmark = bookmarkData;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeDirectoryRepository implements DirectoryRepository {
  _FakeDirectoryRepository(this._byId, {List<DirectoryEntity>? all})
      : _all = all ?? _byId.values.toList();

  final Map<String, DirectoryEntity> _byId;
  final List<DirectoryEntity> _all;

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async => _byId[id];

  @override
  Future<List<DirectoryEntity>> getDirectories() async => _all;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _FakeFavoritesRepository implements FavoritesRepository {
  _FakeFavoritesRepository({this.favorite = false});

  bool favorite;
  final List<String> removedIds = <String>[];

  @override
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async =>
      favorite;

  @override
  Future<void> removeFavorite(String itemId) async {
    removedIds.add(itemId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

MediaEntity _media({
  MediaType type = MediaType.image,
  String directoryId = 'dir-1',
}) {
  return MediaEntity(
    id: 'media-1',
    path: '/library/photos/image.jpg',
    name: 'image.jpg',
    type: type,
    size: 1024,
    lastModified: DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: directoryId,
  );
}

DirectoryEntity _directory({String? bookmarkData}) {
  return DirectoryEntity(
    id: 'dir-1',
    path: '/library',
    name: 'library',
    thumbnailPath: null,
    tagIds: const [],
    lastModified: DateTime(2020, 1, 1),
    bookmarkData: bookmarkData,
  );
}

void main() {
  late _RecordingFileOperationsRepository repo;
  late _FakeDirectoryRepository directoryRepo;
  late _FakeFavoritesRepository favoritesRepo;

  FileOperationsViewModel buildViewModel() {
    return FileOperationsViewModel(
      DeleteFileUseCase(repo),
      DeleteDirectoryUseCase(repo),
      ValidatePathUseCase(repo),
      directoryRepo,
      favoritesRepo,
    );
  }

  setUp(() {
    repo = _RecordingFileOperationsRepository();
    directoryRepo = _FakeDirectoryRepository({
      'dir-1': _directory(bookmarkData: 'BOOKMARK-DATA'),
    });
    favoritesRepo = _FakeFavoritesRepository(favorite: true);
  });

  test('does not delete when deleteFromSource is disabled', () async {
    final viewModel = buildViewModel();

    await viewModel.deleteMedia(_media(), deleteFromSource: false);

    expect(viewModel.debugState, isA<FileOperationsError>());
    expect(repo.deleteFileCalls, 0);
  });

  // The real delete path is macOS-only (moves to Trash). On other hosts the
  // view model short-circuits with an error, so only assert the routing where
  // it actually runs.
  final macOnly = Platform.isMacOS ? false : 'macOS-only delete path';

  test(
    'file delete threads the enclosing directory bookmark and moves to Trash',
    () async {
      final viewModel = buildViewModel();

      await viewModel.deleteMedia(_media(), deleteFromSource: true);

      expect(repo.deleteFileCalls, 1);
      expect(repo.deletedFilePath, '/library/photos/image.jpg');
      expect(repo.deletedFileBookmark, 'BOOKMARK-DATA');
      expect(favoritesRepo.removedIds, contains('media-1'));

      final state = viewModel.debugState;
      expect(state, isA<FileOperationsSuccess>());
      expect((state as FileOperationsSuccess).message, 'Moved to Trash');
    },
    skip: macOnly,
  );

  test(
    'directory delete routes to deleteDirectory with the bookmark',
    () async {
      final viewModel = buildViewModel();

      await viewModel.deleteMedia(
        _media(type: MediaType.directory),
        deleteFromSource: true,
      );

      expect(repo.deleteDirCalls, 1);
      expect(repo.deleteFileCalls, 0);
      expect(repo.deletedDirBookmark, 'BOOKMARK-DATA');

      final state = viewModel.debugState;
      expect(state, isA<FileOperationsSuccess>());
      expect(
        (state as FileOperationsSuccess).message,
        'Directory moved to Trash',
      );
    },
    skip: macOnly,
  );

  test(
    'skips favorite cleanup when the item is not favorited',
    () async {
      favoritesRepo.favorite = false;
      final viewModel = buildViewModel();

      await viewModel.deleteMedia(_media(), deleteFromSource: true);

      expect(repo.deleteFileCalls, 1);
      expect(favoritesRepo.removedIds, isEmpty);
      expect(viewModel.debugState, isA<FileOperationsSuccess>());
    },
    skip: macOnly,
  );

  test(
    'falls back to the enclosing tracked root bookmark for a subdirectory',
    () async {
      // The subdirectory itself isn't tracked (getDirectoryById -> null), but a
      // library root at /library covers its path and holds the bookmark.
      directoryRepo = _FakeDirectoryRepository(
        const {},
        all: [
          DirectoryEntity(
            id: 'root-1',
            path: '/library',
            name: 'library',
            thumbnailPath: null,
            tagIds: const [],
            lastModified: DateTime(2020, 1, 1),
            bookmarkData: 'ROOT-BOOKMARK',
          ),
        ],
      );

      final viewModel = buildViewModel();
      final subdir = MediaEntity(
        id: 'subdir-1',
        path: '/library/photos/vacation',
        name: 'vacation',
        type: MediaType.directory,
        size: 0,
        lastModified: DateTime(2020, 1, 1),
        tagIds: const [],
        directoryId: 'subdir-1', // not a tracked directory id
      );

      await viewModel.deleteMedia(subdir, deleteFromSource: true);

      expect(repo.deleteDirCalls, 1);
      expect(repo.deletedDirPath, '/library/photos/vacation');
      expect(repo.deletedDirBookmark, 'ROOT-BOOKMARK');
    },
    skip: macOnly,
  );
}

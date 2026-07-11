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

  /// Every path passed to a delete, in call order.
  final List<String> deletedPaths = <String>[];

  /// Paths that should fail, mapped to the failure message.
  final Map<String, String> failures = <String, String>{};

  @override
  Future<void> deleteFile(String filePath, {String? bookmarkData}) async {
    deleteFileCalls++;
    deletedFilePath = filePath;
    deletedFileBookmark = bookmarkData;
    _record(filePath);
  }

  @override
  Future<void> deleteDirectory(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    deleteDirCalls++;
    deletedDirPath = directoryPath;
    deletedDirBookmark = bookmarkData;
    _record(directoryPath);
  }

  void _record(String path) {
    final failure = failures[path];
    if (failure != null) {
      throw Exception(failure);
    }
    deletedPaths.add(path);
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

  /// When set, overrides [favorite] with per-id answers.
  Set<String>? favoriteIds;
  final List<String> removedIds = <String>[];

  @override
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async =>
      favoriteIds?.contains(itemId) ?? favorite;

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

/// A file in the tracked `/library` root, keyed by [name] for readable ids.
MediaEntity _file(String name, {String? path}) {
  return MediaEntity(
    id: name,
    path: path ?? '/library/$name',
    name: name,
    type: MediaType.image,
    size: 1024,
    lastModified: DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: 'dir-1',
  );
}

/// A subdirectory of the tracked `/library` root, which the scan does not track
/// as a directory of its own.
MediaEntity _directoryMedia(String name, String path) {
  return MediaEntity(
    id: name,
    path: path,
    name: name,
    type: MediaType.directory,
    size: 0,
    lastModified: DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: 'dir-1',
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

  group('deleteMediaBatch', () {
    test('deletes nothing and reports every id when disabled in settings',
        () async {
      final viewModel = buildViewModel();
      final items = [_file('a.jpg'), _file('b.jpg')];

      final result = await viewModel.deleteMediaBatch(
        items,
        deleteFromSource: false,
      );

      expect(repo.deletedPaths, isEmpty);
      expect(result.hasSuccesses, isFalse);
      expect(result.failureReasons.keys, {'a.jpg', 'b.jpg'});
      expect(viewModel.debugState, isA<FileOperationsError>());
    });

    test(
      'moves every selected item to Trash with the enclosing bookmark',
      () async {
        final viewModel = buildViewModel();
        final items = [
          _file('a.jpg'),
          _file('b.jpg'),
          _directoryMedia('clips', '/library/clips'),
        ];

        final progress = <int>[];
        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
          onProgress: (completed, _) => progress.add(completed),
        );

        expect(repo.deleteFileCalls, 2);
        expect(repo.deleteDirCalls, 1);
        expect(repo.deletedFileBookmark, 'BOOKMARK-DATA');
        expect(repo.deletedDirBookmark, 'BOOKMARK-DATA');
        expect(result.successfulIds, ['a.jpg', 'b.jpg', 'clips']);
        expect(result.hasFailures, isFalse);
        expect(progress, [1, 2, 3]);
        expect(viewModel.debugState, isA<FileOperationsSuccess>());
        expect(
          (viewModel.debugState as FileOperationsSuccess).message,
          'Moved 3 items to Trash',
        );
      },
      skip: macOnly,
    );

    test(
      'trashes a selected folder once instead of its selected contents',
      () async {
        favoritesRepo.favoriteIds = {'nested.jpg'};
        final viewModel = buildViewModel();
        final items = [
          _directoryMedia('vacation', '/library/vacation'),
          _file('nested.jpg', path: '/library/vacation/nested.jpg'),
          _file('sibling.jpg'),
        ];

        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
        );

        // The nested file rides along with its parent: one directory delete,
        // and the only file delete is the one outside it.
        expect(repo.deleteDirCalls, 1);
        expect(repo.deleteFileCalls, 1);
        expect(repo.deletedPaths, [
          '/library/vacation',
          '/library/sibling.jpg',
        ]);
        // ...but it still counts as deleted and gets its favorite cleaned up.
        expect(
          result.successfulIds,
          containsAll(<String>['vacation', 'nested.jpg', 'sibling.jpg']),
        );
        expect(result.hasFailures, isFalse);
        expect(favoritesRepo.removedIds, ['nested.jpg']);
      },
      skip: macOnly,
    );

    test(
      'records a mid-batch failure and still deletes the rest',
      () async {
        repo.failures['/library/b.jpg'] = 'permission denied';
        final viewModel = buildViewModel();
        final items = [_file('a.jpg'), _file('b.jpg'), _file('c.jpg')];

        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
        );

        expect(repo.deletedPaths, ['/library/a.jpg', '/library/c.jpg']);
        expect(result.successfulIds, ['a.jpg', 'c.jpg']);
        expect(result.failureReasons.keys, ['b.jpg']);
        expect(result.failureReasons['b.jpg'], contains('permission denied'));
        expect(favoritesRepo.removedIds, isNot(contains('b.jpg')));
        expect(viewModel.debugState, isA<FileOperationsSuccess>());
        expect(
          (viewModel.debugState as FileOperationsSuccess).message,
          'Moved 2 items to Trash, 1 failed',
        );
      },
      skip: macOnly,
    );

    test(
      'nested items fail when the folder that covers them fails',
      () async {
        repo.failures['/library/vacation'] = 'permission denied';
        final viewModel = buildViewModel();
        final items = [
          _directoryMedia('vacation', '/library/vacation'),
          _file('nested.jpg', path: '/library/vacation/nested.jpg'),
        ];

        final result = await viewModel.deleteMediaBatch(
          items,
          deleteFromSource: true,
        );

        expect(repo.deletedPaths, isEmpty);
        expect(result.hasSuccesses, isFalse);
        expect(result.failureReasons.keys, containsAll(<String>[
          'vacation',
          'nested.jpg',
        ]));
        expect(favoritesRepo.removedIds, isEmpty);
        expect(viewModel.debugState, isA<FileOperationsError>());
      },
      skip: macOnly,
    );
  });
}

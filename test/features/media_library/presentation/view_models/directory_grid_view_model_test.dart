import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/core/utils/batch_update_result.dart';

import '../../../../../lib/core/services/permission_service.dart';
import '../../../../../lib/features/favorites/domain/entities/favorite_entity.dart';
import '../../../../../lib/features/favorites/domain/entities/favorite_item_type.dart';
import '../../../../../lib/features/favorites/domain/repositories/favorites_repository.dart';
import '../../../../../lib/features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../../../../lib/features/media_library/domain/entities/directory_entity.dart';
import '../../../../../lib/features/media_library/domain/entities/directory_media_counts.dart';
import '../../../../../lib/features/media_library/domain/entities/media_entity.dart';
import '../../../../../lib/features/media_library/domain/repositories/directory_repository.dart';
import '../../../../../lib/features/media_library/domain/repositories/media_repository.dart';
import '../../../../../lib/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../../../../lib/shared/providers/repository_providers.dart';

class InMemoryDirectoryRepository implements DirectoryRepository {
  InMemoryDirectoryRepository(this._directories);

  final List<DirectoryEntity> _directories;

  @override
  Future<void> addDirectory(
    DirectoryEntity directory, {
    bool silent = false,
  }) async {
    _directories.add(directory);
  }

  @override
  Future<void> clearAllDirectories() async {
    _directories.clear();
  }

  @override
  Future<void> refreshChangedLibraryRoots() async {}

  @override
  Future<List<DirectoryEntity>> filterDirectoriesByTags(
    List<String> tagIds,
  ) async {
    if (tagIds.isEmpty) {
      return getDirectories();
    }
    return _directories
        .where((dir) => dir.tagIds.any(tagIds.contains))
        .toList();
  }

  @override
  Future<List<DirectoryEntity>> getDirectories() async {
    return List<DirectoryEntity>.from(_directories);
  }

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async {
    try {
      return _directories.firstWhere((dir) => dir.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeDirectory(String id) async {
    _directories.removeWhere((dir) => dir.id == id);
  }

  @override
  Future<List<DirectoryEntity>> searchDirectories(String query) async {
    if (query.isEmpty) {
      return getDirectories();
    }
    final lower = query.toLowerCase();
    return _directories
        .where((dir) => dir.name.toLowerCase().contains(lower))
        .toList();
  }

  @override
  Future<void> updateDirectoryBookmark(
    String directoryId,
    String? bookmarkData,
  ) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index != -1) {
      _directories[index] = _directories[index].copyWith(
        bookmarkData: bookmarkData,
      );
    }
  }

  @override
  Future<void> updateDirectoryTags(
    String directoryId,
    List<String> tagIds,
  ) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index != -1) {
      _directories[index] = _directories[index].copyWith(tagIds: tagIds);
    }
  }

  @override
  Future<void> updateDirectoryMetadata(
    String directoryId, {
    String? path,
    String? name,
    String? bookmarkData,
  }) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index == -1) {
      return;
    }

    final existing = _directories[index];
    _directories[index] = existing.copyWith(
      path: path ?? existing.path,
      name: name ?? existing.name,
      bookmarkData: bookmarkData ?? existing.bookmarkData,
    );
  }
}

class InMemoryMediaRepository implements MediaRepository {
  InMemoryMediaRepository(this._media);

  final List<MediaEntity> _media;

  @override
  Future<List<MediaEntity>> filterMediaByTags(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return List<MediaEntity>.from(_media);
    }
    return _media.where((item) => item.tagIds.any(tagIds.contains)).toList();
  }

  @override
  Future<List<MediaEntity>> filterMediaByTagsForDirectory(
    List<String> tagIds,
    String directoryPath, {
    String? bookmarkData,
  }) async {
    return (await filterMediaByTags(
      tagIds,
    )).where((item) => item.directoryId == directoryPath).toList();
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId) async {
    return _media.where((item) => item.directoryId == directoryId).toList();
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    return getMediaForDirectory(directoryPath);
  }

  @override
  Future<List<MediaEntity>> getAllMedia() async {
    return List<MediaEntity>.from(_media);
  }

  @override
  Future<Map<String, DirectoryMediaCounts>> getDirectoryMediaCounts() async {
    final countsByDirectory = <String, DirectoryMediaCounts>{};

    for (final item in _media) {
      final previous = countsByDirectory[item.directoryId] ??
          const DirectoryMediaCounts();
      countsByDirectory[item.directoryId] = DirectoryMediaCounts(
        totalMediaCount: previous.totalMediaCount + 1,
        taggedMediaCount: previous.taggedMediaCount +
            (item.tagIds.isNotEmpty ? 1 : 0),
      );
    }

    return countsByDirectory;
  }

  @override
  Future<MediaEntity?> getMediaById(String id) async {
    try {
      return _media.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeMediaForDirectory(String directoryId) async {
    _media.removeWhere((item) => item.directoryId == directoryId);
  }

  @override
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    final index = _media.indexWhere((item) => item.id == mediaId);
    if (index != -1) {
      _media[index] = _media[index].copyWith(tagIds: tagIds);
    }
  }

  @override
  Future<BatchUpdateResult> updateMediaTagsBatch(
    Map<String, List<String>> mediaTags,
  ) async {
    final successfulIds = <String>[];
    for (final entry in mediaTags.entries) {
      final index = _media.indexWhere((item) => item.id == entry.key);
      if (index == -1) {
        continue;
      }
      _media[index] = _media[index].copyWith(tagIds: entry.value);
      successfulIds.add(entry.key);
    }
    return BatchUpdateResult(
      successfulIds: successfulIds,
      failureReasons: const <String, String>{},
    );
  }

  @override
  Future<void> removeMediaNotInDirectories(List<String> directoryIds) async {
    final allowedIds = directoryIds.toSet();
    _media.removeWhere((item) => !allowedIds.contains(item.directoryId));
  }

  @override
  Future<void> clearAllMedia() async {
    _media.clear();
  }

  @override
  Future<void> upsertMedia(List<MediaEntity> media) async {
    final mediaById = {for (final item in _media) item.id: item};
    for (final item in media) {
      mediaById[item.id] = item;
    }
    _media
      ..clear()
      ..addAll(mediaById.values);
  }
}

class InMemoryFavoritesRepository implements FavoritesRepository {
  final Map<String, FavoriteEntity> _favorites = <String, FavoriteEntity>{};

  String _key(String id, FavoriteItemType type) => '${type.name}::$id';

  @override
  Future<void> addFavorite(String mediaId) async {
    await addFavorites([
      FavoriteEntity(
        itemId: mediaId,
        itemType: FavoriteItemType.media,
        addedAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<void> addFavorites(List<FavoriteEntity> favorites) async {
    for (final favorite in favorites) {
      _favorites[_key(favorite.itemId, favorite.itemType)] = favorite;
    }
  }

  @override
  Future<List<FavoriteEntity>> getFavorites() async {
    return _favorites.values.toList(growable: false);
  }

  @override
  Future<List<String>> getFavoriteMediaIds() async {
    return _favorites.values
        .where((fav) => fav.itemType == FavoriteItemType.media)
        .map((fav) => fav.itemId)
        .toList();
  }

  @override
  Future<bool> isFavorite(
    String itemId, {
    FavoriteItemType type = FavoriteItemType.media,
  }) async {
    return _favorites.containsKey(_key(itemId, type));
  }

  @override
  Future<void> removeFavorite(String itemId) async {
    await removeFavorites([itemId]);
  }

  @override
  Future<void> removeFavorites(List<String> itemIds) async {
    final ids = itemIds.toSet();
    _favorites.removeWhere((key, value) => ids.contains(value.itemId));
  }
}

class FakeLocalDirectoryDataSource extends LocalDirectoryDataSource {
  FakeLocalDirectoryDataSource()
    : super(bookmarkService: BookmarkService.instance);

  @override
  Future<bool> validateDirectory(DirectoryEntity directory) async => true;
}

class FakePermissionService extends PermissionService {
  FakePermissionService() : super();
}

Future<ProviderContainer> _createDirectoryTestContainer({
  required InMemoryDirectoryRepository directoryRepository,
  required InMemoryMediaRepository mediaRepository,
  required InMemoryFavoritesRepository favoritesRepository,
}) async {
  final container = ProviderContainer(
    overrides: [
      localDirectoryDataSourceProvider.overrideWithValue(
        FakeLocalDirectoryDataSource(),
      ),
      permissionServiceProvider.overrideWithValue(FakePermissionService()),
      directoryRepositoryProvider.overrideWith((ref) {
        return DirectoryRepositoryNotifier(directoryRepository);
      }),
      mediaRepositoryProvider.overrideWith((ref) {
        return MediaRepositoryNotifier(mediaRepository);
      }),
      favoritesRepositoryProvider.overrideWith((ref) {
        return FavoritesRepositoryNotifier(favoritesRepository);
      }),
    ],
  );

  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryDirectoryRepository directoryRepository;
  late InMemoryMediaRepository mediaRepository;
  late InMemoryFavoritesRepository favoritesRepository;

  setUp(() async {
    directoryRepository = InMemoryDirectoryRepository([
      DirectoryEntity(
        id: '1',
        path: '/dir1',
        name: 'Directory 1',
        thumbnailPath: null,
        tagIds: const ['shared', 'tag1'],
        lastModified: DateTime(2024, 1, 1),
      ),
      DirectoryEntity(
        id: '2',
        path: '/dir2',
        name: 'Directory 2',
        thumbnailPath: null,
        tagIds: const ['shared', 'tag2'],
        lastModified: DateTime(2024, 1, 2),
      ),
      DirectoryEntity(
        id: '3',
        path: '/dir3',
        name: 'Directory 3',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: DateTime(2024, 1, 3),
      ),
    ]);
    mediaRepository = InMemoryMediaRepository([]);
    favoritesRepository = InMemoryFavoritesRepository();
  });

  test('toggleDirectorySelection toggles selection mode and IDs', () async {
    final container = await _createDirectoryTestContainer(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(directoryViewModelProvider.notifier);
    await viewModel.loadDirectories();

    viewModel.toggleDirectorySelection('1');

    final state = container.read(directoryViewModelProvider);
    expect(state, isA<DirectoryLoaded>());
    final loaded = state as DirectoryLoaded;
    expect(loaded.selectedDirectoryIds, {'1'});
    expect(loaded.isSelectionMode, isTrue);

    viewModel.toggleDirectorySelection('1');
    final cleared =
        container.read(directoryViewModelProvider) as DirectoryLoaded;
    expect(cleared.selectedDirectoryIds, isEmpty);
    expect(cleared.isSelectionMode, isFalse);
  });

  test('selectDirectoryRange supports append mode', () async {
    final container = await _createDirectoryTestContainer(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(directoryViewModelProvider.notifier);
    await viewModel.loadDirectories();

    viewModel.selectDirectoryRange(const ['1', '2']);
    DirectoryLoaded state =
        container.read(directoryViewModelProvider) as DirectoryLoaded;
    expect(state.selectedDirectoryIds, {'1', '2'});
    expect(state.isSelectionMode, isTrue);

    viewModel.selectDirectoryRange(const ['3'], append: true);
    state = container.read(directoryViewModelProvider) as DirectoryLoaded;
    expect(state.selectedDirectoryIds, {'1', '2', '3'});
  });

  test('clearDirectorySelection resets providers', () async {
    final container = await _createDirectoryTestContainer(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(directoryViewModelProvider.notifier);
    await viewModel.loadDirectories();
    viewModel.selectDirectoryRange(const ['1', '2']);

    viewModel.clearDirectorySelection();

    final state = container.read(directoryViewModelProvider) as DirectoryLoaded;
    expect(state.selectedDirectoryIds, isEmpty);
    expect(state.isSelectionMode, isFalse);
    expect(container.read(selectedDirectoryIdsProvider), isEmpty);
    expect(container.read(directorySelectionModeProvider), isFalse);
    expect(container.read(selectedDirectoryCountProvider), 0);
  });

  test(
    'commonTagIdsForSelection returns tags shared across selected directories',
    () async {
      final container = await _createDirectoryTestContainer(
        directoryRepository: directoryRepository,
        mediaRepository: mediaRepository,
        favoritesRepository: favoritesRepository,
      );
      addTearDown(container.dispose);

      final viewModel = container.read(directoryViewModelProvider.notifier);
      await viewModel.loadDirectories();
      viewModel.selectDirectoryRange(const ['1', '2']);

      final commonTags = viewModel.commonTagIdsForSelection();
      expect(commonTags, ['shared']);
    },
  );

  test(
    'applyTagsToSelection updates repositories and state for selection',
    () async {
      final container = await _createDirectoryTestContainer(
        directoryRepository: directoryRepository,
        mediaRepository: mediaRepository,
        favoritesRepository: favoritesRepository,
      );
      addTearDown(container.dispose);

      final viewModel = container.read(directoryViewModelProvider.notifier);
      await viewModel.loadDirectories();
      viewModel.selectDirectoryRange(const ['1', '3']);

      await viewModel.applyTagsToSelection(const ['bulk', 'bulk']);

      final repoDirectories = await directoryRepository.getDirectories();
      expect(repoDirectories.firstWhere((dir) => dir.id == '1').tagIds, [
        'bulk',
      ]);
      expect(repoDirectories.firstWhere((dir) => dir.id == '3').tagIds, [
        'bulk',
      ]);

      final state = container.read(directoryViewModelProvider);
      expect(state, isA<DirectoryLoaded>());
      final loaded = state as DirectoryLoaded;
      expect(loaded.selectedDirectoryIds, {'1', '3'});
      expect(loaded.directories.firstWhere((dir) => dir.id == '1').tagIds, [
        'bulk',
      ]);
    },
  );

  test('loadDirectories enriches directories with cached media counts', () async {
    mediaRepository = InMemoryMediaRepository([
      MediaEntity(
        id: 'media-1',
        path: '/dir1/a.jpg',
        name: 'a.jpg',
        type: MediaType.image,
        size: 100,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const ['tag-1'],
        directoryId: '1',
      ),
      MediaEntity(
        id: 'media-2',
        path: '/dir1/b.jpg',
        name: 'b.jpg',
        type: MediaType.image,
        size: 100,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const <String>[],
        directoryId: '1',
      ),
      MediaEntity(
        id: 'media-3',
        path: '/dir2/c.jpg',
        name: 'c.jpg',
        type: MediaType.image,
        size: 100,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const ['tag-2'],
        directoryId: '2',
      ),
    ]);

    final container = await _createDirectoryTestContainer(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(directoryViewModelProvider.notifier);
    await viewModel.loadDirectories();

    final state = container.read(directoryViewModelProvider) as DirectoryLoaded;
    final directoryOne = state.directories.firstWhere((dir) => dir.id == '1');
    final directoryTwo = state.directories.firstWhere((dir) => dir.id == '2');
    final directoryThree = state.directories.firstWhere((dir) => dir.id == '3');

    expect(directoryOne.mediaCounts.totalMediaCount, 2);
    expect(directoryOne.mediaCounts.taggedMediaCount, 1);
    expect(directoryTwo.mediaCounts.totalMediaCount, 1);
    expect(directoryTwo.mediaCounts.taggedMediaCount, 1);
    expect(directoryThree.mediaCounts.totalMediaCount, 0);
    expect(directoryThree.mediaCounts.taggedMediaCount, 0);
  });

  test(
    'changeSortOption sorts directories by tagged percentage in both directions',
    () async {
      directoryRepository = InMemoryDirectoryRepository([
        DirectoryEntity(
          id: '1',
          path: '/alpha',
          name: 'Alpha',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 1),
        ),
        DirectoryEntity(
          id: '2',
          path: '/beta',
          name: 'Beta',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 2),
        ),
        DirectoryEntity(
          id: '3',
          path: '/gamma',
          name: 'Gamma',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 3),
        ),
        DirectoryEntity(
          id: '4',
          path: '/empty',
          name: 'Empty',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 4),
        ),
        DirectoryEntity(
          id: '5',
          path: '/aardvark',
          name: 'Aardvark',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 5),
        ),
        DirectoryEntity(
          id: '6',
          path: '/sparse',
          name: 'Sparse',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 6),
        ),
      ]);

      List<MediaEntity> createMediaForDirectory({
        required String directoryId,
        required int taggedCount,
        required int totalCount,
      }) {
        return List<MediaEntity>.generate(totalCount, (index) {
          final isTagged = index < taggedCount;
          return MediaEntity(
            id: '$directoryId-media-$index',
            path: '/$directoryId/$index.jpg',
            name: '$index.jpg',
            type: MediaType.image,
            size: 100,
            lastModified: DateTime(2024, 1, 1),
            tagIds: isTagged ? ['tag-$directoryId'] : const <String>[],
            directoryId: directoryId,
          );
        });
      }

      mediaRepository = InMemoryMediaRepository([
        ...createMediaForDirectory(
          directoryId: '1',
          taggedCount: 1,
          totalCount: 2,
        ),
        ...createMediaForDirectory(
          directoryId: '2',
          taggedCount: 2,
          totalCount: 4,
        ),
        ...createMediaForDirectory(
          directoryId: '3',
          taggedCount: 3,
          totalCount: 4,
        ),
        ...createMediaForDirectory(
          directoryId: '5',
          taggedCount: 1,
          totalCount: 2,
        ),
        ...createMediaForDirectory(
          directoryId: '6',
          taggedCount: 4,
          totalCount: 10,
        ),
      ]);

      final container = await _createDirectoryTestContainer(
        directoryRepository: directoryRepository,
        mediaRepository: mediaRepository,
        favoritesRepository: favoritesRepository,
      );
      addTearDown(container.dispose);

      final viewModel = container.read(directoryViewModelProvider.notifier);
      await viewModel.loadDirectories();

      viewModel.changeSortOption(DirectorySortOption.taggedPercentageDescending);

      final descendingState =
          container.read(directoryViewModelProvider) as DirectoryLoaded;
      expect(
        descendingState.directories.map((directory) => directory.name).toList(),
        ['Gamma', 'Beta', 'Aardvark', 'Alpha', 'Sparse', 'Empty'],
      );
      expect(
        descendingState.sortOption,
        DirectorySortOption.taggedPercentageDescending,
      );

      final emptyDirectory = descendingState.directories.last;
      expect(emptyDirectory.name, 'Empty');
      expect(emptyDirectory.mediaCounts.totalMediaCount, 0);
      expect(emptyDirectory.mediaCounts.taggedMediaCount, 0);

      viewModel.changeSortOption(DirectorySortOption.taggedPercentageAscending);

      final ascendingState =
          container.read(directoryViewModelProvider) as DirectoryLoaded;
      expect(
        ascendingState.directories.map((directory) => directory.name).toList(),
        ['Empty', 'Sparse', 'Aardvark', 'Alpha', 'Beta', 'Gamma'],
      );
      expect(
        ascendingState.sortOption,
        DirectorySortOption.taggedPercentageAscending,
      );
    },
  );
}

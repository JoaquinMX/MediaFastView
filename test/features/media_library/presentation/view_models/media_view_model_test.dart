import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/utils/batch_update_result.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_media_counts.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_entity.dart';
import 'package:media_fast_view/features/favorites/domain/entities/favorite_item_type.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/get_media_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/update_directory_access_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/media_grid_view_model.dart';
import 'package:media_fast_view/shared/providers/media_mutation_bus.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:path/path.dart' as p;
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'media_view_model_test.mocks.dart';

@GenerateMocks([IsarMediaDataSource, DirectoryRepository])
void _dummy() {}

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

  /// No filesystem in this fake, so nothing can be confirmed missing.
  @override
  Future<int> pruneMissingMedia() async => 0;

  /// No filesystem in this fake, so there is nothing to re-read.
  @override
  Future<int> rescanLibrary({
    void Function(int done, int total)? onProgress,
  }) async =>
      0;

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

  @override
  Future<List<String>> getFavoriteDirectoryIds() async {
    return _favorites.values
        .where((fav) => fav.itemType == FavoriteItemType.directory)
        .map((fav) => fav.itemId)
        .toList();
  }
}

// Mocks are now generated; remove inline Mock declarations

ProviderContainer _createMediaTestContainer({
  required IsarMediaDataSource mediaDataSource,
  required InMemoryMediaRepository mediaRepository,
  required GetMediaUseCase getMediaUseCase,
  required InMemoryFavoritesRepository favoritesRepository,
  required UpdateDirectoryAccessUseCase updateDirectoryAccessUseCase,
}) {
  return ProviderContainer(
    overrides: [
      favoritesRepositoryProvider.overrideWith((ref) {
        return FavoritesRepositoryNotifier(favoritesRepository);
      }),
      mediaRepositoryProvider.overrideWith((ref) {
        return MediaRepositoryNotifier(mediaRepository);
      }),
      mediaViewModelProvider.overrideWithProvider((params) {
        return StateNotifierProvider.autoDispose<MediaViewModel, MediaState>(
          (ref) => MediaViewModel(
            ref,
            params,
            getMediaUseCase: getMediaUseCase,
            mediaDataSource: mediaDataSource,
            updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
          ),
        );
      }),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockIsarMediaDataSource mediaCache;
  late InMemoryMediaRepository mediaRepository;
  late InMemoryFavoritesRepository favoritesRepository;
  late GetMediaUseCase getMediaUseCase;
  late UpdateDirectoryAccessUseCase updateDirectoryAccessUseCase;
  late MockDirectoryRepository directoryRepository;
  const params = MediaViewModelParams(
    directoryPath: '/dir1',
    directoryName: 'Directory 1',
  );

  setUp(() async {
    // GridColumnsNotifier (read transitively by MediaViewModel) calls
    // SharedPreferences.getInstance() in its constructor; without this mock
    // the platform channel throws MissingPluginException and the provider
    // errors out (which auto-disposes and breaks every test using the VM).
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mediaCache = MockIsarMediaDataSource();
    when(mediaCache.getMedia()).thenAnswer((_) async => <MediaModel>[]);
    when(
      mediaCache.getMediaForDirectory(any),
    ).thenAnswer((_) async => <MediaModel>[]);
    when(mediaCache.removeMediaForDirectory(any)).thenAnswer((_) async {});
    when(mediaCache.upsertMedia(any)).thenAnswer((_) async {});
    favoritesRepository = InMemoryFavoritesRepository();
    directoryRepository = MockDirectoryRepository();
    when(
      directoryRepository.updateDirectoryMetadata(
        any,
        path: anyNamed('path'),
        name: anyNamed('name'),
        bookmarkData: anyNamed('bookmarkData'),
      ),
    ).thenAnswer((_) async {});
    updateDirectoryAccessUseCase = UpdateDirectoryAccessUseCase(
      directoryRepository,
    );
    mediaRepository = InMemoryMediaRepository([
      MediaEntity(
        id: 'm1',
        path: '/dir1/media1.jpg',
        name: 'media1.jpg',
        type: MediaType.image,
        size: 1000,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const ['shared', 'blue'],
        directoryId: '/dir1',
      ),
      MediaEntity(
        id: 'm2',
        path: '/dir1/media2.jpg',
        name: 'media2.jpg',
        type: MediaType.image,
        size: 2000,
        lastModified: DateTime(2024, 1, 2),
        tagIds: const ['shared', 'green'],
        directoryId: '/dir1',
      ),
      MediaEntity(
        id: 'm3',
        path: '/dir1/media3.jpg',
        name: 'media3.jpg',
        type: MediaType.image,
        size: 3000,
        lastModified: DateTime(2024, 1, 3),
        tagIds: const ['other'],
        directoryId: '/dir1',
      ),
    ]);
    getMediaUseCase = GetMediaUseCase(mediaRepository);
  });


  test('loadMedia fetches persisted rows for current directory only', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      getMediaUseCase: getMediaUseCase,
      favoritesRepository: favoritesRepository,
      updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
    );
    addTearDown(container.dispose);
    container.listen(mediaViewModelProvider(params), (_, __) {});

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();
    clearInteractions(mediaCache);

    await viewModel.loadMedia();

    verify(mediaCache.getMediaForDirectory(viewModel.directoryId)).called(1);
    verifyNever(mediaCache.getMedia());
  });

  test('toggleMediaSelection toggles selection state', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      getMediaUseCase: getMediaUseCase,
      favoritesRepository: favoritesRepository,
      updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
    );
    addTearDown(container.dispose);
    container.listen(mediaViewModelProvider(params), (_, __) {});

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.toggleMediaSelection('m1');

    final state = container.read(mediaViewModelProvider(params));
    expect(state, isA<MediaLoaded>());
    final loaded = state as MediaLoaded;
    expect(loaded.selectedMediaIds, {'m1'});
    expect(loaded.isSelectionMode, isTrue);

    viewModel.toggleMediaSelection('m1');
    final cleared =
        container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(cleared.selectedMediaIds, isEmpty);
    // Production keeps `isSelectionMode` true after the last item is
    // deselected — only `clearMediaSelection()` exits selection mode.
    expect(cleared.isSelectionMode, isTrue);
  });

  test('selectMediaRange appends when requested', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      getMediaUseCase: getMediaUseCase,
      favoritesRepository: favoritesRepository,
      updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
    );
    addTearDown(container.dispose);
    container.listen(mediaViewModelProvider(params), (_, __) {});

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.selectMediaRange(const ['m1', 'm2']);
    MediaLoaded state =
        container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(state.selectedMediaIds, {'m1', 'm2'});
    expect(state.isSelectionMode, isTrue);

    viewModel.selectMediaRange(const ['m3'], append: true);
    state = container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(state.selectedMediaIds, {'m1', 'm2', 'm3'});
  });

  test('clearMediaSelection resets selection providers', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      getMediaUseCase: getMediaUseCase,
      favoritesRepository: favoritesRepository,
      updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
    );
    addTearDown(container.dispose);
    container.listen(mediaViewModelProvider(params), (_, __) {});

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();
    viewModel.selectMediaRange(const ['m1', 'm2']);

    viewModel.clearMediaSelection();

    final state = container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(state.selectedMediaIds, isEmpty);
    expect(state.isSelectionMode, isFalse);
    expect(container.read(selectedMediaIdsProvider(params)), isEmpty);
    expect(container.read(mediaSelectionModeProvider(params)), isFalse);
    expect(container.read(selectedMediaCountProvider(params)), 0);
  });

  test('commonTagIdsForSelection returns shared tags', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      getMediaUseCase: getMediaUseCase,
      favoritesRepository: favoritesRepository,
      updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
    );
    addTearDown(container.dispose);
    container.listen(mediaViewModelProvider(params), (_, __) {});

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();
    viewModel.selectMediaRange(const ['m1', 'm2']);

    expect(viewModel.commonTagIdsForSelection(), ['shared']);
  });

  test(
    'changeSortOption sorts subdirectories by tagged percentage in both directions',
    () async {
      const childAlphaPath = '/dir1/alpha';
      const childBetaPath = '/dir1/beta';
      const childEmptyPath = '/dir1/empty';

      mediaRepository = InMemoryMediaRepository([
        MediaEntity(
          id: 'dir-alpha',
          path: childAlphaPath,
          name: 'Alpha',
          type: MediaType.directory,
          size: 0,
          lastModified: DateTime(2024, 1, 1),
          tagIds: const [],
          directoryId: '/dir1',
        ),
        MediaEntity(
          id: 'dir-beta',
          path: childBetaPath,
          name: 'Beta',
          type: MediaType.directory,
          size: 0,
          lastModified: DateTime(2024, 1, 2),
          tagIds: const [],
          directoryId: '/dir1',
        ),
        MediaEntity(
          id: 'dir-empty',
          path: childEmptyPath,
          name: 'Empty',
          type: MediaType.directory,
          size: 0,
          lastModified: DateTime(2024, 1, 3),
          tagIds: const [],
          directoryId: '/dir1',
        ),
        MediaEntity(
          id: 'file-1',
          path: '/dir1/file-1.jpg',
          name: 'file-1.jpg',
          type: MediaType.image,
          size: 100,
          lastModified: DateTime(2024, 1, 4),
          tagIds: const ['local'],
          directoryId: '/dir1',
        ),
        MediaEntity(
          id: 'alpha-1',
          path: '$childAlphaPath/1.jpg',
          name: '1.jpg',
          type: MediaType.image,
          size: 100,
          lastModified: DateTime(2024, 1, 5),
          tagIds: const ['tag-a'],
          directoryId: generateDirectoryId(childAlphaPath),
        ),
        MediaEntity(
          id: 'alpha-2',
          path: '$childAlphaPath/2.jpg',
          name: '2.jpg',
          type: MediaType.image,
          size: 100,
          lastModified: DateTime(2024, 1, 5),
          tagIds: const <String>[],
          directoryId: generateDirectoryId(childAlphaPath),
        ),
        MediaEntity(
          id: 'beta-1',
          path: '$childBetaPath/1.jpg',
          name: '1.jpg',
          type: MediaType.image,
          size: 100,
          lastModified: DateTime(2024, 1, 5),
          tagIds: const ['tag-b'],
          directoryId: generateDirectoryId(childBetaPath),
        ),
      ]);
      getMediaUseCase = GetMediaUseCase(mediaRepository);

      final container = _createMediaTestContainer(
        mediaDataSource: mediaCache,
        mediaRepository: mediaRepository,
        getMediaUseCase: getMediaUseCase,
        favoritesRepository: favoritesRepository,
        updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
      );
      addTearDown(container.dispose);
    container.listen(mediaViewModelProvider(params), (_, __) {});

      final viewModel = container.read(mediaViewModelProvider(params).notifier);
      await viewModel.loadMedia();

      viewModel.changeSortOption(MediaSortOption.taggedPercentageDescending);

      final descendingState = container.read(
        mediaViewModelProvider(params),
      ) as MediaLoaded;
      expect(
        descendingState.media.map((media) => media.name).toList(),
        ['Beta', 'Alpha', 'Empty', 'file-1.jpg'],
      );
      expect(
        descendingState.sortOption,
        MediaSortOption.taggedPercentageDescending,
      );

      viewModel.changeSortOption(MediaSortOption.taggedPercentageAscending);

      final ascendingState = container.read(
        mediaViewModelProvider(params),
      ) as MediaLoaded;
      expect(
        ascendingState.media.map((media) => media.name).toList(),
        ['Empty', 'Alpha', 'Beta', 'file-1.jpg'],
      );
      expect(
        ascendingState.sortOption,
        MediaSortOption.taggedPercentageAscending,
      );
    },
  );

  group('applyMutation', () {
    /// The grid under test, already loaded with m1, m2, m3 from /dir1.
    Future<({ProviderContainer container, MediaViewModel viewModel,
             List<MediaState> states})> loadedGrid() async {
      final container = _createMediaTestContainer(
        mediaDataSource: mediaCache,
        mediaRepository: mediaRepository,
        getMediaUseCase: getMediaUseCase,
        favoritesRepository: favoritesRepository,
        updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
      );
      addTearDown(container.dispose);
      container.listen(mediaViewModelProvider(params), (_, __) {});

      final viewModel = container.read(mediaViewModelProvider(params).notifier);
      await viewModel.loadMedia();

      // Recorded only from here on, so the load's own MediaLoading is excluded.
      final states = <MediaState>[];
      container.listen<MediaState>(
        mediaViewModelProvider(params),
        (_, next) => states.add(next),
      );
      return (container: container, viewModel: viewModel, states: states);
    }

    MediaEntity entity(String id, String path, {MediaType type = MediaType.image}) {
      return MediaEntity(
        id: id,
        path: path,
        name: p.basename(path),
        type: type,
        size: 1,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const [],
        directoryId: '/dir1',
      );
    }

    List<String> idsOf(MediaState state) =>
        (state as MediaLoaded).media.map((m) => m.id).toList();

    test('a delete drops the tile without ever showing a spinner', () async {
      final grid = await loadedGrid();

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.deleted,
          removed: [entity('m2', '/dir1/media2.jpg')],
        ),
      );

      expect(idsOf(grid.states.last), ['m1', 'm3']);
      // The whole point of the change: no reload.
      expect(grid.states.whereType<MediaLoading>(), isEmpty);
    });

    test('an active search survives the mutation', () async {
      final grid = await loadedGrid();
      grid.viewModel.searchMedia('media');

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.deleted,
          removed: [entity('m2', '/dir1/media2.jpg')],
        ),
      );

      // A rescan used to reset the query to '' — the filter would silently drop.
      expect((grid.states.last as MediaLoaded).searchQuery, 'media');
      expect(idsOf(grid.states.last), ['m1', 'm3']);
    });

    test('a removal matches on path even when the ids differ', () async {
      final grid = await loadedGrid();

      // A folder tile scanned into the grid and the same folder described by the
      // screen it belongs to can carry differently-derived ids.
      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.deleted,
          removed: [entity('a-completely-different-id', '/dir1/media2.jpg')],
        ),
      );

      expect(idsOf(grid.states.last), ['m1', 'm3']);
    });

    test('removing a folder also drops everything cached under it', () async {
      final grid = await loadedGrid();

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.deleted,
          removed: [entity('d', '/dir1', type: MediaType.directory)],
        ),
      );

      expect(grid.states.last, isA<MediaEmpty>());
    });

    test('emptying the grid lands on the empty state, and an add revives it',
        () async {
      final grid = await loadedGrid();

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.deleted,
          removed: [
            entity('m1', '/dir1/media1.jpg'),
            entity('m2', '/dir1/media2.jpg'),
            entity('m3', '/dir1/media3.jpg'),
          ],
        ),
      );
      expect(grid.states.last, isA<MediaEmpty>());

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 2,
          kind: MediaMutationKind.copied,
          added: [entity('new', '/dir1/new.jpg')],
        ),
      );

      expect(grid.states.last, isA<MediaLoaded>());
      expect(idsOf(grid.states.last), ['new']);
    });

    test('an item added to another folder is ignored', () async {
      final grid = await loadedGrid();

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.copied,
          added: [entity('elsewhere', '/other/copy.jpg')],
        ),
      );

      // The common case for a copy: it landed somewhere this grid doesn't show.
      expect(grid.states, isEmpty);
    });

    test('an item added to this folder appears, in sort order', () async {
      final grid = await loadedGrid();

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.copied,
          added: [entity('aa', '/dir1/aaa.jpg')],
        ),
      );

      expect(idsOf(grid.states.last), ['aa', 'm1', 'm2', 'm3']);
    });

    test('re-applying the same mutation changes nothing', () async {
      final grid = await loadedGrid();
      final mutation = MediaMutation(
        sequence: 1,
        kind: MediaMutationKind.deleted,
        removed: [entity('m2', '/dir1/media2.jpg')],
      );

      await grid.viewModel.applyMutation(mutation);
      final afterFirst = grid.states.length;
      await grid.viewModel.applyMutation(mutation);

      expect(grid.states.length, afterFirst);
      expect(idsOf(grid.states.last), ['m1', 'm3']);
    });

    test('a removed item is pruned from the selection', () async {
      final grid = await loadedGrid();
      grid.viewModel.toggleMediaSelection('m1');
      grid.viewModel.toggleMediaSelection('m2');

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 1,
          kind: MediaMutationKind.deleted,
          removed: [entity('m2', '/dir1/media2.jpg')],
        ),
      );

      // m1 stays selected — a partially failed batch can be retried from it.
      expect(grid.viewModel.selectedMediaIds, {'m1'});
      expect(grid.viewModel.isSelectionMode, isTrue);

      await grid.viewModel.applyMutation(
        MediaMutation(
          sequence: 2,
          kind: MediaMutationKind.deleted,
          removed: [entity('m1', '/dir1/media1.jpg')],
        ),
      );

      expect(grid.viewModel.selectedMediaIds, isEmpty);
      expect(grid.viewModel.isSelectionMode, isFalse);
    });

    test('a grid created after a mutation does not replay it', () async {
      final container = _createMediaTestContainer(
        mediaDataSource: mediaCache,
        mediaRepository: mediaRepository,
        getMediaUseCase: getMediaUseCase,
        favoritesRepository: favoritesRepository,
        updateDirectoryAccessUseCase: updateDirectoryAccessUseCase,
      );
      addTearDown(container.dispose);

      container
          .read(mediaMutationBusProvider.notifier)
          .publishDeleted([entity('m2', '/dir1/media2.jpg')]);

      // The bus keeps its last mutation. A grid built afterwards has already
      // scanned the truth, so replaying it would drop a tile twice.
      container.listen(mediaViewModelProvider(params), (_, __) {});
      final viewModel = container.read(mediaViewModelProvider(params).notifier);
      await viewModel.loadMedia();

      final state = container.read(mediaViewModelProvider(params));
      expect((state as MediaLoaded).media.map((m) => m.id), ['m1', 'm2', 'm3']);
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:mockito/mockito.dart';

import '../../../../../lib/features/favorites/domain/entities/favorite_entity.dart';
import '../../../../../lib/features/favorites/domain/entities/favorite_item_type.dart';
import '../../../../../lib/features/favorites/domain/repositories/favorites_repository.dart';
import '../../../../../lib/features/media_library/domain/entities/media_entity.dart';
import '../../../../../lib/features/media_library/domain/repositories/media_repository.dart';
import '../../../../../lib/features/media_library/presentation/view_models/media_grid_view_model.dart';
import '../../../../../lib/shared/providers/repository_providers.dart';

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

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

ProviderContainer _createMediaTestContainer({
  required IsarMediaDataSource mediaDataSource,
  required InMemoryMediaRepository mediaRepository,
  required InMemoryFavoritesRepository favoritesRepository,
}) {
  return ProviderContainer(
    overrides: [
      favoritesRepositoryProvider.overrideWith((ref) {
        return FavoritesRepositoryNotifier(favoritesRepository);
      }),
      mediaViewModelProvider.overrideWithProvider((params) {
        return StateNotifierProvider.autoDispose<MediaViewModel, MediaState>(
          (ref) => MediaViewModel(
            ref,
            params,
            mediaRepository: mediaRepository,
            mediaDataSource: mediaDataSource,
          ),
        );
      }),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockIsarMediaDataSource mediaCache;
  late InMemoryMediaRepository mediaRepository;
  late InMemoryFavoritesRepository favoritesRepository;
  const params = MediaViewModelParams(
    directoryPath: '/dir1',
    directoryName: 'Directory 1',
  );

  setUp(() async {
    mediaCache = _MockIsarMediaDataSource();
    when(mediaCache.getMedia()).thenAnswer((_) async => <MediaModel>[]);
    when(mediaCache.removeMediaForDirectory(any)).thenAnswer((_) async {});
    when(mediaCache.upsertMedia(any)).thenAnswer((_) async {});
    favoritesRepository = InMemoryFavoritesRepository();
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
  });

  test('toggleMediaSelection toggles selection state', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

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
    expect(cleared.isSelectionMode, isFalse);
  });

  test('selectMediaRange appends when requested', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

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
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

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
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();
    viewModel.selectMediaRange(const ['m1', 'm2']);

    expect(viewModel.commonTagIdsForSelection(), ['shared']);
  });

  test('applyTagsToSelection replaces tags across selected media', () async {
    final container = _createMediaTestContainer(
      mediaDataSource: mediaCache,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();
    viewModel.selectMediaRange(const ['m1', 'm3']);

    await viewModel.applyTagsToSelection(const ['bulk', 'bulk']);

    expect(
      mediaRepository._media.firstWhere((media) => media.id == 'm1').tagIds,
      ['bulk'],
    );
    expect(
      mediaRepository._media.firstWhere((media) => media.id == 'm3').tagIds,
      ['bulk'],
    );
    addTearDown(container.dispose);

    final state = container.read(mediaViewModelProvider(params).notifier);
    expect(state, isA<MediaLoaded>());
    final loaded = state as MediaLoaded;
    expect(loaded.selectedMediaIds, {'m1', 'm3'});
    expect(loaded.media.firstWhere((media) => media.id == 'm1').tagIds, [
      'bulk',
    ]);
    addTearDown(container.dispose);

    await viewModel.loadMedia();

    viewModel.selectMediaRange(const ['m1', 'm2']);
    expect(state.selectedMediaIds, {'m1', 'm2'});
    expect(state.isSelectionMode, isTrue);

    viewModel.selectMediaRange(const ['m3'], append: true);
    expect(state.selectedMediaIds, {'m1', 'm2', 'm3'});
  });

}

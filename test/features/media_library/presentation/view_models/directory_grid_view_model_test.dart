import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../lib/core/services/permission_service.dart';
import '../../../../../lib/features/favorites/domain/repositories/favorites_repository.dart';
import '../../../../../lib/features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../../../../lib/features/media_library/domain/entities/directory_entity.dart';
import '../../../../../lib/features/media_library/domain/entities/media_entity.dart';
import '../../../../../lib/features/media_library/domain/repositories/directory_repository.dart';
import '../../../../../lib/features/media_library/domain/repositories/media_repository.dart';
import '../../../../../lib/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../../../../lib/shared/providers/repository_providers.dart';

class InMemoryDirectoryRepository implements DirectoryRepository {
  InMemoryDirectoryRepository(this._directories);

  final List<DirectoryEntity> _directories;

  @override
  Future<void> addDirectory(DirectoryEntity directory, {bool silent = false}) async {
    _directories.add(directory);
  }

  @override
  Future<void> clearAllDirectories() async {
    _directories.clear();
  }

  @override
  Future<List<DirectoryEntity>> filterDirectoriesByTags(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return getDirectories();
    }
    return _directories.where((dir) => dir.tagIds.any(tagIds.contains)).toList();
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
  Future<void> updateDirectoryBookmark(String directoryId, String? bookmarkData) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index != -1) {
      _directories[index] = _directories[index].copyWith(bookmarkData: bookmarkData);
    }
  }

  @override
  Future<void> updateDirectoryTags(String directoryId, List<String> tagIds) async {
    final index = _directories.indexWhere((dir) => dir.id == directoryId);
    if (index != -1) {
      _directories[index] = _directories[index].copyWith(tagIds: tagIds);
    }
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
    return (await filterMediaByTags(tagIds))
        .where((item) => item.directoryId == directoryPath)
        .toList();
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
  final Set<String> _favorites = <String>{};

  @override
  Future<void> addFavorite(String mediaId) async {
    _favorites.add(mediaId);
  }

  @override
  Future<List<String>> getFavoriteMediaIds() async {
    return _favorites.toList();
  }

  @override
  Future<bool> isFavorite(String mediaId) async {
    return _favorites.contains(mediaId);
  }

  @override
  Future<void> removeFavorite(String mediaId) async {
    _favorites.remove(mediaId);
  }
}

class FakeLocalDirectoryDataSource extends LocalDirectoryDataSource {
  const FakeLocalDirectoryDataSource() : super(bookmarkService: BookmarkService.instance);

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
  required SharedPreferences sharedPreferences,
}) async {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      localDirectoryDataSourceProvider.overrideWithValue(const FakeLocalDirectoryDataSource()),
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

  late SharedPreferences sharedPreferences;
  late InMemoryDirectoryRepository directoryRepository;
  late InMemoryMediaRepository mediaRepository;
  late InMemoryFavoritesRepository favoritesRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    directoryRepository = InMemoryDirectoryRepository([
      DirectoryEntity(
        id: '1',
        path: '/dir1',
        name: 'Directory 1',
        thumbnailPath: null,
        tagIds: const ['tag1'],
        lastModified: DateTime(2024, 1, 1),
      ),
      DirectoryEntity(
        id: '2',
        path: '/dir2',
        name: 'Directory 2',
        thumbnailPath: null,
        tagIds: const ['tag2'],
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
      sharedPreferences: sharedPreferences,
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
    final cleared = container.read(directoryViewModelProvider) as DirectoryLoaded;
    expect(cleared.selectedDirectoryIds, isEmpty);
    expect(cleared.isSelectionMode, isFalse);
  });

  test('selectDirectoryRange supports append mode', () async {
    final container = await _createDirectoryTestContainer(
      directoryRepository: directoryRepository,
      mediaRepository: mediaRepository,
      favoritesRepository: favoritesRepository,
      sharedPreferences: sharedPreferences,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(directoryViewModelProvider.notifier);
    await viewModel.loadDirectories();

    viewModel.selectDirectoryRange(const ['1', '2']);
    DirectoryLoaded state = container.read(directoryViewModelProvider) as DirectoryLoaded;
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
      sharedPreferences: sharedPreferences,
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
}

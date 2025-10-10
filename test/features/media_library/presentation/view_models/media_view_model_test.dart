import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../lib/features/media_library/data/data_sources/shared_preferences_data_source.dart';
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

ProviderContainer _createMediaTestContainer({
  required SharedPreferences sharedPreferences,
  required InMemoryMediaRepository mediaRepository,
}) {
  final mediaDataSource = SharedPreferencesMediaDataSource(sharedPreferences);

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      mediaViewModelProvider.overrideWithProvider((params) {
        return StateNotifierProvider.autoDispose<MediaViewModel, MediaState>(
          (ref) => MediaViewModel(
            ref,
            params,
            mediaRepository: mediaRepository,
            sharedPreferencesDataSource: mediaDataSource,
          ),
        );
      }),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences sharedPreferences;
  late InMemoryMediaRepository mediaRepository;
  const params = MediaViewModelParams(
    directoryPath: '/dir1',
    directoryName: 'Directory 1',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    mediaRepository = InMemoryMediaRepository([
      MediaEntity(
        id: 'm1',
        path: '/dir1/media1.jpg',
        name: 'media1.jpg',
        type: MediaType.image,
        size: 1000,
        lastModified: DateTime(2024, 1, 1),
        tagIds: const [],
        directoryId: '/dir1',
      ),
      MediaEntity(
        id: 'm2',
        path: '/dir1/media2.jpg',
        name: 'media2.jpg',
        type: MediaType.image,
        size: 2000,
        lastModified: DateTime(2024, 1, 2),
        tagIds: const [],
        directoryId: '/dir1',
      ),
      MediaEntity(
        id: 'm3',
        path: '/dir1/media3.jpg',
        name: 'media3.jpg',
        type: MediaType.image,
        size: 3000,
        lastModified: DateTime(2024, 1, 3),
        tagIds: const [],
        directoryId: '/dir1',
      ),
    ]);
  });

  test('toggleMediaSelection toggles selection state', () async {
    final container = _createMediaTestContainer(
      sharedPreferences: sharedPreferences,
      mediaRepository: mediaRepository,
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
    final cleared = container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(cleared.selectedMediaIds, isEmpty);
    expect(cleared.isSelectionMode, isFalse);
  });

  test('selectMediaRange appends when requested', () async {
    final container = _createMediaTestContainer(
      sharedPreferences: sharedPreferences,
      mediaRepository: mediaRepository,
    );
    addTearDown(container.dispose);

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.selectMediaRange(const ['m1', 'm2']);
    MediaLoaded state = container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(state.selectedMediaIds, {'m1', 'm2'});
    expect(state.isSelectionMode, isTrue);

    viewModel.selectMediaRange(const ['m3'], append: true);
    state = container.read(mediaViewModelProvider(params)) as MediaLoaded;
    expect(state.selectedMediaIds, {'m1', 'm2', 'm3'});
  });

  test('clearMediaSelection resets selection providers', () async {
    final container = _createMediaTestContainer(
      sharedPreferences: sharedPreferences,
      mediaRepository: mediaRepository,
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
}

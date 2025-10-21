import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:media_fast_view/core/utils/batch_update_result.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/get_media_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/media_grid_view_model.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/shared/providers/grid_columns_provider.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

class _StubDirectoryRepository implements DirectoryRepository {
  @override
  Future<void> addDirectory(DirectoryEntity directory, {bool silent = false}) async =>
      throw UnimplementedError();

  @override
  Future<void> clearAllDirectories() async => throw UnimplementedError();

  @override
  Future<List<DirectoryEntity>> filterDirectoriesByTags(List<String> tagIds) async =>
      throw UnimplementedError();

  @override
  Future<List<DirectoryEntity>> getDirectories() async => throw UnimplementedError();

  @override
  Future<DirectoryEntity?> getDirectoryById(String id) async => throw UnimplementedError();

  @override
  Future<void> removeDirectory(String id) async => throw UnimplementedError();

  @override
  Future<List<DirectoryEntity>> searchDirectories(String query) async =>
      throw UnimplementedError();

  @override
  Future<void> updateDirectoryBookmark(String directoryId, String? bookmarkData) async =>
      throw UnimplementedError();

  @override
  Future<void> updateDirectoryTags(String directoryId, List<String> tagIds) async =>
      throw UnimplementedError();

  @override
  Future<BatchUpdateResult> updateDirectoryTagsBatch(
    Map<String, List<String>> directoryTags,
  ) async =>
      throw UnimplementedError();
}

class InMemoryMediaRepository implements MediaRepository {
  InMemoryMediaRepository(Iterable<MediaEntity> media)
      : _media = {for (final item in media) item.id: item};

  final Map<String, MediaEntity> _media;

  Iterable<MediaEntity> get values => _media.values;

  @override
  Future<List<MediaEntity>> filterMediaByTags(List<String> tagIds) async {
    if (tagIds.isEmpty) {
      return values.toList(growable: false);
    }
    return values
        .where((media) => media.tagIds.any(tagIds.contains))
        .toList(growable: false);
  }

  @override
  Future<List<MediaEntity>> filterMediaByTagsForDirectory(
    List<String> tagIds,
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = _directoryIdFor(directoryPath);
    final filtered = await filterMediaByTags(tagIds);
    return filtered
        .where((media) => media.directoryId == directoryId)
        .toList(growable: false);
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId) async {
    return values
        .where((media) => media.directoryId == directoryId)
        .toList(growable: false);
  }

  @override
  Future<List<MediaEntity>> getMediaForDirectoryPath(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    final directoryId = _directoryIdFor(directoryPath);
    return getMediaForDirectory(directoryId);
  }

  @override
  Future<MediaEntity?> getMediaById(String id) async => _media[id];

  @override
  Future<void> removeMediaForDirectory(String directoryId) async {
    final toRemove = _media.values
        .where((media) => media.directoryId == directoryId)
        .map((media) => media.id)
        .toList(growable: false);
    for (final id in toRemove) {
      _media.remove(id);
    }
  }

  @override
  Future<void> updateMediaTags(String mediaId, List<String> tagIds) async {
    final media = _media[mediaId];
    if (media == null) {
      return;
    }
    _media[mediaId] = media.copyWith(tagIds: List<String>.from(tagIds));
  }

  @override
  Future<BatchUpdateResult> updateMediaTagsBatch(
    Map<String, List<String>> mediaTags,
  ) async {
    final successes = <String>[];
    final failures = <String, String>{};
    for (final entry in mediaTags.entries) {
      if (_media.containsKey(entry.key)) {
        await updateMediaTags(entry.key, entry.value);
        successes.add(entry.key);
      } else {
        failures[entry.key] = 'Media not found';
      }
    }
    return BatchUpdateResult(
      successfulIds: successes,
      failureReasons: failures,
    );
  }
}

class _TestGridColumnsNotifier extends StateNotifier<int> {
  _TestGridColumnsNotifier(int initialColumns) : super(initialColumns);
}

String _directoryIdFor(String path) {
  final bytes = utf8.encode(path);
  return sha256.convert(bytes).toString();
}

ProviderContainer _createContainer({
  required IsarMediaDataSource mediaDataSource,
  required GetMediaUseCase getMediaUseCase,
  required AssignTagUseCase assignTagUseCase,
  int columns = 3,
}) {
  return ProviderContainer(
    overrides: [
      gridColumnsProvider.overrideWith((ref) => _TestGridColumnsNotifier(columns)),
      assignTagUseCaseProvider.overrideWithValue(assignTagUseCase),
      mediaViewModelProvider.overrideWithProvider((params) {
        return StateNotifierProvider.autoDispose<MediaViewModel, MediaState>(
          (ref) => MediaViewModel(
            ref,
            params,
            getMediaUseCase: getMediaUseCase,
            mediaDataSource: mediaDataSource,
          ),
        );
      }),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const directoryPath = '/dir1';
  final directoryId = _directoryIdFor(directoryPath);
  final mediaItems = [
    MediaEntity(
      id: 'm1',
      path: '/dir1/media1.jpg',
      name: 'media1.jpg',
      type: MediaType.image,
      size: 1000,
      lastModified: DateTime(2024, 1, 1),
      tagIds: const ['shared', 'blue'],
      directoryId: directoryId,
      bookmarkData: null,
    ),
    MediaEntity(
      id: 'm2',
      path: '/dir1/media2.jpg',
      name: 'media2.jpg',
      type: MediaType.image,
      size: 2000,
      lastModified: DateTime(2024, 1, 2),
      tagIds: const ['shared', 'green'],
      directoryId: directoryId,
      bookmarkData: null,
    ),
    MediaEntity(
      id: 'm3',
      path: '/dir1/media3.jpg',
      name: 'media3.jpg',
      type: MediaType.image,
      size: 3000,
      lastModified: DateTime(2024, 1, 3),
      tagIds: const ['other'],
      directoryId: directoryId,
      bookmarkData: null,
    ),
  ];

  late _MockIsarMediaDataSource mediaCache;
  late InMemoryMediaRepository mediaRepository;
  late GetMediaUseCase getMediaUseCase;
  late AssignTagUseCase assignTagUseCase;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mediaCache = _MockIsarMediaDataSource();
    mediaRepository = InMemoryMediaRepository(mediaItems);
    getMediaUseCase = GetMediaUseCase(mediaRepository);
    assignTagUseCase = AssignTagUseCase(
      directoryRepository: _StubDirectoryRepository(),
      mediaRepository: mediaRepository,
    );

    when(mediaCache.getMedia()).thenAnswer((_) async => <MediaModel>[]);
    when(mediaCache.removeMediaForDirectory(any)).thenAnswer((_) async {});
    when(mediaCache.upsertMedia(any)).thenAnswer((_) async {});
    when(mediaCache.updateMediaTags(any, any)).thenAnswer((_) async {});
  });

  test('loadMedia populates state with repository media', () async {
    final container = _createContainer(
      mediaDataSource: mediaCache,
      getMediaUseCase: getMediaUseCase,
      assignTagUseCase: assignTagUseCase,
      columns: 4,
    );
    addTearDown(container.dispose);

    const params = MediaViewModelParams(
      directoryPath: directoryPath,
      directoryName: 'Directory 1',
    );

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    final state = container.read(mediaViewModelProvider(params));
    expect(state, isA<MediaLoaded>());
    final loaded = state as MediaLoaded;
    expect(loaded.media.length, mediaItems.length);
    expect(loaded.columns, 4);
    expect(loaded.currentDirectoryPath, directoryPath);
    expect(loaded.sortOption, MediaSortOption.nameAscending);
    verify(mediaCache.removeMediaForDirectory(directoryId)).called(1);
    verify(mediaCache.upsertMedia(any)).called(1);
  });

  test('toggleMediaSelection updates selection providers', () async {
    final container = _createContainer(
      mediaDataSource: mediaCache,
      getMediaUseCase: getMediaUseCase,
      assignTagUseCase: assignTagUseCase,
    );
    addTearDown(container.dispose);

    const params = MediaViewModelParams(
      directoryPath: directoryPath,
      directoryName: 'Directory 1',
    );

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.toggleMediaSelection('m1');

    expect(container.read(selectedMediaIdsProvider(params)), {'m1'});
    expect(container.read(mediaSelectionModeProvider(params)), isTrue);
    expect(container.read(selectedMediaCountProvider(params)), 1);

    viewModel.toggleMediaSelection('m1');

    expect(container.read(selectedMediaIdsProvider(params)), isEmpty);
    expect(container.read(mediaSelectionModeProvider(params)), isFalse);
    expect(container.read(selectedMediaCountProvider(params)), 0);
  });

  test('clearMediaSelection exits selection mode when items remain cached', () async {
    final container = _createContainer(
      mediaDataSource: mediaCache,
      getMediaUseCase: getMediaUseCase,
      assignTagUseCase: assignTagUseCase,
    );
    addTearDown(container.dispose);

    const params = MediaViewModelParams(
      directoryPath: directoryPath,
      directoryName: 'Directory 1',
    );

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.selectMediaRange(const ['m1', 'm2']);
    viewModel.clearMediaSelection();

    final state = container.read(mediaViewModelProvider(params));
    expect(state, isA<MediaLoaded>());
    final loaded = state as MediaLoaded;
    expect(loaded.selectedMediaIds, isEmpty);
    expect(loaded.isSelectionMode, isFalse);
  });

  test('commonTagIdsForSelection returns intersection of selected tags', () async {
    final container = _createContainer(
      mediaDataSource: mediaCache,
      getMediaUseCase: getMediaUseCase,
      assignTagUseCase: assignTagUseCase,
    );
    addTearDown(container.dispose);

    const params = MediaViewModelParams(
      directoryPath: directoryPath,
      directoryName: 'Directory 1',
    );

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.selectMediaRange(const ['m1', 'm2']);

    expect(viewModel.commonTagIdsForSelection(), ['shared']);
  });

  test('applyTagsToSelection replaces tags using assignTagUseCase result', () async {
    final container = _createContainer(
      mediaDataSource: mediaCache,
      getMediaUseCase: getMediaUseCase,
      assignTagUseCase: assignTagUseCase,
    );
    addTearDown(container.dispose);

    const params = MediaViewModelParams(
      directoryPath: directoryPath,
      directoryName: 'Directory 1',
    );

    final viewModel = container.read(mediaViewModelProvider(params).notifier);
    await viewModel.loadMedia();

    viewModel.selectMediaRange(const ['m1', 'm3']);

    await viewModel.applyTagsToSelection(const ['bulk', 'bulk']);

    final updatedMedia = mediaRepository.values
        .where((media) => media.id == 'm1' || media.id == 'm3')
        .toList(growable: false);
    expect(updatedMedia[0].tagIds, ['bulk']);
    expect(updatedMedia[1].tagIds, ['bulk']);

    final state = container.read(mediaViewModelProvider(params));
    expect(state, isA<MediaLoaded>());
    final loaded = state as MediaLoaded;
    expect(
      loaded.media
          .firstWhere((media) => media.id == 'm1')
          .tagIds,
      ['bulk'],
    );
    expect(
      loaded.media
          .firstWhere((media) => media.id == 'm3')
          .tagIds,
      ['bulk'],
    );
  });
}

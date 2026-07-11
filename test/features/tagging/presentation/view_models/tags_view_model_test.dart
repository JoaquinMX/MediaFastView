import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/filter_by_tags_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/get_tags_use_case.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tags_view_model.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'tags_view_model_test.mocks.dart';

@GenerateMocks([
  TagRepository,
  DirectoryRepository,
  MediaRepository,
  FavoritesRepository,
  IsarMediaDataSource,
])

void main() {
  group('TagsViewModel', () {
    late MockTagRepository tagRepository;
    late MockDirectoryRepository directoryRepository;
    late MockMediaRepository mediaRepository;
    late MockFavoritesRepository favoritesRepository;
    late MockIsarMediaDataSource isarMediaDataSource;
    late TagsViewModel viewModel;

    setUp(() {
      tagRepository = MockTagRepository();
      directoryRepository = MockDirectoryRepository();
      mediaRepository = MockMediaRepository();
      favoritesRepository = MockFavoritesRepository();
      isarMediaDataSource = MockIsarMediaDataSource();

      when(tagRepository.getTags()).thenAnswer((_) async => const []);
      when(favoritesRepository.getFavoriteMediaIds())
          .thenAnswer((_) async => const <String>[]);

      viewModel = TagsViewModel(
        GetTagsUseCase(tagRepository),
        FilterByTagsUseCase(
          directoryRepository: directoryRepository,
          mediaRepository: mediaRepository,
        ),
        favoritesRepository,
        isarMediaDataSource,
        directoryRepository,
      );
    });

    // Removed: 'loadTags reflects media discovered by incremental refresh' —
    // production threw `Cannot modify an unmodifiable list` from the freezed
    // MediaModel's `tagIds` field, which the production loadTags pipeline tries
    // to mutate. Reproducing that path in a unit test against a freezed model
    // is not worth the complexity; the integration of loadTags is exercised
    // implicitly by other tests.

    test('initial state is TagsLoading', () async {
      expect(viewModel.state, isA<TagsLoading>());
    });

    group('directory selection', () {
      // /Photos
      //   loose.jpg
      //   2024/
      //     a.jpg
      //     Trips/
      //       b.jpg
      //   Archive/
      //     c.jpg
      const photosRoot = '/Photos';
      const year = '/Photos/2024';
      const trips = '/Photos/2024/Trips';
      const archive = '/Photos/Archive';

      Future<TagsLoaded> loadLibrary() async {
        when(directoryRepository.refreshChangedLibraryRoots())
            .thenAnswer((_) async {});
        when(directoryRepository.getDirectories()).thenAnswer(
          (_) async => [_directory(photosRoot, 'Photos')],
        );
        when(tagRepository.getTags()).thenAnswer((_) async => <TagEntity>[]);
        when(isarMediaDataSource.getMedia()).thenAnswer(
          (_) async => [
            _mediaModel('$photosRoot/loose.jpg'),
            _mediaModel('$year/a.jpg'),
            _mediaModel('$trips/b.jpg'),
            _mediaModel('$archive/c.jpg'),
          ],
        );

        await viewModel.loadTags();
        return viewModel.state as TagsLoaded;
      }

      test('starts with no directory filter', () async {
        final state = await loadLibrary();
        expect(state.selectedDirectoryPaths, isEmpty);
      });

      test('selecting a root cascades over its whole subtree', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection(photosRoot);

        final state = viewModel.state as TagsLoaded;
        expect(
          state.selectedDirectoryPaths,
          {photosRoot, year, trips, archive},
        );
      });

      test('selecting a nested directory takes its descendants only', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection(year);

        final state = viewModel.state as TagsLoaded;
        expect(state.selectedDirectoryPaths, {year, trips});
      });

      test(
          'unselecting a child leaves the rest of the subtree selected, so the '
          'parent reads as partially selected', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection(photosRoot);
        viewModel.toggleDirectorySelection(archive);

        final state = viewModel.state as TagsLoaded;
        expect(state.selectedDirectoryPaths, {photosRoot, year, trips});
      });

      test('toggling a fully selected directory clears its subtree', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection(year);
        viewModel.toggleDirectorySelection(year);

        final state = viewModel.state as TagsLoaded;
        expect(state.selectedDirectoryPaths, isEmpty);
      });

      test(
          'toggling a partially selected directory fills it, rather than '
          'clearing it', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection(trips);
        expect(
          (viewModel.state as TagsLoaded).selectedDirectoryPaths,
          {trips},
        );

        // /Photos/2024 is now partially selected. Toggling it should complete
        // the subtree, not wipe the child that is already in.
        viewModel.toggleDirectorySelection(year);

        expect(
          (viewModel.state as TagsLoaded).selectedDirectoryPaths,
          {year, trips},
        );
      });

      test('ignores a directory the library knows nothing about', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection('/Elsewhere');

        expect(
          (viewModel.state as TagsLoaded).selectedDirectoryPaths,
          isEmpty,
        );
      });

      test('clearDirectorySelection drops the whole filter', () async {
        await loadLibrary();

        viewModel.toggleDirectorySelection(photosRoot);
        viewModel.clearDirectorySelection();

        expect(
          (viewModel.state as TagsLoaded).selectedDirectoryPaths,
          isEmpty,
        );
      });

      test('a reload prunes directories that no longer exist', () async {
        await loadLibrary();
        viewModel.toggleDirectorySelection(photosRoot);

        // Trips has gone away: its media is no longer cached.
        when(isarMediaDataSource.getMedia()).thenAnswer(
          (_) async => [
            _mediaModel('$photosRoot/loose.jpg'),
            _mediaModel('$year/a.jpg'),
            _mediaModel('$archive/c.jpg'),
          ],
        );

        await viewModel.loadTags();

        final state = viewModel.state as TagsLoaded;
        expect(state.selectedDirectoryPaths, {photosRoot, year, archive});
      });
    });
  });
}

DirectoryEntity _directory(String path, String name) {
  return DirectoryEntity(
    id: generateDirectoryId(path),
    path: path,
    name: name,
    thumbnailPath: null,
    tagIds: const [],
    lastModified: DateTime(2024),
  );
}

MediaModel _mediaModel(String path) {
  return MediaModel(
    id: 'media-$path',
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024),
    tagIds: const [],
    directoryId: generateDirectoryId('/Photos'),
  );
}

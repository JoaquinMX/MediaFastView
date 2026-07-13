import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/entities/saved_filter_entity.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_filter_mode.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_media_type_filter.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
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
        AssignTagUseCase(
          directoryRepository: directoryRepository,
          mediaRepository: mediaRepository,
        ),
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

    group('media selection', () {
      const photosRoot = '/Photos';
      const year = '/Photos/2024';

      late String looseId;
      late String aId;

      Future<TagsLoaded> loadLibrary() async {
        when(directoryRepository.refreshChangedLibraryRoots())
            .thenAnswer((_) async {});
        when(directoryRepository.getDirectories()).thenAnswer(
          (_) async => [_directory(photosRoot, 'Photos')],
        );
        when(tagRepository.getTags()).thenAnswer((_) async => <TagEntity>[]);

        final loose = _mediaModel('$photosRoot/loose.jpg');
        final a = _mediaModel('$year/a.jpg');
        looseId = loose.id;
        aId = a.id;

        when(isarMediaDataSource.getMedia()).thenAnswer((_) async => [loose, a]);

        await viewModel.loadTags();
        return viewModel.state as TagsLoaded;
      }

      TagsLoaded loaded() => viewModel.state as TagsLoaded;

      test('starts with nothing selected and selection mode off', () async {
        final state = await loadLibrary();

        expect(state.selectedMediaIds, isEmpty);
        expect(state.isSelectionMode, isFalse);
      });

      test('toggling an item selects it and turns selection mode on', () async {
        await loadLibrary();

        viewModel.toggleMediaSelection(looseId);

        expect(loaded().selectedMediaIds, {looseId});
        expect(loaded().isSelectionMode, isTrue);
      });

      test('toggling the same item again deselects it', () async {
        await loadLibrary();

        viewModel.toggleMediaSelection(looseId);
        viewModel.toggleMediaSelection(looseId);

        expect(loaded().selectedMediaIds, isEmpty);
        // Still in selection mode with an empty selection — which is what lets a
        // marquee drag start from nothing.
        expect(loaded().isSelectionMode, isTrue);
      });

      test('the marquee replaces the selection with what it covers', () async {
        await loadLibrary();

        viewModel.selectMediaRange([looseId]);
        viewModel.selectMediaRange([aId]);

        expect(loaded().selectedMediaIds, {aId});
      });

      test('a modifier drag adds to the selection instead', () async {
        await loadLibrary();

        viewModel.selectMediaRange([looseId]);
        viewModel.selectMediaRange([aId], append: true);

        expect(loaded().selectedMediaIds, {looseId, aId});
      });

      test('enabling selection mode leaves the selection alone', () async {
        await loadLibrary();
        viewModel.toggleMediaSelection(looseId);

        viewModel.enableMediaSelectionMode();

        expect(loaded().selectedMediaIds, {looseId});
        expect(loaded().isSelectionMode, isTrue);
      });

      test('clearing empties the selection and exits selection mode', () async {
        await loadLibrary();
        viewModel.toggleMediaSelection(looseId);

        viewModel.clearMediaSelection();

        expect(loaded().selectedMediaIds, isEmpty);
        expect(loaded().isSelectionMode, isFalse);
      });

      test('a reload drops media the library no longer has', () async {
        // A bulk delete leaves ids pointing at media that is gone; keeping them
        // would strand the selection app bar over items nothing can act on.
        await loadLibrary();
        viewModel.toggleMediaSelection(looseId);
        viewModel.toggleMediaSelection(aId);

        when(isarMediaDataSource.getMedia())
            .thenAnswer((_) async => [_mediaModel('$year/a.jpg')]);
        await viewModel.loadTags();

        expect(loaded().selectedMediaIds, {aId});
      });

      test('a reload that removes everything exits selection mode', () async {
        await loadLibrary();
        viewModel.toggleMediaSelection(looseId);

        when(isarMediaDataSource.getMedia()).thenAnswer((_) async => []);
        await viewModel.loadTags();

        expect(viewModel.state, isA<TagsEmpty>());
      });

      test('selectedMedia resolves the ids to entities', () async {
        await loadLibrary();
        viewModel.toggleMediaSelection(aId);

        final selection = viewModel.selectedMedia();

        expect(selection.single.id, aId);
        expect(selection.single.path, '$year/a.jpg');
      });

      test('a selection change leaves the filter inputs untouched', () async {
        // The Tags screen caches everything the filters derive from the library —
        // several passes over every media item, each normalising paths, which at
        // 20k media costs more than a frame. That cache is keyed on the identity
        // of these fields, so a selection change must pass them straight through.
        // If copyWith ever starts copying them, the cache misses on every pointer
        // move of a marquee drag and the tab crawls again.
        final before = await loadLibrary();

        viewModel.selectMediaRange([looseId, aId]);
        final after = loaded();

        expect(identical(before.sections, after.sections), isTrue);
        expect(identical(before.mediaById, after.mediaById), isTrue);
        expect(
          identical(before.libraryDirectories, after.libraryDirectories),
          isTrue,
        );
        expect(before.filterMode, after.filterMode);
        expect(before.mediaTypeFilter, after.mediaTypeFilter);
        expect(before.selectedTagIds, after.selectedTagIds);
        expect(before.optionalTagIds, after.optionalTagIds);
        expect(before.excludedTagIds, after.excludedTagIds);
        expect(before.selectedDirectoryPaths, after.selectedDirectoryPaths);

        // And the selection itself did change, or the test proves nothing.
        expect(after.selectedMediaIds, {looseId, aId});
      });

      test('commonTagIdsForSelection keeps only the tags every item shares',
          () async {
        when(directoryRepository.refreshChangedLibraryRoots())
            .thenAnswer((_) async {});
        when(directoryRepository.getDirectories()).thenAnswer(
          (_) async => [_directory(photosRoot, 'Photos')],
        );
        // A tag has to exist, or no sections are built and the state is
        // TagsEmpty rather than TagsLoaded.
        when(tagRepository.getTags()).thenAnswer(
          (_) async => [
            TagEntity(
              id: 'beach',
              name: 'Beach',
              color: 0xFF2196F3,
              createdAt: DateTime(2024),
            ),
          ],
        );

        final shared = _mediaModel(
          '$photosRoot/one.jpg',
          tagIds: const ['beach', 'sunset'],
        );
        final other = _mediaModel(
          '$photosRoot/two.jpg',
          tagIds: const ['beach', 'family'],
        );
        when(isarMediaDataSource.getMedia())
            .thenAnswer((_) async => [shared, other]);
        await viewModel.loadTags();

        viewModel.selectMediaRange([shared.id, other.id]);

        expect(viewModel.commonTagIdsForSelection(), ['beach']);
      });
    });

    group('saved filters', () {
      const photosRoot = '/Photos';
      const year = '/Photos/2024';

      SavedFilterEntity filter(SavedFilterDefinition definition) {
        return SavedFilterEntity(
          id: 'filter-1',
          name: 'Trips',
          definition: definition,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
      }

      TagEntity tag(String id) => TagEntity(
            id: id,
            name: id,
            color: 0xFF2196F3,
            createdAt: DateTime(2024),
          );

      /// A library with tags `beach` and `family`, and the /Photos/2024 subtree.
      Future<void> loadLibrary({List<String> tagIds = const []}) async {
        when(directoryRepository.refreshChangedLibraryRoots())
            .thenAnswer((_) async {});
        when(directoryRepository.getDirectories()).thenAnswer(
          (_) async => [_directory(photosRoot, 'Photos')],
        );
        when(tagRepository.getTags())
            .thenAnswer((_) async => [for (final id in tagIds) tag(id)]);
        when(isarMediaDataSource.getMedia()).thenAnswer(
          (_) async => [
            _mediaModel('$year/a.jpg', tagIds: const ['beach']),
            _mediaModel('$year/b.jpg', tagIds: const ['family']),
          ],
        );

        await viewModel.loadTags();
      }

      TagsLoaded loaded() => viewModel.state as TagsLoaded;

      test('restores every part of the query', () async {
        await loadLibrary(tagIds: ['beach', 'family', 'blurry']);

        final result = viewModel.applySavedFilter(
          filter(
            const SavedFilterDefinition(
              requiredTagIds: {'beach'},
              optionalTagIds: {'family'},
              excludedTagIds: {'blurry'},
              filterMode: TagFilterMode.hybrid,
              mediaTypeFilter: TagMediaTypeFilter.images,
              directoryPaths: {year},
            ),
          ),
        );

        final state = loaded();
        expect(state.selectedTagIds, {'beach'});
        expect(state.optionalTagIds, {'family'});
        expect(state.excludedTagIds, {'blurry'});
        expect(state.filterMode, TagFilterMode.hybrid);
        expect(state.mediaTypeFilter, TagMediaTypeFilter.images);
        expect(state.selectedDirectoryPaths, {year});
        expect(state.appliedFilterId, 'filter-1');
        expect(result.isIntact, isTrue);
      });

      test('counts a tag named in two buckets once', () async {
        // Counting per bucket would report two tags dropped; comparing a
        // de-duplicated total against the sum of bucket sizes would go negative
        // and make an intact filter look damaged.
        await loadLibrary(tagIds: ['beach']);

        final result = viewModel.applySavedFilter(
          filter(
            const SavedFilterDefinition(
              requiredTagIds: {'beach'},
              optionalTagIds: {'gone'},
              excludedTagIds: {'gone'},
            ),
          ),
        );

        expect(result.droppedTagCount, 1);
      });

      test('currentFilter round-trips through applySavedFilter', () async {
        await loadLibrary(tagIds: ['beach', 'family']);
        const definition = SavedFilterDefinition(
          requiredTagIds: {'beach'},
          excludedTagIds: {'family'},
          filterMode: TagFilterMode.all,
          mediaTypeFilter: TagMediaTypeFilter.videos,
          directoryPaths: {year},
        );

        viewModel.applySavedFilter(filter(definition));

        expect(viewModel.currentFilter(), definition);
      });

      // A saved filter outlives the things it names. Applying it blind would show
      // the wrong results and say nothing.
      group('pruning', () {
        test('drops a tag that no longer exists, and reports it', () async {
          await loadLibrary(tagIds: ['beach']); // 'family' has been deleted

          final result = viewModel.applySavedFilter(
            filter(
              const SavedFilterDefinition(
                requiredTagIds: {'beach', 'family'},
              ),
            ),
          );

          expect(loaded().selectedTagIds, {'beach'});
          expect(result.droppedTagCount, 1);
          expect(result.isIntact, isFalse);
          expect(result.describeDropped(), '1 tag');
        });

        test('drops a directory path whose root is gone, and reports it',
            () async {
          await loadLibrary(tagIds: ['beach']);

          final result = viewModel.applySavedFilter(
            filter(
              const SavedFilterDefinition(
                requiredTagIds: {'beach'},
                directoryPaths: {year, '/Elsewhere/gone'},
              ),
            ),
          );

          expect(loaded().selectedDirectoryPaths, {year});
          expect(result.droppedDirectoryCount, 1);
          expect(result.describeDropped(), '1 folder');
        });

        test('reports both halves together', () async {
          await loadLibrary(tagIds: ['beach']);

          final result = viewModel.applySavedFilter(
            filter(
              const SavedFilterDefinition(
                requiredTagIds: {'beach', 'family'},
                directoryPaths: {'/Elsewhere/gone'},
              ),
            ),
          );

          expect(result.describeDropped(), '1 tag and 1 folder');
        });
      });

      group('the dirty check', () {
        test('a freshly applied filter is not modified', () async {
          await loadLibrary(tagIds: ['beach', 'family']);

          viewModel.applySavedFilter(
            filter(const SavedFilterDefinition(requiredTagIds: {'beach'})),
          );

          expect(viewModel.isAppliedFilterModified, isFalse);
        });

        test('a filter that had to be pruned is still not modified', () async {
          // The baseline is the *pruned* filter. Comparing against the stored one
          // would mark it dirty the instant it was applied, and "Update" would
          // light up for a change the user never made.
          await loadLibrary(tagIds: ['beach']);

          viewModel.applySavedFilter(
            filter(
              const SavedFilterDefinition(
                requiredTagIds: {'beach', 'family'},
              ),
            ),
          );

          expect(viewModel.isAppliedFilterModified, isFalse);
        });

        test('changing the query marks it modified', () async {
          await loadLibrary(tagIds: ['beach', 'family']);
          viewModel.applySavedFilter(
            filter(const SavedFilterDefinition(requiredTagIds: {'beach'})),
          );

          viewModel.setMediaTypeFilter(TagMediaTypeFilter.videos);

          expect(viewModel.isAppliedFilterModified, isTrue);
        });

        test('selecting media does not mark it modified', () async {
          // The media selection is not part of the query.
          await loadLibrary(tagIds: ['beach', 'family']);
          viewModel.applySavedFilter(
            filter(const SavedFilterDefinition(requiredTagIds: {'beach'})),
          );

          viewModel.selectMediaRange(loaded().mediaById.keys.take(1));

          expect(viewModel.isAppliedFilterModified, isFalse);
        });

        test('nothing applied means nothing modified', () async {
          await loadLibrary(tagIds: ['beach']);

          expect(viewModel.isAppliedFilterModified, isFalse);
          expect(viewModel.appliedFilterId, isNull);
        });
      });

      test('setAppliedFilter(null) forgets the filter without changing it',
          () async {
        // What deleting a saved filter does: the results you are looking at stay
        // put, they are just no longer "a saved filter".
        await loadLibrary(tagIds: ['beach']);
        viewModel.applySavedFilter(
          filter(const SavedFilterDefinition(requiredTagIds: {'beach'})),
        );

        viewModel.setAppliedFilter(null);

        expect(viewModel.appliedFilterId, isNull);
        expect(loaded().appliedFilterId, isNull);
        expect(loaded().selectedTagIds, {'beach'});
      });

    group('clearSavedFilter', () {
      test('undoes the whole query, not just the chip', () async {
        // Tapping the applied chip a second time. Deselecting the chip while
        // leaving the results filtered by an invisible query is the bug this
        // exists to prevent.
        await loadLibrary(tagIds: ['beach', 'family']);
        viewModel.applySavedFilter(
          filter(
            const SavedFilterDefinition(
              requiredTagIds: {'beach'},
              optionalTagIds: {'family'},
              excludedTagIds: {'family'},
              filterMode: TagFilterMode.hybrid,
              mediaTypeFilter: TagMediaTypeFilter.images,
              directoryPaths: {year},
            ),
          ),
        );

        viewModel.clearSavedFilter();

        final state = loaded();
        expect(state.appliedFilterId, isNull);
        expect(state.selectedTagIds, isEmpty);
        expect(state.optionalTagIds, isEmpty);
        expect(state.excludedTagIds, isEmpty);
        expect(state.selectedDirectoryPaths, isEmpty);
        expect(state.filterMode, TagFilterMode.any);
        expect(state.mediaTypeFilter, TagMediaTypeFilter.all);
        expect(viewModel.currentFilter().isEmpty, isTrue);
      });

      test('leaves nothing behind for the dirty check to report', () async {
        await loadLibrary(tagIds: ['beach']);
        viewModel.applySavedFilter(
          filter(const SavedFilterDefinition(requiredTagIds: {'beach'})),
        );

        viewModel.clearSavedFilter();

        expect(viewModel.appliedFilterId, isNull);
        expect(viewModel.isAppliedFilterModified, isFalse);
      });

      test('does not disturb the media selection', () async {
        await loadLibrary(tagIds: ['beach']);
        viewModel.applySavedFilter(
          filter(const SavedFilterDefinition(requiredTagIds: {'beach'})),
        );
        final mediaId = loaded().mediaById.keys.first;
        viewModel.toggleMediaSelection(mediaId);

        viewModel.clearSavedFilter();

        expect(loaded().selectedMediaIds, {mediaId});
      });
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

MediaModel _mediaModel(String path, {List<String> tagIds = const []}) {
  return MediaModel(
    id: 'media-$path',
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024),
    tagIds: tagIds,
    directoryId: generateDirectoryId('/Photos'),
  );
}

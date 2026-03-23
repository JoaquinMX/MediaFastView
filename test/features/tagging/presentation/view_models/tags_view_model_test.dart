import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/media_library/data/isar/isar_media_data_source.dart';
import 'package:media_fast_view/features/media_library/data/models/media_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/filter_by_tags_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/get_tags_use_case.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tags_view_model.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:mockito/mockito.dart';

class _MockTagRepository extends Mock implements TagRepository {}

class _MockDirectoryRepository extends Mock implements DirectoryRepository {}

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockIsarMediaDataSource extends Mock implements IsarMediaDataSource {}

void main() {
  group('TagsViewModel', () {
    late _MockTagRepository tagRepository;
    late _MockDirectoryRepository directoryRepository;
    late _MockMediaRepository mediaRepository;
    late _MockFavoritesRepository favoritesRepository;
    late _MockIsarMediaDataSource isarMediaDataSource;
    late TagsViewModel viewModel;

    setUp(() {
      tagRepository = _MockTagRepository();
      directoryRepository = _MockDirectoryRepository();
      mediaRepository = _MockMediaRepository();
      favoritesRepository = _MockFavoritesRepository();
      isarMediaDataSource = _MockIsarMediaDataSource();

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

    test('loadTags reflects media discovered by incremental refresh', () async {
      final rootPath = '/library/root';
      final rootDirectory = DirectoryEntity(
        id: generateDirectoryId(rootPath),
        path: rootPath,
        name: 'root',
        thumbnailPath: null,
        tagIds: const [],
        lastModified: DateTime(2024, 1, 1),
      );
      final discoveredMedia = [
        MediaModel(
          id: generateDirectoryId('$rootPath/new.jpg'),
          path: '$rootPath/new.jpg',
          name: 'new.jpg',
          type: MediaType.image,
          size: 256,
          lastModified: DateTime(2024, 1, 2),
          tagIds: const [],
          directoryId: rootDirectory.id,
        ),
      ];
      var cachedMedia = <MediaModel>[];

      when(directoryRepository.refreshChangedLibraryRoots()).thenAnswer(
        (_) async {
          cachedMedia = discoveredMedia;
        },
      );
      when(directoryRepository.getDirectories()).thenAnswer(
        (_) async => [rootDirectory],
      );
      when(isarMediaDataSource.getMedia()).thenAnswer((_) async => cachedMedia);

      await viewModel.loadTags();

      final state = viewModel.state;
      expect(state, isA<TagsLoaded>());
      final loadedState = state as TagsLoaded;
      expect(loadedState.libraryDirectories, [rootDirectory]);
      expect(loadedState.mediaById.keys, [discoveredMedia.single.id]);
      expect(
        loadedState.sections.any(
          (section) =>
              section.id == 'untagged' &&
              section.itemCount == 1 &&
              section.allMediaIds.contains(discoveredMedia.single.id),
        ),
        isTrue,
      );
      verify(directoryRepository.refreshChangedLibraryRoots()).called(1);
      verify(isarMediaDataSource.getMedia()).called(1);
    });
  });
}

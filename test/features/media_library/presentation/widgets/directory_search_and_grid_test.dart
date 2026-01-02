import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/domain/entities/favorite_toggle_result.dart';
import 'package:media_fast_view/features/favorites/domain/repositories/favorites_repository.dart';
import 'package:media_fast_view/features/favorites/domain/use_cases/favorite_media_use_case.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/media_library/data/data_sources/local_directory_data_source.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_repository.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/add_directory_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/clear_directories_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/get_directories_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/remove_directory_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/search_directories_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/screens/directory_grid_screen.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_grid_item.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_search_bar.dart';
import 'package:media_fast_view/features/tagging/domain/entities/tag_entity.dart';
import 'package:media_fast_view/features/tagging/domain/repositories/tag_repository.dart';
import 'package:media_fast_view/features/tagging/presentation/states/tag_state.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tag_management_view_model.dart';
import 'package:media_fast_view/shared/providers/grid_columns_provider.dart';
import 'package:media_fast_view/shared/utils/directory_id_utils.dart';
import 'package:media_fast_view/core/services/permission_service.dart';

class _MockDirectoryRepository extends Mock implements DirectoryRepository {}

class _MockMediaRepository extends Mock implements MediaRepository {}

class _MockFavoritesRepository extends Mock implements FavoritesRepository {}

class _MockFavoriteMediaUseCase extends Mock implements FavoriteMediaUseCase {}

class _MockLocalDirectoryDataSource extends Mock
    implements LocalDirectoryDataSource {}

class _MockPermissionService extends Mock implements PermissionService {}

class _MockTagRepository extends Mock implements TagRepository {}

class _StubFavoritesViewModel extends FavoritesViewModel {
  _StubFavoritesViewModel()
      : super(
          _MockFavoritesRepository(),
          _MockFavoriteMediaUseCase(),
        ) {
    state = const FavoritesLoaded(
      favorites: [],
      media: [],
      directoryFavorites: [],
    );
  }

  @override
  Future<void> loadFavorites() async {}

  @override
  Future<FavoriteToggleResult> toggleFavoritesForDirectories(
    List<DirectoryEntity> directories,
  ) async {
    state = const FavoritesLoaded(
      favorites: [],
      media: [],
      directoryFavorites: [],
    );
    return const FavoriteToggleResult(added: 0, removed: 0);
  }
}

class _StubTagViewModel extends TagViewModel {
  _StubTagViewModel()
      : super(_MockTagRepository()) {
    state = TagLoaded(tags: const [
      TagEntity(id: 'tag-1', name: 'Tag 1', color: 0),
    ]);
  }
}

class _StubGridColumnsNotifier extends StateNotifier<int> {
  _StubGridColumnsNotifier() : super(2);
}

class _StubDirectoryViewModel extends DirectoryViewModel {
  _StubDirectoryViewModel(this._directories, Ref ref)
      : super(
          ref,
          GetDirectoriesUseCase(_MockDirectoryRepository()),
          const SearchDirectoriesUseCase(),
          AddDirectoryUseCase(_MockDirectoryRepository()),
          RemoveDirectoryUseCase(
            _MockDirectoryRepository(),
            _MockMediaRepository(),
            _MockFavoritesRepository(),
          ),
          ClearDirectoriesUseCase(_MockDirectoryRepository()),
          _MockLocalDirectoryDataSource(),
          _MockPermissionService(),
        );

  final List<DirectoryEntity> _directories;
  String? lastSearchQuery;
  String? removedDirectoryId;

  @override
  Future<void> loadDirectories() async {
    state = DirectoryLoaded(
      directories: _directories,
      searchQuery: lastSearchQuery ?? '',
      selectedTagIds: const [],
      columns: 2,
      sortOption: DirectorySortOption.nameAscending,
      selectedDirectoryIds: const {},
      isSelectionMode: false,
      showFavoritesOnly: false,
    );
  }

  @override
  void searchDirectories(String query) {
    lastSearchQuery = query;
    state = DirectoryLoaded(
      directories: _directories,
      searchQuery: query,
      selectedTagIds: const [],
      columns: 2,
      sortOption: DirectorySortOption.nameAscending,
      selectedDirectoryIds: const {},
      isSelectionMode: false,
      showFavoritesOnly: false,
    );
  }

  @override
  Future<void> removeDirectory(String id) async {
    removedDirectoryId = id;
  }
}

void main() {
  group('DirectorySearchBar', () {
    testWidgets('invokes search with entered query and clears on tap',
        (tester) async {
      final directories = [
        DirectoryEntity(
          id: generateDirectoryId('/movies'),
          path: '/movies',
          name: 'Movies',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 1),
        ),
      ];
      late _StubDirectoryViewModel viewModel;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gridColumnsProvider
                .overrideWith((ref) => _StubGridColumnsNotifier()),
            favoritesViewModelProvider.overrideWith(
              (ref) => _StubFavoritesViewModel(),
            ),
            directoryViewModelProvider.overrideWith((ref) {
              viewModel = _StubDirectoryViewModel(directories, ref);
              return viewModel;
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(body: DirectorySearchBar()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'action');
      expect(viewModel.lastSearchQuery, 'action');

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(viewModel.lastSearchQuery, isEmpty);
    });
  });

  group('DirectoryGrid interactions', () {
    testWidgets('renders directories and confirms deletions', (tester) async {
      final directories = [
        DirectoryEntity(
          id: generateDirectoryId('/music'),
          path: '/music',
          name: 'Music',
          thumbnailPath: null,
          tagIds: const ['tag-1'],
          lastModified: DateTime(2024, 1, 1),
        ),
        DirectoryEntity(
          id: generateDirectoryId('/pictures'),
          path: '/pictures',
          name: 'Pictures',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 2),
        ),
      ];
      late _StubDirectoryViewModel viewModel;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gridColumnsProvider
                .overrideWith((ref) => _StubGridColumnsNotifier()),
            favoritesViewModelProvider.overrideWith(
              (ref) => _StubFavoritesViewModel(),
            ),
            tagViewModelProvider.overrideWith((ref) => _StubTagViewModel()),
            directoryViewModelProvider.overrideWith((ref) {
              viewModel = _StubDirectoryViewModel(directories, ref);
              return viewModel;
            }),
          ],
          child: const MaterialApp(
            home: DirectoryGridScreen(),
          ),
        ),
      );

      expect(find.text('Music'), findsOneWidget);
      expect(find.text('Pictures'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(DirectoryGridItem, 'Music'),
          matching: find.byIcon(Icons.delete),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete Directory'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(viewModel.removedDirectoryId, directories.first.id);
    });
  });
}

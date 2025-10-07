import 'package:test/test.dart';

import '../../../../../lib/features/media_library/domain/entities/directory_entity.dart';
import '../../../../../lib/features/media_library/domain/repositories/directory_repository.dart';
import '../../../../../lib/features/media_library/domain/use_cases/add_directory_use_case.dart';
import '../../../../../lib/features/media_library/domain/use_cases/clear_directories_use_case.dart';
import '../../../../../lib/features/media_library/domain/use_cases/get_directories_use_case.dart';
import '../../../../../lib/features/media_library/domain/use_cases/remove_directory_use_case.dart';
import '../../../../../lib/features/media_library/domain/use_cases/search_directories_use_case.dart';
import '../../../../../lib/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import '../../../../../lib/features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../../../../lib/core/services/permission_service.dart';

DirectoryEntity? _firstWhereOrNull(
  Iterable<DirectoryEntity> directories,
  bool Function(DirectoryEntity) test,
) {
  for (final directory in directories) {
    if (test(directory)) {
      return directory;
    }
  }
  return null;
}

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
    return _firstWhereOrNull(_directories, (dir) => dir.id == id);
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

class FakeLocalDirectoryDataSource extends LocalDirectoryDataSource {
  const FakeLocalDirectoryDataSource() : super(bookmarkService: BookmarkService.instance);

  @override
  Future<bool> validateDirectory(DirectoryEntity directory) async => true;
}

class FakePermissionService extends PermissionService {
  FakePermissionService() : super();
}

void main() {
  group('DirectoryViewModel tag filtering', () {
    late DirectoryViewModel viewModel;
    late InMemoryDirectoryRepository repository;

    setUp(() async {
      repository = InMemoryDirectoryRepository([
        DirectoryEntity(
          id: '1',
          path: '/dir1',
          name: 'Dir 1',
          thumbnailPath: null,
          tagIds: const ['tag1'],
          lastModified: DateTime(2024, 1, 1),
        ),
        DirectoryEntity(
          id: '2',
          path: '/dir2',
          name: 'Dir 2',
          thumbnailPath: null,
          tagIds: const ['tag2'],
          lastModified: DateTime(2024, 1, 2),
        ),
        DirectoryEntity(
          id: '3',
          path: '/dir3',
          name: 'Dir 3',
          thumbnailPath: null,
          tagIds: const [],
          lastModified: DateTime(2024, 1, 3),
        ),
      ]);

      viewModel = DirectoryViewModel(
        GetDirectoriesUseCase(repository),
        const SearchDirectoriesUseCase(),
        AddDirectoryUseCase(repository),
        RemoveDirectoryUseCase(repository),
        ClearDirectoriesUseCase(repository),
        const FakeLocalDirectoryDataSource(),
        FakePermissionService(),
      );

      await viewModel.loadDirectories();
    });

    test('filters directories by selected tag ids', () async {
      expect(viewModel.state, isA<DirectoryLoaded>());

      viewModel.filterByTags(const ['tag1']);

      final state = viewModel.state;
      expect(state, isA<DirectoryLoaded>());
      final loadedState = state as DirectoryLoaded;
      expect(loadedState.directories.length, 1);
      expect(loadedState.directories.first.id, '1');
      expect(loadedState.selectedTagIds, ['tag1']);
    });
  });
}

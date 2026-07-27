import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/reconcile_directory_cover_use_case.dart';

class _MemoryCoverRepository implements DirectoryCoverRepository {
  _MemoryCoverRepository(this.cover);

  DirectoryCoverEntity? cover;

  @override
  Future<void> clearCovers() async => cover = null;

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async => cover;

  @override
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) async {}

  @override
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) async {}

  @override
  Future<void> removeCover(String directoryPath) async => cover = null;

  @override
  Future<void> removeCoverForSource(String sourcePath) async {}

  @override
  Future<void> removeCoversUnder(String directoryPath) async {}

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {
    this.cover = cover;
  }
}

DirectoryCoverEntity _cover() {
  return DirectoryCoverEntity.images(
    directoryPath: '/library/photos',
    sourceFileNames: <String>['one.jpg', 'two.jpg', 'three.jpg'],
    updatedAt: DateTime(2025),
  );
}

void main() {
  test('removes only missing selections when valid images remain', () async {
    final repository = _MemoryCoverRepository(_cover());

    await ReconcileDirectoryCoverUseCase(repository)(
      directoryPath: '/library/photos',
      missingSourceFileNames: <String>['TWO.JPG'],
    );

    expect(repository.cover?.sourceFileNames, <String>['one.jpg', 'three.jpg']);
  });

  test('clears the custom setting when every selection is missing', () async {
    final repository = _MemoryCoverRepository(_cover());

    await ReconcileDirectoryCoverUseCase(repository)(
      directoryPath: '/library/photos',
      missingSourceFileNames: <String>['one.jpg', 'two.jpg', 'three.jpg'],
    );

    expect(repository.cover, isNull);
  });
}

import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/repositories/directory_cover_repository.dart';
import '../isar/isar_directory_cover_data_source.dart';

/// Isar-backed implementation of [DirectoryCoverRepository].
class DirectoryCoverRepositoryImpl implements DirectoryCoverRepository {
  const DirectoryCoverRepositoryImpl(this._dataSource);

  final IsarDirectoryCoverDataSource _dataSource;

  @override
  Future<void> clearCovers() => _dataSource.clearCovers();

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) {
    return _dataSource.getCover(directoryPath);
  }

  @override
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) {
    return _dataSource.rebaseDirectoryTree(
      oldRootPath: oldRootPath,
      newRootPath: newRootPath,
    );
  }

  @override
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) {
    return _dataSource.reconcileMediaMove(oldPath: oldPath, newPath: newPath);
  }

  @override
  Future<void> removeCover(String directoryPath) {
    return _dataSource.removeCover(directoryPath);
  }

  @override
  Future<void> removeCoverForSource(String sourcePath) {
    return _dataSource.removeCoverForSource(sourcePath);
  }

  @override
  Future<void> removeCoversUnder(String directoryPath) {
    return _dataSource.removeCoversUnder(directoryPath);
  }

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) {
    return _dataSource.saveCover(cover);
  }
}

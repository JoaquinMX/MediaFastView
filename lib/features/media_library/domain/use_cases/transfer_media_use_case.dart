import '../../../../core/services/file_transfer_result.dart';
import '../repositories/file_operations_repository.dart';

/// Moves an item into another directory.
class MoveMediaUseCase {
  const MoveMediaUseCase(this._repository);

  final FileOperationsRepository _repository;

  Future<FileTransferResult> call(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    return _repository.moveItem(
      sourcePath,
      destinationDirectoryPath: destinationDirectoryPath,
      sourceBookmarkData: sourceBookmarkData,
      destinationBookmarkData: destinationBookmarkData,
      conflictStrategy: conflictStrategy,
    );
  }
}

/// Copies an item into another directory.
class CopyMediaUseCase {
  const CopyMediaUseCase(this._repository);

  final FileOperationsRepository _repository;

  Future<FileTransferResult> call(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    return _repository.copyItem(
      sourcePath,
      destinationDirectoryPath: destinationDirectoryPath,
      sourceBookmarkData: sourceBookmarkData,
      destinationBookmarkData: destinationBookmarkData,
      conflictStrategy: conflictStrategy,
    );
  }
}

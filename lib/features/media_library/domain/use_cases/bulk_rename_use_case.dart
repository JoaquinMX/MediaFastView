import '../entities/file_rename_request.dart';
import '../repositories/file_operations_repository.dart';

/// Use case for renaming multiple files or directories at once.
class BulkRenameUseCase {
  const BulkRenameUseCase(this._repository);

  final FileOperationsRepository _repository;

  Future<List<String>> call(
    List<FileRenameRequest> requests, {
    Map<String, String?>? bookmarkDataMap,
  }) {
    return _repository.bulkRename(
      requests,
      bookmarkDataMap: bookmarkDataMap,
    );
  }
}

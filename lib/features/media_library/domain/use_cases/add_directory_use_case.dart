import '../entities/directory_entity.dart';
import '../repositories/directory_repository.dart';

/// Use case for adding a new directory.
class AddDirectoryUseCase {
  const AddDirectoryUseCase(this._repository);

  final DirectoryRepository _repository;

  /// Executes the use case to add a directory by path.
  /// Creates a DirectoryEntity and delegates validation to the repository.
  /// [silent] if true, skips recovery dialogs for bookmark failures (used for drag-and-drop).
  Future<void> call(String path, {bool silent = false}) async {
    // Generate ID from path
    final id = path.hashCode.toString();

    // Get directory name from path
    final name = path.split('/').lastWhere((element) => element.isNotEmpty, orElse: () => path);

    final directoryEntity = DirectoryEntity(
      id: id,
      path: path,
      name: name,
      thumbnailPath: null,
      tagIds: const [],
      lastModified: DateTime.now(),
    );

    await _repository.addDirectory(directoryEntity, silent: silent);
  }
}

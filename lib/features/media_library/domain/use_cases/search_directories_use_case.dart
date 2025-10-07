import '../entities/directory_entity.dart';

/// Use case for searching directories by query.
class SearchDirectoriesUseCase {
  const SearchDirectoriesUseCase();

  /// Executes the use case to search directories by query.
  /// Filters the provided directories list by name containing the query (case-insensitive).
  List<DirectoryEntity> call(List<DirectoryEntity> directories, String query) {
    if (query.isEmpty) {
      return directories;
    }
    final lowerQuery = query.toLowerCase();
    return directories
        .where((dir) => dir.name.toLowerCase().contains(lowerQuery))
        .toList();
  }
}

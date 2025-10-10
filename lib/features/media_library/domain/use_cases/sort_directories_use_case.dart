import '../entities/directory_entity.dart';
import '../value_objects/sort_option.dart';

/// Use case responsible for sorting directories using the provided option.
class SortDirectoriesUseCase {
  const SortDirectoriesUseCase();

  /// Returns a new list of directories sorted according to [option].
  List<DirectoryEntity> call(
    List<DirectoryEntity> directories,
    DirectorySortOption option,
  ) {
    final sortedDirectories = List<DirectoryEntity>.from(directories);
    sortedDirectories.sort((a, b) {
      final comparison = switch (option.field) {
        DirectorySortField.name => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
        DirectorySortField.lastModified => a.lastModified.compareTo(
              b.lastModified,
            ),
      };

      return option.order == SortOrder.ascending ? comparison : -comparison;
    });

    return sortedDirectories;
  }
}

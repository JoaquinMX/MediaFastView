/// Represents a directory that can be navigated to from the media grid.
class DirectoryNavigationTarget {
  const DirectoryNavigationTarget({
    required this.path,
    required this.name,
    this.bookmarkData,
  });

  final String path;
  final String name;
  final String? bookmarkData;
}

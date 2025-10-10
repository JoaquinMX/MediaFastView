/// Sorting options available for media library listings.
enum LibrarySortOption {
  nameAscending,
  nameDescending,
  lastModifiedDescending,
}

extension LibrarySortOptionX on LibrarySortOption {
  /// Human-readable label for display in menus.
  String get label {
    switch (this) {
      case LibrarySortOption.nameAscending:
        return 'Name (A-Z)';
      case LibrarySortOption.nameDescending:
        return 'Name (Z-A)';
      case LibrarySortOption.lastModifiedDescending:
        return 'Last Modified';
    }
  }
}

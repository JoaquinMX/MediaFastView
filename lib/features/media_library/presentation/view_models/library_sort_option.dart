import 'package:flutter/material.dart';

/// Available sort options for library listings.
enum LibrarySortOption {
  nameAscending,
  nameDescending,
  lastModified,
}

extension LibrarySortOptionX on LibrarySortOption {
  /// Display label for the sort option.
  String get label => switch (this) {
        LibrarySortOption.nameAscending => 'Name (A-Z)',
        LibrarySortOption.nameDescending => 'Name (Z-A)',
        LibrarySortOption.lastModified => 'Last Modified',
      };

  /// Icon associated with the sort option.
  IconData get icon => switch (this) {
        LibrarySortOption.nameAscending => Icons.sort_by_alpha,
        LibrarySortOption.nameDescending => Icons.sort_by_alpha,
        LibrarySortOption.lastModified => Icons.access_time,
      };
}

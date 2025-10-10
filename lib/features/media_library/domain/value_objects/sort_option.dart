/// Represents the order a collection should be sorted in.
enum SortOrder { ascending, descending }

/// Available fields for sorting directories.
enum DirectorySortField { name, lastModified }

/// Available fields for sorting media items.
enum MediaSortField { name, lastModified, size }

/// Defines how directories should be sorted.
class DirectorySortOption {
  const DirectorySortOption({
    required this.field,
    required this.order,
  });

  final DirectorySortField field;
  final SortOrder order;

  DirectorySortOption copyWith({
    DirectorySortField? field,
    SortOrder? order,
  }) {
    return DirectorySortOption(
      field: field ?? this.field,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DirectorySortOption &&
        other.field == field &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(field, order);

  static const DirectorySortOption nameAscending = DirectorySortOption(
    field: DirectorySortField.name,
    order: SortOrder.ascending,
  );

  static const DirectorySortOption nameDescending = DirectorySortOption(
    field: DirectorySortField.name,
    order: SortOrder.descending,
  );

  static const DirectorySortOption lastModifiedNewestFirst =
      DirectorySortOption(
    field: DirectorySortField.lastModified,
    order: SortOrder.descending,
  );

  static const DirectorySortOption lastModifiedOldestFirst =
      DirectorySortOption(
    field: DirectorySortField.lastModified,
    order: SortOrder.ascending,
  );

  static const List<DirectorySortOption> values = <DirectorySortOption>[
    nameAscending,
    nameDescending,
    lastModifiedNewestFirst,
    lastModifiedOldestFirst,
  ];
}

/// Defines how media should be sorted.
class MediaSortOption {
  const MediaSortOption({
    required this.field,
    required this.order,
  });

  final MediaSortField field;
  final SortOrder order;

  MediaSortOption copyWith({
    MediaSortField? field,
    SortOrder? order,
  }) {
    return MediaSortOption(
      field: field ?? this.field,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaSortOption &&
        other.field == field &&
        other.order == order;
  }

  @override
  int get hashCode => Object.hash(field, order);

  static const MediaSortOption nameAscending = MediaSortOption(
    field: MediaSortField.name,
    order: SortOrder.ascending,
  );

  static const MediaSortOption nameDescending = MediaSortOption(
    field: MediaSortField.name,
    order: SortOrder.descending,
  );

  static const MediaSortOption lastModifiedNewestFirst = MediaSortOption(
    field: MediaSortField.lastModified,
    order: SortOrder.descending,
  );

  static const MediaSortOption lastModifiedOldestFirst = MediaSortOption(
    field: MediaSortField.lastModified,
    order: SortOrder.ascending,
  );

  static const MediaSortOption sizeLargestFirst = MediaSortOption(
    field: MediaSortField.size,
    order: SortOrder.descending,
  );

  static const MediaSortOption sizeSmallestFirst = MediaSortOption(
    field: MediaSortField.size,
    order: SortOrder.ascending,
  );

  static const List<MediaSortOption> values = <MediaSortOption>[
    nameAscending,
    nameDescending,
    lastModifiedNewestFirst,
    lastModifiedOldestFirst,
    sizeLargestFirst,
    sizeSmallestFirst,
  ];
}

enum TagMediaTypeFilter {
  images,
  videos,
  all,
}

extension TagMediaTypeFilterX on TagMediaTypeFilter {
  String get label => switch (this) {
        TagMediaTypeFilter.images => 'Images',
        TagMediaTypeFilter.videos => 'Videos',
        TagMediaTypeFilter.all => 'Images & Videos',
      };
}

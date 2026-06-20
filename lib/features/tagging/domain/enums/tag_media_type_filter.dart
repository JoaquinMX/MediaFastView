enum TagMediaTypeFilter {
  images,
  videos,
  audio,
  all,
}

extension TagMediaTypeFilterX on TagMediaTypeFilter {
  String get label => switch (this) {
        TagMediaTypeFilter.images => 'Images',
        TagMediaTypeFilter.videos => 'Videos',
        TagMediaTypeFilter.audio => 'Audio',
        TagMediaTypeFilter.all => 'All media',
      };
}

/// Determines how selected media is compared with the indexed library.
enum MediaLookupMode {
  /// Compares images with images and videos with videos.
  mediaMatches,

  /// Treats selected images as frames and searches indexed videos.
  videoFromFrame,
}

extension MediaLookupModeX on MediaLookupMode {
  String get label => switch (this) {
    MediaLookupMode.mediaMatches => 'Media matches',
    MediaLookupMode.videoFromFrame => 'Video from frame',
  };
}

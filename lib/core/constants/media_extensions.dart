import 'package:path/path.dart' as p;

/// File extensions recognised as images by the media library.
///
/// Keep lookup, indexing, and picker validation on this shared source of truth.
const Set<String> supportedImageExtensions = <String>{
  'jpg',
  'jpeg',
  'png',
  'gif',
  'jfif',
  'bmp',
  'webp',
  'tiff',
  'tif',
  'heic',
  'heif',
  'heics',
  'dng',
  'nef',
  'cr2',
  'cr3',
  'arw',
  'raf',
  'orf',
  'rw2',
  'sr2',
  'pef',
};

/// File extensions recognised as videos by the media library.
const Set<String> supportedVideoExtensions = <String>{
  'mp4',
  'mov',
  'avi',
  'mkv',
  'wmv',
  'flv',
  'webm',
  'm4v',
  'ts',
  'mts',
  'm2ts',
  'mpg',
  'mpeg',
};

/// File extensions supported as visual-media lookup queries.
const Set<String> supportedVisualMediaExtensions = <String>{
  ...supportedImageExtensions,
  ...supportedVideoExtensions,
};

/// Whether [filePath] has an extension supported by the image pipeline.
bool isSupportedImagePath(String filePath) {
  final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
  return supportedImageExtensions.contains(extension);
}

/// Whether [filePath] has a video extension supported by the media pipeline.
bool isSupportedVideoPath(String filePath) {
  final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
  return supportedVideoExtensions.contains(extension);
}

/// Whether [filePath] can be used as an image or video lookup query.
bool isSupportedVisualMediaPath(String filePath) {
  final extension = p.extension(filePath).toLowerCase().replaceFirst('.', '');
  return supportedVisualMediaExtensions.contains(extension);
}

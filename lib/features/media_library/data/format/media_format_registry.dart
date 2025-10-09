import '../../domain/entities/media_entity.dart';

/// Registry describing supported media formats and how they map to [MediaType].
class MediaFormatRegistry {
  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'jfif',
    'bmp',
    'webp',
    'heic',
    'heif',
    'tiff',
    'tif',
    'raw',
    'dng',
    'cr2',
    'nef',
    'raf',
    'arw',
    'orf',
    'sr2',
    'pef',
  };

  static const Set<String> videoExtensions = {
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'flv',
    'webm',
    'm4v',
    '3gp',
    'mpg',
    'mpeg',
    'm2ts',
    'mts',
    'prores',
  };

  static const Set<String> textExtensions = {'txt', 'md', 'log', 'json', 'xml'};

  static const Set<String> audioExtensions = {
    'mp3',
    'wav',
    'aac',
    'flac',
    'oga',
    'ogg',
    'aiff',
    'm4a',
  };

  static const Set<String> documentExtensions = {'pdf'};

  static const Set<String> bundleExtensions = {
    'photoslibrary',
    'aplibrary',
  };

  static bool isSupportedExtension(String extension) {
    final normalized = _normalize(extension);
    return imageExtensions.contains(normalized) ||
        videoExtensions.contains(normalized) ||
        textExtensions.contains(normalized) ||
        audioExtensions.contains(normalized) ||
        documentExtensions.contains(normalized);
  }

  static MediaType mediaTypeForExtension(String extension) {
    final normalized = _normalize(extension);
    if (imageExtensions.contains(normalized)) {
      return MediaType.image;
    }
    if (videoExtensions.contains(normalized)) {
      return MediaType.video;
    }
    if (textExtensions.contains(normalized)) {
      return MediaType.text;
    }
    if (audioExtensions.contains(normalized)) {
      return MediaType.audio;
    }
    if (documentExtensions.contains(normalized)) {
      return MediaType.document;
    }
    return MediaType.directory;
  }

  static bool isBundleDirectory(String path) {
    final extension = path.split('.').last.toLowerCase();
    return bundleExtensions.contains(extension);
  }

  static String _normalize(String extension) {
    return extension.replaceFirst('.', '').toLowerCase();
  }
}

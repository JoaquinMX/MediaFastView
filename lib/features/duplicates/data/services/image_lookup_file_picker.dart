import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/media_extensions.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../domain/entities/image_lookup_source.dart';

/// Selects and validates visual-media queries without copying source files.
abstract interface class MediaLookupFilePicker {
  Future<List<ImageLookupSource>> pickMedia({
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  });

  Future<List<ImageLookupSource>> sourcesFromPaths(
    Iterable<String> paths, {
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  });
}

/// macOS image/video implementation backed by the picker and bookmarks.
class MacOsMediaLookupFilePicker implements MediaLookupFilePicker {
  const MacOsMediaLookupFilePicker(this._bookmarkService);

  final BookmarkService _bookmarkService;

  @override
  Future<List<ImageLookupSource>> pickMedia({
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  }) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Media lookup is currently supported on macOS.');
    }
    final result = await FilePicker.platform.pickFiles(
      dialogTitle:
          allowedMediaTypes.length == 1 &&
              allowedMediaTypes.contains(MediaType.image)
          ? 'Choose Image Frames to Match'
          : 'Choose Images or Videos to Match',
      type: FileType.custom,
      allowedExtensions: _extensionsFor(allowedMediaTypes),
      allowMultiple: true,
    );
    if (result == null) {
      return const <ImageLookupSource>[];
    }
    return sourcesFromPaths(
      result.files.map((file) => file.path).whereType<String>(),
      allowedMediaTypes: allowedMediaTypes,
    );
  }

  @override
  Future<List<ImageLookupSource>> sourcesFromPaths(
    Iterable<String> paths, {
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  }) async {
    final uniquePaths = <String>{
      for (final path in paths) p.normalize(p.absolute(path)),
    };
    final sources = <ImageLookupSource>[];
    for (final path in uniquePaths) {
      if (!isSupportedVisualMediaPath(path)) {
        continue;
      }
      final mediaType = isSupportedVideoPath(path)
          ? MediaType.video
          : MediaType.image;
      if (!allowedMediaTypes.contains(mediaType)) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      final stat = await file.stat();
      String? bookmarkData;
      if (Platform.isMacOS) {
        try {
          bookmarkData = await _bookmarkService.createFileBookmark(path);
        } catch (_) {
          // The current picker/drop grant can still be sufficient for this
          // session. Saved history will mark the file unavailable if the app
          // cannot regain access later.
        }
      }
      sources.add(
        ImageLookupSource(
          path: path,
          name: p.basename(path),
          size: stat.size,
          lastModified: stat.modified,
          mediaType: mediaType,
          bookmarkData: bookmarkData,
        ),
      );
    }
    return List<ImageLookupSource>.unmodifiable(sources);
  }

  List<String> _extensionsFor(Set<MediaType> mediaTypes) {
    return <String>{
      if (mediaTypes.contains(MediaType.image)) ...supportedImageExtensions,
      if (mediaTypes.contains(MediaType.video)) ...supportedVideoExtensions,
    }.toList(growable: false);
  }
}

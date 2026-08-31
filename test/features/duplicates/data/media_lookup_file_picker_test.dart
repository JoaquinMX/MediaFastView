import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/features/duplicates/data/services/image_lookup_file_picker.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

void main() {
  test(
    'accepts supported images and videos and records their media type',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'media-fast-view-lookup-picker-',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final image = File('${directory.path}/query.jpg');
      final video = File('${directory.path}/query.mov');
      final audio = File('${directory.path}/query.mp3');
      await image.writeAsBytes(<int>[1]);
      await video.writeAsBytes(<int>[2]);
      await audio.writeAsBytes(<int>[3]);
      final picker = MacOsMediaLookupFilePicker(BookmarkService.instance);

      final sources = await picker.sourcesFromPaths(<String>[
        image.path,
        video.path,
        audio.path,
        '${directory.path}/missing.mp4',
        video.path,
      ]);

      expect(sources, hasLength(2));
      expect(sources.map((source) => source.mediaType), <MediaType>[
        MediaType.image,
        MediaType.video,
      ]);

      final frameSources = await picker.sourcesFromPaths(
        <String>[image.path, video.path],
        allowedMediaTypes: const <MediaType>{MediaType.image},
      );
      expect(frameSources, hasLength(1));
      expect(frameSources.single.mediaType, MediaType.image);
    },
  );
}

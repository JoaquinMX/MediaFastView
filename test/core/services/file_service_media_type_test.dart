import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_service.dart';

void main() {
  final fileService = FileService();

  group('FileService.getMediaTypeFromExtension - audio', () {
    const audioExtensions = [
      'mp3',
      'm4a',
      'aac',
      'wav',
      'aiff',
      'aif',
      'flac',
      'caf',
      'alac',
      'ogg',
      'oga',
      'opus',
    ];

    for (final ext in audioExtensions) {
      test('classifies .$ext as audio', () {
        expect(
          fileService.getMediaTypeFromExtension('/music/song.$ext'),
          'audio',
        );
      });

      test('classifies uppercase .$ext as audio', () {
        expect(
          fileService.getMediaTypeFromExtension('/music/SONG.${ext.toUpperCase()}'),
          'audio',
        );
      });
    }
  });

  group('FileService.getMediaTypeFromExtension - other types unaffected', () {
    test('classifies images, videos, and text correctly', () {
      expect(fileService.getMediaTypeFromExtension('/p/a.png'), 'image');
      expect(fileService.getMediaTypeFromExtension('/p/a.mp4'), 'video');
      expect(fileService.getMediaTypeFromExtension('/p/a.ts'), 'video');
      expect(fileService.getMediaTypeFromExtension('/p/a.txt'), 'text');
      expect(fileService.getMediaTypeFromExtension('/p/a.unknownext'), 'unknown');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

void main() {
  group('MediaType.isTimeBased', () {
    test('is true for video and audio', () {
      expect(MediaType.video.isTimeBased, isTrue);
      expect(MediaType.audio.isTimeBased, isTrue);
    });

    test('is false for image, text, and directory', () {
      expect(MediaType.image.isTimeBased, isFalse);
      expect(MediaType.text.isTimeBased, isFalse);
      expect(MediaType.directory.isTimeBased, isFalse);
    });
  });

  group('MediaType.label', () {
    test('audio has a label', () {
      expect(MediaType.audio.label, 'Audio');
    });

    test('every type has a label', () {
      for (final type in MediaType.values) {
        expect(type.label, isNotEmpty);
      }
    });
  });
}

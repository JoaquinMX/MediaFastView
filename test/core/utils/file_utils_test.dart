import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/utils/file_utils.dart';

void main() {
  test('recognizes every media-scan exclusion prefix', () {
    expect(isExcludedMediaFileName('._photo.jpg'), isTrue);
    expect(isExcludedMediaFileName('.DS_Store'), isTrue);
    expect(isExcludedMediaFileName('Thumbs.db.backup'), isTrue);
    expect(isExcludedMediaFileName('desktop.ini'), isTrue);
    expect(isExcludedMediaFileName('.mediafastview.json'), isTrue);
  });

  test('keeps ordinary and unrelated hidden media names', () {
    expect(isExcludedMediaFileName('photo.jpg'), isFalse);
    expect(isExcludedMediaFileName('photo._edited.jpg'), isFalse);
    expect(isExcludedMediaFileName('.favorite.jpg'), isFalse);
  });
}

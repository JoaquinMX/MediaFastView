import 'package:flutter_test/flutter_test.dart';

import 'package:media_fast_view/features/favorites/domain/use_cases/start_slideshow_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

void main() {
  const useCase = StartSlideshowUseCase();

  final media = [
    MediaEntity(
      id: '1',
      path: '/a',
      name: 'a',
      type: MediaType.image,
      size: 1,
      lastModified: DateTime(2024, 1, 1),
      tagIds: const [],
      directoryId: 'dir',
      bookmarkData: null,
    ),
    MediaEntity(
      id: '2',
      path: '/b',
      name: 'b',
      type: MediaType.video,
      size: 2,
      lastModified: DateTime(2024, 1, 2),
      tagIds: const [],
      directoryId: 'dir',
      bookmarkData: null,
    ),
  ];

  test('returns media unchanged in provided order', () async {
    final result = await useCase.execute(media);

    expect(result, media);
  });
}

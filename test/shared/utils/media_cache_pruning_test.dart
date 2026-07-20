import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/shared/utils/media_cache_pruning.dart';

MediaEntity _media(String path, {String? id, List<String> tagIds = const []}) {
  return MediaEntity(
    id: id ?? 'id:$path',
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024),
    tagIds: tagIds,
    directoryId: 'dir',
  );
}

void main() {
  test('selects only entries whose path is absent from the verified set', () {
    final media = <MediaEntity>[
      _media('/lib/a/keep.jpg'),
      _media('/lib/gone/missing.jpg'),
      _media('/lib/b/keep2.jpg'),
    ];

    final ids = missingMediaIds(media, <String>{
      '/lib/a/keep.jpg',
      '/lib/b/keep2.jpg',
    });

    expect(ids, <String>['id:/lib/gone/missing.jpg']);
  });

  test('keeps tagged media that still exists, even deep in a subfolder', () {
    // The old directoryId-based prune deleted exactly this: a tagged file in a
    // subfolder, whose directoryId is the subfolder's rather than the root's.
    final tagged = _media('/lib/a/b/c/photo.jpg', tagIds: <String>['t1']);

    final ids = missingMediaIds(
      <MediaEntity>[tagged],
      <String>{'/lib/a/b/c/photo.jpg'},
    );

    expect(ids, isEmpty);
  });

  test('prunes nothing when every path was verified present', () {
    final media = <MediaEntity>[_media('/a.jpg'), _media('/b.jpg')];

    expect(
      missingMediaIds(media, <String>{'/a.jpg', '/b.jpg'}),
      isEmpty,
    );
  });

  test('an empty verified set means everything is missing', () {
    // Callers must add unverifiable paths to the set themselves; an empty set
    // genuinely means "checked, and none were found".
    final media = <MediaEntity>[_media('/a.jpg')];

    expect(missingMediaIds(media, <String>{}), <String>['id:/a.jpg']);
  });
}

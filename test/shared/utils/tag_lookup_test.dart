import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/tag_entity.dart';
import 'package:media_fast_view/shared/utils/tag_lookup.dart';

import '../../features/tagging/presentation/tag_view_model_fakes.dart';

TagEntity _tag(String name, {int color = 0xFF2196F3}) {
  return TagEntity(
    id: 'tag-beach',
    name: name,
    color: color,
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  // Why this matters: TagLookup is an app-lifetime cache and it is what the
  // full-screen and slideshow overlays resolve media.tagIds through. Renaming a
  // tag writes straight to the repository, so unless something refreshes this
  // cache those overlays keep showing the old name and colour until the app
  // restarts. TagCacheRefresher.refresh() is what does it.
  //
  // The refresher itself is not unit-tested here: it also reloads three view
  // models that boot Isar through path_provider, and isolating it would mean
  // faking the whole provider graph. The runtime check in the plan covers that
  // wiring — open a tagged item full-screen after a rename, without restarting.
  group('TagLookup', () {
    test('serves a stale tag until it is refreshed', () async {
      final repository = FakeTagRepository([_tag('Beach')]);
      final lookup = TagLookup(repository);

      expect((await lookup.getAllTags()).single.name, 'Beach');

      await repository.updateTag(_tag('Seaside', color: 0xFFE91E63));

      // The write went in behind the cache's back; it does not notice.
      expect((await lookup.getAllTags()).single.name, 'Beach');
      expect((await lookup.getTagsByIds(['tag-beach'])).single.name, 'Beach');
    });

    test('picks up a renamed and recoloured tag once refreshed', () async {
      final repository = FakeTagRepository([_tag('Beach')]);
      final lookup = TagLookup(repository);

      await lookup.getAllTags(); // warm the cache
      await repository.updateTag(_tag('Seaside', color: 0xFFE91E63));

      await lookup.refresh();

      final resolved = (await lookup.getTagsByIds(['tag-beach'])).single;
      expect(resolved.name, 'Seaside');
      expect(resolved.color, 0xFFE91E63);
    });

    test('keeps resolving the tag by its original id after a rename', () async {
      // The id never changes, which is why media keep their tags across an edit.
      final repository = FakeTagRepository([_tag('Beach')]);
      final lookup = TagLookup(repository);

      await repository.updateTag(_tag('Seaside'));
      await lookup.refresh();

      expect(await lookup.getTagsByIds(['tag-beach']), hasLength(1));
    });
  });
}

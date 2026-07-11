import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_transfer_result.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/shared/providers/media_mutation_bus.dart';

MediaEntity _media(String id, String path) {
  return MediaEntity(
    id: id,
    path: path,
    name: path.split('/').last,
    type: MediaType.image,
    size: 1,
    lastModified: DateTime(2024, 1, 1),
    tagIds: const [],
    directoryId: 'dir-1',
  );
}

void main() {
  late ProviderContainer container;
  late List<MediaMutation> published;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);

    published = <MediaMutation>[];
    container.listen<MediaMutation?>(mediaMutationBusProvider, (_, next) {
      if (next != null) published.add(next);
    });
  });

  MediaMutationBus bus() =>
      container.read(mediaMutationBusProvider.notifier);

  test('two identical deletes are both announced', () {
    final item = _media('m1', '/dir/a.jpg');

    bus().publishDeleted([item]);
    bus().publishDeleted([item]);

    // Without the sequence, the second would be indistinguishable from the first
    // and a listener could reasonably ignore it.
    expect(published, hasLength(2));
    expect(published.map((m) => m.sequence), [1, 2]);
  });

  test('an empty payload is not announced', () {
    bus().publishDeleted([]);

    expect(published, isEmpty);
  });

  test('a move announces the source leaving and the result arriving', () {
    final source = _media('m1', '/dir/a.jpg');
    final result = _media('m1-new', '/other/a.jpg');

    bus().publishTransfer(
      mode: TransferMode.move,
      source: source,
      result: result,
    );

    final mutation = published.single;
    expect(mutation.kind, MediaMutationKind.moved);
    expect(mutation.removed.single.id, 'm1');
    expect(mutation.added.single.id, 'm1-new');
  });

  test('a copy announces only the arrival; the source stays put', () {
    final source = _media('m1', '/dir/a.jpg');
    final result = _media('m1-copy', '/other/a.jpg');

    bus().publishTransfer(
      mode: TransferMode.copy,
      source: source,
      result: result,
    );

    final mutation = published.single;
    expect(mutation.kind, MediaMutationKind.copied);
    expect(mutation.removed, isEmpty);
    expect(mutation.added.single.id, 'm1-copy');
  });

  test('a copy that kept its source id is not announced', () {
    final source = _media('m1', '/dir/a.jpg');

    // The reconciler refuses to write a row for such a copy, because doing so
    // would overwrite the original's. Announcing it would put a tile on screen
    // that no record backs.
    bus().publishTransfer(
      mode: TransferMode.copy,
      source: source,
      result: _media('m1', '/other/a.jpg'),
    );

    expect(published, isEmpty);
  });
}

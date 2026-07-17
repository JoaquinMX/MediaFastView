import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/repositories/duplicate_repository_impl.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/keeper_strategy.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/perceptual_hash.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/media_repository.dart';

import '../duplicate_test_helpers.dart';

class _FakeMediaRepository implements MediaRepository {
  _FakeMediaRepository(this.media);

  final List<MediaEntity> media;

  @override
  Future<List<MediaEntity>> getAllMedia() async => media;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHashDataSource implements PerceptualHashDataSource {
  _FakeHashDataSource(this.store);

  final Map<String, PerceptualHash> store;
  final List<List<PerceptualHash>> writes = [];

  @override
  Future<Map<String, PerceptualHash>> getByMediaIds(
    Iterable<String> mediaIds,
  ) async {
    return {
      for (final id in mediaIds)
        if (store.containsKey(id)) id: store[id]!,
    };
  }

  @override
  Future<void> putAll(List<PerceptualHash> hashes) async {
    writes.add(hashes);
    store.addAll({for (final hash in hashes) hash.mediaId: hash});
  }
}

class _FakeDismissedDataSource implements DismissedGroupDataSource {
  final Set<String> signatures = {};

  @override
  Future<Set<String>> getSignatures() async => signatures;

  @override
  Future<void> add(String signature) async => signatures.add(signature);
}

PerceptualHash hashFor(
  MediaEntity media,
  int hash, {
  int width = 100,
  int height = 100,
}) {
  return PerceptualHash(
    mediaId: media.id,
    hash: hash,
    width: width,
    height: height,
    fingerprint: perceptualFingerprint(
      size: media.size,
      lastModified: media.lastModified,
    ),
  );
}

void main() {
  group('DuplicateRepositoryImpl.loadGroups', () {
    test('clusters hashed images and picks the keeper by strategy', () async {
      final m1 = buildMedia('m1', size: 9000);
      final m2 = buildMedia('m2', size: 2000);
      final m3 = buildMedia('m3', size: 3000);
      final m4 = buildMedia('m4', size: 1000); // no cached hash

      final hashDataSource = _FakeHashDataSource({
        'm1': hashFor(m1, 0, width: 4000, height: 3000),
        'm2': hashFor(m2, 3, width: 1000, height: 750), // 2 bits from m1
        'm3': hashFor(m3, 0xFFFF, width: 500, height: 500), // far
      });

      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository([m1, m2, m3, m4]),
        hashDataSource: hashDataSource,
        dismissedDataSource: _FakeDismissedDataSource(),
      );

      final groups = await repository.loadGroups(
        sensitivity: DuplicateSensitivity.balanced,
        keeperStrategy: KeeperStrategy.highestResolution,
      );

      expect(groups, hasLength(1));
      final group = groups.single;
      expect(group.candidates.map((c) => c.id).toSet(), {'m1', 'm2'});
      expect(group.keeperId, 'm1'); // highest resolution
      expect(group.removable.map((c) => c.id), ['m2']);
      expect(group.reclaimableBytes, 2000);
    });

    test('excludes dismissed groups', () async {
      final m1 = buildMedia('m1');
      final m2 = buildMedia('m2');
      final dismissed = _FakeDismissedDataSource()..signatures.add('m1|m2');

      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository([m1, m2]),
        hashDataSource: _FakeHashDataSource({
          'm1': hashFor(m1, 0),
          'm2': hashFor(m2, 0),
        }),
        dismissedDataSource: dismissed,
      );

      final groups = await repository.loadGroups(
        sensitivity: DuplicateSensitivity.balanced,
        keeperStrategy: KeeperStrategy.highestResolution,
      );

      expect(groups, isEmpty);
    });

    test('sorts groups by reclaimable bytes, largest first', () async {
      // Group A: two 500-byte copies -> reclaim 500. Group B: two 9000 -> 9000.
      final a1 = buildMedia('a1', size: 500);
      final a2 = buildMedia('a2', size: 500);
      final b1 = buildMedia('b1', size: 9000);
      final b2 = buildMedia('b2', size: 9000);

      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository([a1, a2, b1, b2]),
        hashDataSource: _FakeHashDataSource({
          'a1': hashFor(a1, 0),
          'a2': hashFor(a2, 0),
          'b1': hashFor(b1, 0xFFFF),
          'b2': hashFor(b2, 0xFFFF),
        }),
        dismissedDataSource: _FakeDismissedDataSource(),
      );

      final groups = await repository.loadGroups(
        sensitivity: DuplicateSensitivity.strict,
        keeperStrategy: KeeperStrategy.largestFile,
      );

      expect(groups, hasLength(2));
      expect(groups.first.reclaimableBytes, 9000);
      expect(groups.last.reclaimableBytes, 500);
    });
  });

  group('DuplicateRepositoryImpl.hashLibrary', () {
    test('reuses cached hashes without decoding or writing', () async {
      final m1 = buildMedia('m1');
      final m2 = buildMedia('m2');
      final hashDataSource = _FakeHashDataSource({
        'm1': hashFor(m1, 0),
        'm2': hashFor(m2, 0),
      });

      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository([m1, m2]),
        hashDataSource: hashDataSource,
        dismissedDataSource: _FakeDismissedDataSource(),
      );

      final events = await repository.hashLibrary().toList();

      final last = events.last;
      expect(last.isComplete, isTrue);
      expect(last.processed, 2);
      expect(last.reused, 2);
      expect(last.failed, 0);
      expect(hashDataSource.writes, isEmpty);
    });

    test('emits a single complete event for an empty library', () async {
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(const []),
        hashDataSource: _FakeHashDataSource({}),
        dismissedDataSource: _FakeDismissedDataSource(),
      );

      final events = await repository.hashLibrary().toList();

      expect(events, hasLength(1));
      expect(events.single.total, 0);
      expect(events.single.isComplete, isTrue);
    });

    test('stops early when cancelled', () async {
      final media = List.generate(50, (i) => buildMedia('m$i'));
      final cache = {for (final m in media) m.id: hashFor(m, 0)};
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(media),
        hashDataSource: _FakeHashDataSource(cache),
        dismissedDataSource: _FakeDismissedDataSource(),
      );

      final cancellation = DuplicateScanCancellation()..cancel();
      final events = await repository
          .hashLibrary(cancellation: cancellation)
          .toList();

      expect(events.last.isCancelled, isTrue);
      expect(events.last.processed, lessThan(50));
    });
  });
}

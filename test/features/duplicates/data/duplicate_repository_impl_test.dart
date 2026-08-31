import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/repositories/duplicate_repository_impl.dart';
import 'package:media_fast_view/features/duplicates/data/services/perceptual_hasher.dart';
import 'package:media_fast_view/features/duplicates/data/services/video_thumbnail_hasher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/keeper_strategy.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
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

class _FakeHasher extends PerceptualHasher {
  _FakeHasher(this.results);

  final Map<String, ImageHashResult?> results;
  final List<String> hashedPaths = <String>[];

  @override
  Future<ImageHashResult?> hashFile(String path) async {
    hashedPaths.add(path);
    return results[path];
  }
}

class _FakeVideoThumbnailHasher implements VideoThumbnailHasher {
  _FakeVideoThumbnailHasher(this.results);

  final Map<String, ImageHashResult?> results;
  final List<String> hashedPaths = <String>[];

  @override
  Future<ImageHashResult?> hashVideo({
    required String path,
    required int size,
    required DateTime lastModified,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  }) async {
    hashedPaths.add(path);
    return results[path];
  }
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
    fingerprint: visualPerceptualFingerprint(
      mediaType: media.type,
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

  group('DuplicateRepositoryImpl image lookup', () {
    test('reports current cache coverage and excludes stale hashes', () async {
      final current = buildMedia('current');
      final stale = buildMedia('stale');
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[current, stale]),
        hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{
          current.id: hashFor(current, 0),
          stale.id: hashFor(stale, 0).copyWith(fingerprint: 'stale'),
        }),
        dismissedDataSource: _FakeDismissedDataSource(),
      );

      final coverage = await repository.getLibraryCoverage();

      expect(coverage.totalImages, 2);
      expect(coverage.readyImages, 1);
      expect(coverage.pendingImages, 1);
    });

    test(
      'matches multiple queries closest-first and includes exact matches',
      () async {
        final exact = buildMedia('exact');
        final close = buildMedia('close');
        final far = buildMedia('far');
        final hasher = _FakeHasher(<String, ImageHashResult?>{
          '/query-a.jpg': const ImageHashResult(
            hash: 0,
            width: 800,
            height: 600,
          ),
          '/query-b.jpg': const ImageHashResult(
            hash: 0xFFFF,
            width: 900,
            height: 700,
          ),
        });
        final repository = DuplicateRepositoryImpl(
          mediaRepository: _FakeMediaRepository(<MediaEntity>[
            exact,
            close,
            far,
          ]),
          hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{
            exact.id: hashFor(exact, 0),
            close.id: hashFor(close, 3),
            far.id: hashFor(far, 0xFFFF),
          }),
          dismissedDataSource: _FakeDismissedDataSource()
            ..signatures.add('${exact.id}|${close.id}'),
          hasher: hasher,
        );
        final sources = <ImageLookupSource>[
          ImageLookupSource(
            path: '/query-a.jpg',
            name: 'query-a.jpg',
            size: 100,
            lastModified: DateTime(2024),
          ),
          ImageLookupSource(
            path: '/query-b.jpg',
            name: 'query-b.jpg',
            size: 200,
            lastModified: DateTime(2024),
          ),
        ];

        final batch = await repository.findImageMatches(
          sources: sources,
          sensitivity: DuplicateSensitivity.strict,
        );

        expect(batch.results, hasLength(2));
        expect(
          batch.results.first.matches.map((match) => match.candidate.id),
          <String>[exact.id, close.id],
        );
        expect(
          batch.results.first.matches.map((match) => match.distance),
          <int>[0, 2],
        );
        expect(batch.results.last.matches.single.candidate.id, far.id);
        expect(hasher.hashedPaths, <String>['/query-a.jpg', '/query-b.jpg']);
      },
    );

    test('rematches existing queries without hashing them again', () async {
      final close = buildMedia('close');
      final hasher = _FakeHasher(<String, ImageHashResult?>{
        '/query.jpg': const ImageHashResult(hash: 0, width: 800, height: 600),
      });
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[close]),
        hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{
          close.id: hashFor(close, 0xFF),
        }),
        dismissedDataSource: _FakeDismissedDataSource(),
        hasher: hasher,
      );
      final source = ImageLookupSource(
        path: '/query.jpg',
        name: 'query.jpg',
        size: 100,
        lastModified: DateTime(2024),
      );
      final strict = await repository.findImageMatches(
        sources: <ImageLookupSource>[source],
        sensitivity: DuplicateSensitivity.strict,
      );

      final loose = await repository.rematchImageQueries(
        queries: <ImageLookupQuery>[strict.results.single.query!],
        sensitivity: DuplicateSensitivity.loose,
      );

      expect(strict.results.single.matches, isEmpty);
      expect(loose.results.single.matches.single.candidate.id, close.id);
      expect(hasher.hashedPaths, <String>['/query.jpg']);
    });

    test('matches video miniatures only against indexed videos', () async {
      final exactVideo = buildMedia('video-exact', type: MediaType.video);
      final closeVideo = buildMedia('video-close', type: MediaType.video);
      final identicalImage = buildMedia('image-exact');
      final videoHasher = _FakeVideoThumbnailHasher(<String, ImageHashResult?>{
        '/query.mov': const ImageHashResult(hash: 0, width: 512, height: 288),
      });
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[
          exactVideo,
          closeVideo,
          identicalImage,
        ]),
        hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{
          exactVideo.id: hashFor(exactVideo, 0),
          closeVideo.id: hashFor(closeVideo, 3),
          identicalImage.id: hashFor(identicalImage, 0),
        }),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoThumbnailHasher: videoHasher,
      );
      final source = ImageLookupSource(
        path: '/query.mov',
        name: 'query.mov',
        size: 5000,
        lastModified: DateTime(2024),
        mediaType: MediaType.video,
      );

      final batch = await repository.findImageMatches(
        sources: <ImageLookupSource>[source],
        sensitivity: DuplicateSensitivity.strict,
      );

      expect(
        batch.results.single.matches.map((match) => match.candidate.id),
        <String>[exactVideo.id, closeVideo.id],
      );
      expect(batch.searchedLibraryImages, 2);
      expect(videoHasher.hashedPaths, <String>['/query.mov']);
    });

    test('prepares only requested video miniature hashes', () async {
      final image = buildMedia('image');
      final video = buildMedia('video', type: MediaType.video);
      final imageHasher = _FakeHasher(<String, ImageHashResult?>{});
      final videoHasher = _FakeVideoThumbnailHasher(<String, ImageHashResult?>{
        video.path: const ImageHashResult(hash: 42, width: 512, height: 288),
      });
      final hashes = _FakeHashDataSource(<String, PerceptualHash>{});
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[image, video]),
        hashDataSource: hashes,
        dismissedDataSource: _FakeDismissedDataSource(),
        hasher: imageHasher,
        videoThumbnailHasher: videoHasher,
      );

      final events = await repository
          .hashLibrary(mediaTypes: const <MediaType>{MediaType.video})
          .toList();

      expect(events.last.total, 1);
      expect(events.last.isComplete, isTrue);
      expect(imageHasher.hashedPaths, isEmpty);
      expect(videoHasher.hashedPaths, <String>[video.path]);
      expect(hashes.store[video.id]?.hash, 42);
      expect(
        hashes.store[video.id]?.fingerprint,
        startsWith('video_thumbnail_v1_'),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/models/media_lookup_mode.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/data_sources/video_frame_hash_data_source.dart';
import 'package:media_fast_view/features/duplicates/data/repositories/duplicate_repository_impl.dart';
import 'package:media_fast_view/features/duplicates/data/services/perceptual_hasher.dart';
import 'package:media_fast_view/features/duplicates/data/services/video_thumbnail_hasher.dart';
import 'package:media_fast_view/features/duplicates/data/services/video_frame_hasher.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/keeper_strategy.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/perceptual_hash.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_hash.dart';
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

class _FakeVideoFrameHashDataSource implements VideoFrameHashDataSource {
  _FakeVideoFrameHashDataSource(this.store);

  final Map<String, List<VideoFrameHash>> store;
  final List<Map<String, List<VideoFrameHash>>> writes =
      <Map<String, List<VideoFrameHash>>>[];

  @override
  Future<Map<String, List<VideoFrameHash>>> getByMediaIds(
    Iterable<String> mediaIds,
  ) async {
    return <String, List<VideoFrameHash>>{
      for (final mediaId in mediaIds)
        if (store[mediaId] case final hashes?) mediaId: hashes,
    };
  }

  @override
  Future<void> replaceAll(
    Map<String, List<VideoFrameHash>> hashesByMediaId,
  ) async {
    writes.add(hashesByMediaId);
    store.addAll(hashesByMediaId);
  }
}

class _FakeVideoFrameHasher implements VideoFrameHasher {
  _FakeVideoFrameHasher(this.results);

  final Map<String, List<VideoFrameHash>?> results;
  final List<String> hashedPaths = <String>[];

  @override
  Future<List<VideoFrameHash>?> hashVideo({
    required String mediaId,
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

List<VideoFrameHash> frameHashesFor(
  MediaEntity video,
  List<int> hashes, {
  String? fingerprint,
}) {
  return <VideoFrameHash>[
    for (var index = 0; index < videoFrameSamplePercents.length; index++)
      VideoFrameHash(
        mediaId: video.id,
        positionPercent: videoFrameSamplePercents[index],
        timestamp: Duration(seconds: (index + 1) * 10),
        hash: hashes[index],
        width: 512,
        height: 288,
        fingerprint:
            fingerprint ??
            videoFrameLookupFingerprint(
              size: video.size,
              lastModified: video.lastModified,
            ),
      ),
  ];
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

  group('DuplicateRepositoryImpl video from frame lookup', () {
    test(
      'reports coverage only for complete current five-frame sets',
      () async {
        final ready = buildMedia('ready-video', type: MediaType.video);
        final stale = buildMedia('stale-video', type: MediaType.video);
        final image = buildMedia('image');
        final frames = _FakeVideoFrameHashDataSource(
          <String, List<VideoFrameHash>>{
            ready.id: frameHashesFor(ready, <int>[0, 1, 2, 3, 4]),
            stale.id: frameHashesFor(stale, <int>[
              0,
              1,
              2,
              3,
              4,
            ], fingerprint: 'stale'),
          },
        );
        final repository = DuplicateRepositoryImpl(
          mediaRepository: _FakeMediaRepository(<MediaEntity>[
            ready,
            stale,
            image,
          ]),
          hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{}),
          dismissedDataSource: _FakeDismissedDataSource(),
          videoFrameHashDataSource: frames,
        );

        final coverage = await repository.getVideoFrameIndexCoverage();

        expect(coverage.totalVideos, 2);
        expect(coverage.readyVideos, 1);
        expect(coverage.pendingVideos, 1);
      },
    );

    test(
      'preparation reuses current videos and atomically stores new sets',
      () async {
        final ready = buildMedia('ready-video', type: MediaType.video);
        final pending = buildMedia('pending-video', type: MediaType.video);
        final generated = frameHashesFor(pending, <int>[10, 20, 30, 40, 50]);
        final dataSource = _FakeVideoFrameHashDataSource(
          <String, List<VideoFrameHash>>{
            ready.id: frameHashesFor(ready, <int>[0, 1, 2, 3, 4]),
          },
        );
        final hasher = _FakeVideoFrameHasher(<String, List<VideoFrameHash>?>{
          pending.path: generated,
        });
        final repository = DuplicateRepositoryImpl(
          mediaRepository: _FakeMediaRepository(<MediaEntity>[ready, pending]),
          hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{}),
          dismissedDataSource: _FakeDismissedDataSource(),
          videoFrameHashDataSource: dataSource,
          videoFrameHasher: hasher,
        );

        final events = await repository.hashVideoFrames().toList();

        expect(events.last.isComplete, isTrue);
        expect(events.last.reused, 1);
        expect(hasher.hashedPaths, <String>[pending.path]);
        expect(dataSource.store[pending.id], generated);
      },
    );

    test('returns each video once using its closest sampled frame', () async {
      final first = buildMedia('first-video', type: MediaType.video);
      final second = buildMedia('second-video', type: MediaType.video);
      final image = buildMedia('identical-image');
      final frameDataSource = _FakeVideoFrameHashDataSource(
        <String, List<VideoFrameHash>>{
          first.id: frameHashesFor(first, <int>[0xFF, 3, 0xFF, 0xFF, 0xFF]),
          second.id: frameHashesFor(second, <int>[0xFF, 0xFF, 7, 0xFF, 0xFF]),
        },
      );
      final queryHasher = _FakeHasher(<String, ImageHashResult?>{
        '/frame.jpg': const ImageHashResult(hash: 0, width: 800, height: 600),
      });
      final repository = DuplicateRepositoryImpl(
        mediaRepository: _FakeMediaRepository(<MediaEntity>[
          first,
          second,
          image,
        ]),
        hashDataSource: _FakeHashDataSource(<String, PerceptualHash>{
          image.id: hashFor(image, 0),
        }),
        dismissedDataSource: _FakeDismissedDataSource(),
        videoFrameHashDataSource: frameDataSource,
        hasher: queryHasher,
      );
      final source = ImageLookupSource(
        path: '/frame.jpg',
        name: 'frame.jpg',
        size: 100,
        lastModified: DateTime(2024),
      );

      final batch = await repository.findImageMatches(
        sources: <ImageLookupSource>[source],
        sensitivity: DuplicateSensitivity.strict,
        lookupMode: MediaLookupMode.videoFromFrame,
      );

      final matches = batch.results.single.matches;
      expect(matches.map((match) => match.candidate.id), <String>[
        first.id,
        second.id,
      ]);
      expect(matches.map((match) => match.distance), <int>[2, 3]);
      expect(matches.first.matchedVideoFrame?.positionPercent, 30);
      expect(
        matches.first.matchedVideoFrame?.timestamp,
        const Duration(seconds: 20),
      );
      expect(batch.searchedLibraryImages, 2);
    });
  });
}

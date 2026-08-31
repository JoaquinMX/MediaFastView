import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/entities/directory_entity.dart';
import '../../../media_library/domain/repositories/directory_repository.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../../../shared/utils/bookmark_resolver.dart';
import '../../domain/entities/duplicate_candidate.dart';
import '../../domain/entities/duplicate_group.dart';
import '../../domain/entities/duplicate_library_coverage.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/duplicate_sensitivity.dart';
import '../../domain/entities/image_lookup_batch.dart';
import '../../domain/entities/image_lookup_match.dart';
import '../../domain/entities/image_lookup_query.dart';
import '../../domain/entities/image_lookup_result.dart';
import '../../domain/entities/image_lookup_source.dart';
import '../../domain/entities/keeper_strategy.dart';
import '../../domain/entities/perceptual_hash.dart';
import '../../domain/repositories/duplicate_repository.dart';
import '../data_sources/dismissed_group_data_source.dart';
import '../data_sources/perceptual_hash_data_source.dart';
import '../services/duplicate_clusterer.dart';
import '../services/perceptual_hasher.dart';
import '../services/video_thumbnail_hasher.dart';

class DuplicateRepositoryImpl implements DuplicateRepository {
  DuplicateRepositoryImpl({
    required MediaRepository mediaRepository,
    required PerceptualHashDataSource hashDataSource,
    required DismissedGroupDataSource dismissedDataSource,
    DirectoryRepository? directoryRepository,
    VideoThumbnailHasher? videoThumbnailHasher,
    PerceptualHasher hasher = const PerceptualHasher(),
    DuplicateClusterer clusterer = const DuplicateClusterer(),
  }) : _mediaRepository = mediaRepository,
       _hashDataSource = hashDataSource,
       _dismissedDataSource = dismissedDataSource,
       _directoryRepository = directoryRepository,
       _videoThumbnailHasher = videoThumbnailHasher,
       _hasher = hasher,
       _clusterer = clusterer;

  final MediaRepository _mediaRepository;
  final PerceptualHashDataSource _hashDataSource;
  final DismissedGroupDataSource _dismissedDataSource;
  final DirectoryRepository? _directoryRepository;
  final VideoThumbnailHasher? _videoThumbnailHasher;
  final PerceptualHasher _hasher;
  final DuplicateClusterer _clusterer;

  /// How many hashed images to accumulate before flushing to the cache. Bounds
  /// memory and means a cancelled scan still banks the work it managed to do.
  static const int _persistBatchSize = 64;

  /// How often to surface progress and yield to the event loop. Emitting per
  /// image would flood the UI; never yielding on the cheap cache-reuse path
  /// would freeze the frame.
  static const int _emitEvery = 16;

  /// The active profile's images, from the persisted library index.
  ///
  /// Uses the media the app has already cached rather than re-walking disk: it is
  /// the app's own model of the library and keeps the scan bounded. Folders never
  /// browsed are therefore out of scope until they are indexed.
  Future<List<MediaEntity>> _libraryMedia(Set<MediaType> mediaTypes) async {
    final media = await _mediaRepository.getAllMedia();
    return media
        .where((item) => mediaTypes.contains(item.type))
        .toList(growable: false);
  }

  Future<List<MediaEntity>> _libraryImages() {
    return _libraryMedia(const <MediaType>{MediaType.image});
  }

  @override
  Stream<DuplicateScanProgress> hashLibrary({
    DuplicateScanCancellation? cancellation,
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) async* {
    final media = await _libraryMedia(mediaTypes);
    final total = media.length;
    if (total == 0) {
      yield const DuplicateScanProgress(
        processed: 0,
        total: 0,
        isComplete: true,
      );
      return;
    }

    final cached = await _hashDataSource.getByMediaIds(
      media.map((item) => item.id),
    );
    final directories = mediaTypes.contains(MediaType.video)
        ? await _loadDirectories()
        : const <DirectoryEntity>[];

    var processed = 0;
    var reused = 0;
    var failed = 0;
    final pending = <PerceptualHash>[];

    for (var i = 0; i < media.length; i++) {
      if (cancellation?.isCancelled ?? false) {
        await _flush(pending);
        yield DuplicateScanProgress(
          processed: processed,
          total: total,
          reused: reused,
          failed: failed,
          isCancelled: true,
        );
        return;
      }

      final item = media[i];
      final fingerprint = _fingerprint(item);
      final existing = cached[item.id];

      if (existing != null && existing.fingerprint == fingerprint) {
        reused++;
      } else {
        final result = await _hashMedia(
          item,
          directories: directories,
          cancellation: cancellation,
        );
        if (cancellation?.isCancelled ?? false) {
          await _flush(pending);
          yield DuplicateScanProgress(
            processed: processed,
            total: total,
            reused: reused,
            failed: failed,
            isCancelled: true,
          );
          return;
        }
        if (result == null) {
          failed++;
        } else {
          pending.add(
            PerceptualHash(
              mediaId: item.id,
              hash: result.hash,
              width: result.width,
              height: result.height,
              fingerprint: fingerprint,
            ),
          );
          if (pending.length >= _persistBatchSize) {
            await _flush(pending);
          }
        }
      }
      processed++;

      final isLast = i == media.length - 1;
      if (processed % _emitEvery == 0 || isLast) {
        yield DuplicateScanProgress(
          processed: processed,
          total: total,
          reused: reused,
          failed: failed,
          isComplete: isLast,
        );
        // Hand the frame back so the progress bar can paint and the decode does
        // not starve the UI.
        await Future<void>.delayed(Duration.zero);
      }
    }

    await _flush(pending);
  }

  @override
  Future<DuplicateLibraryCoverage> getLibraryCoverage({
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) async {
    final media = await _libraryMedia(mediaTypes);
    if (media.isEmpty) {
      return const DuplicateLibraryCoverage(totalImages: 0, readyImages: 0);
    }

    final cached = await _hashDataSource.getByMediaIds(
      media.map((item) => item.id),
    );
    var ready = 0;
    for (final item in media) {
      final hash = cached[item.id];
      if (hash != null && hash.fingerprint == _fingerprint(item)) {
        ready++;
      }
    }
    return DuplicateLibraryCoverage(
      totalImages: media.length,
      readyImages: ready,
    );
  }

  @override
  Future<ImageLookupBatch> findImageMatches({
    required List<ImageLookupSource> sources,
    required DuplicateSensitivity sensitivity,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) async {
    final queries = <ImageLookupQuery>[];
    final failedByPath = <String, ImageLookupResult>{};
    for (var index = 0; index < sources.length; index++) {
      if (cancellation?.isCancelled ?? false) {
        break;
      }
      final source = sources[index];
      final hash = await _hashSource(source, cancellation: cancellation);
      if (cancellation?.isCancelled ?? false) {
        break;
      }
      if (hash == null) {
        failedByPath[source.path] = ImageLookupResult(
          source: source,
          matches: const <ImageLookupMatch>[],
          errorMessage: 'The image could not be read or decoded.',
        );
      } else {
        queries.add(
          ImageLookupQuery(
            source: source,
            hash: hash.hash,
            width: hash.width,
            height: hash.height,
          ),
        );
      }
      onProgress?.call(index + 1, sources.length);
      await Future<void>.delayed(Duration.zero);
    }

    if (cancellation?.isCancelled ?? false) {
      return const ImageLookupBatch(
        results: <ImageLookupResult>[],
        searchedLibraryImages: 0,
      );
    }

    final matched = await rematchImageQueries(
      queries: queries,
      sensitivity: sensitivity,
      cancellation: cancellation,
    );
    final matchedByPath = <String, ImageLookupResult>{
      for (final result in matched.results) result.source.path: result,
    };
    final orderedResults = <ImageLookupResult>[
      for (final source in sources)
        if (failedByPath[source.path] case final failed?)
          failed
        else if (matchedByPath[source.path] case final matched?)
          matched,
    ];

    return ImageLookupBatch(
      results: List<ImageLookupResult>.unmodifiable(orderedResults),
      searchedLibraryImages: matched.searchedLibraryImages,
    );
  }

  @override
  Future<ImageLookupBatch> rematchImageQueries({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) async {
    final mediaTypes = queries.map((query) => query.source.mediaType).toSet();
    final candidates = await _loadLookupCandidates(mediaTypes);
    final results = <ImageLookupResult>[];
    for (var index = 0; index < queries.length; index++) {
      if (cancellation?.isCancelled ?? false) {
        break;
      }
      final query = queries[index];
      final matches = <ImageLookupMatch>[];
      for (final candidate in candidates) {
        if (candidate.media.type != query.source.mediaType) {
          continue;
        }
        final distance = hammingDistance(query.hash, candidate.hash);
        if (distance <= sensitivity.threshold) {
          matches.add(
            ImageLookupMatch(candidate: candidate, distance: distance),
          );
        }
      }
      matches.sort((first, second) {
        final byDistance = first.distance.compareTo(second.distance);
        if (byDistance != 0) {
          return byDistance;
        }
        return first.candidate.media.path.compareTo(
          second.candidate.media.path,
        );
      });
      results.add(
        ImageLookupResult(
          source: query.source,
          query: query,
          matches: List<ImageLookupMatch>.unmodifiable(matches),
        ),
      );
      onProgress?.call(index + 1, queries.length);
      await Future<void>.delayed(Duration.zero);
    }
    return ImageLookupBatch(
      results: List<ImageLookupResult>.unmodifiable(results),
      searchedLibraryImages: candidates.length,
    );
  }

  Future<List<DuplicateCandidate>> _loadLookupCandidates(
    Set<MediaType> mediaTypes,
  ) async {
    final images = await _libraryMedia(mediaTypes);
    final cached = await _hashDataSource.getByMediaIds(
      images.map((image) => image.id),
    );
    final candidates = <DuplicateCandidate>[];
    for (final image in images) {
      final hash = cached[image.id];
      if (hash == null || hash.fingerprint != _fingerprint(image)) {
        continue;
      }
      candidates.add(
        DuplicateCandidate(
          media: image,
          width: hash.width,
          height: hash.height,
          hash: hash.hash,
        ),
      );
    }
    return candidates;
  }

  Future<ImageHashResult?> _hashSource(
    ImageLookupSource source, {
    DuplicateScanCancellation? cancellation,
  }) {
    if (source.mediaType == MediaType.video) {
      return _videoThumbnailHasher?.hashVideo(
            path: source.path,
            size: source.size,
            lastModified: source.lastModified,
            bookmarkData: source.bookmarkData,
            cancellation: cancellation,
          ) ??
          Future<ImageHashResult?>.value();
    }
    return _hasher.hashFile(source.path);
  }

  Future<ImageHashResult?> _hashMedia(
    MediaEntity media, {
    required List<DirectoryEntity> directories,
    DuplicateScanCancellation? cancellation,
  }) {
    if (media.type == MediaType.video) {
      final bookmark =
          media.bookmarkData ?? resolveBookmarkForPath(media.path, directories);
      return _videoThumbnailHasher?.hashVideo(
            path: media.path,
            size: media.size,
            lastModified: media.lastModified,
            bookmarkData: bookmark,
            cancellation: cancellation,
          ) ??
          Future<ImageHashResult?>.value();
    }
    return _hasher.hashFile(media.path);
  }

  Future<List<DirectoryEntity>> _loadDirectories() async {
    final repository = _directoryRepository;
    if (repository == null) {
      return const <DirectoryEntity>[];
    }
    return repository.getDirectories();
  }

  String _fingerprint(MediaEntity media) {
    return visualPerceptualFingerprint(
      mediaType: media.type,
      size: media.size,
      lastModified: media.lastModified,
    );
  }

  Future<void> _flush(List<PerceptualHash> pending) async {
    if (pending.isEmpty) {
      return;
    }
    await _hashDataSource.putAll(List<PerceptualHash>.from(pending));
    pending.clear();
  }

  @override
  Future<List<DuplicateGroup>> loadGroups({
    required DuplicateSensitivity sensitivity,
    required KeeperStrategy keeperStrategy,
  }) async {
    final images = await _libraryImages();
    if (images.length < 2) {
      return const [];
    }

    final cached = await _hashDataSource.getByMediaIds(
      images.map((image) => image.id),
    );

    final candidates = <DuplicateCandidate>[];
    for (final image in images) {
      final hash = cached[image.id];
      if (hash == null) {
        continue; // Not hashed yet, or undecodable — cannot be compared.
      }
      candidates.add(
        DuplicateCandidate(
          media: image,
          width: hash.width,
          height: hash.height,
          hash: hash.hash,
        ),
      );
    }

    final clusters = _clusterer.cluster(candidates, sensitivity.threshold);
    if (clusters.isEmpty) {
      return const [];
    }

    final dismissed = await _dismissedDataSource.getSignatures();
    final groups = <DuplicateGroup>[];
    for (final cluster in clusters) {
      final group = DuplicateGroup.fromCandidates(cluster, keeperStrategy);
      if (dismissed.contains(group.signature)) {
        continue;
      }
      groups.add(group);
    }

    groups.sort((a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes));
    return groups;
  }

  @override
  Future<void> dismissGroup(String signature) {
    return _dismissedDataSource.add(signature);
  }
}

import 'dart:io';

import '../../../../core/models/media_lookup_mode.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';
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
import '../../domain/entities/image_lookup_progress.dart';
import '../../domain/entities/image_lookup_query.dart';
import '../../domain/entities/image_lookup_result.dart';
import '../../domain/entities/image_lookup_source.dart';
import '../../domain/entities/image_lookup_update.dart';
import '../../domain/entities/image_lookup_verification_summary.dart';
import '../../domain/entities/keeper_strategy.dart';
import '../../domain/entities/matched_video_frame.dart';
import '../../domain/entities/perceptual_hash.dart';
import '../../domain/entities/video_frame_hash.dart';
import '../../domain/entities/video_frame_index_coverage.dart';
import '../../domain/entities/maximum_video_frame_descriptor.dart';
import '../../domain/entities/video_frame_presentation_time.dart';
import '../../domain/entities/video_maximum_frame_index_chunk.dart';
import '../../domain/entities/video_maximum_frame_index_status.dart';
import '../../domain/repositories/duplicate_repository.dart';
import '../data_sources/dismissed_group_data_source.dart';
import '../data_sources/perceptual_hash_data_source.dart';
import '../data_sources/video_frame_hash_data_source.dart';
import '../data_sources/video_maximum_frame_index_data_source.dart';
import '../isar/maximum_video_frame_descriptor_codec.dart';
import '../services/duplicate_clusterer.dart';
import '../services/perceptual_hasher.dart';
import '../services/video_thumbnail_hasher.dart';
import '../services/video_frame_hasher.dart';
import '../services/native_compact_descriptor_generator.dart';
import '../services/native_maximum_video_frame_indexer.dart';
import '../services/native_vision_frame_matcher.dart';

class DuplicateRepositoryImpl implements DuplicateRepository {
  DuplicateRepositoryImpl({
    required MediaRepository mediaRepository,
    required PerceptualHashDataSource hashDataSource,
    required DismissedGroupDataSource dismissedDataSource,
    DirectoryRepository? directoryRepository,
    VideoThumbnailHasher? videoThumbnailHasher,
    VideoFrameHashDataSource? videoFrameHashDataSource,
    VideoFrameHasher? videoFrameHasher,
    VideoMaximumFrameIndexDataSource? videoMaximumFrameIndexDataSource,
    MaximumVideoFrameIndexer? maximumVideoFrameIndexer,
    CompactImageDescriptorGenerator? compactDescriptorGenerator,
    VisionFrameMatcher? visionFrameMatcher,
    Future<bool> Function(List<MediaEntity> videos)?
    videoSourceSnapshotValidator,
    PerceptualHasher hasher = const PerceptualHasher(),
    DuplicateClusterer clusterer = const DuplicateClusterer(),
  }) : _mediaRepository = mediaRepository,
       _hashDataSource = hashDataSource,
       _dismissedDataSource = dismissedDataSource,
       _directoryRepository = directoryRepository,
       _videoThumbnailHasher = videoThumbnailHasher,
       _videoFrameHashDataSource = videoFrameHashDataSource,
       _videoFrameHasher = videoFrameHasher,
       _videoMaximumFrameIndexDataSource = videoMaximumFrameIndexDataSource,
       _maximumVideoFrameIndexer = maximumVideoFrameIndexer,
       _compactDescriptorGenerator = compactDescriptorGenerator,
       _visionFrameMatcher = visionFrameMatcher,
       _videoSourceSnapshotValidator = videoSourceSnapshotValidator,
       _hasher = hasher,
       _clusterer = clusterer;

  final MediaRepository _mediaRepository;
  final PerceptualHashDataSource _hashDataSource;
  final DismissedGroupDataSource _dismissedDataSource;
  final DirectoryRepository? _directoryRepository;
  final VideoThumbnailHasher? _videoThumbnailHasher;
  final VideoFrameHashDataSource? _videoFrameHashDataSource;
  final VideoFrameHasher? _videoFrameHasher;
  final VideoMaximumFrameIndexDataSource? _videoMaximumFrameIndexDataSource;
  final MaximumVideoFrameIndexer? _maximumVideoFrameIndexer;
  final CompactImageDescriptorGenerator? _compactDescriptorGenerator;
  final VisionFrameMatcher? _visionFrameMatcher;
  final Future<bool> Function(List<MediaEntity> videos)?
  _videoSourceSnapshotValidator;
  final PerceptualHasher _hasher;
  final DuplicateClusterer _clusterer;

  /// Versioned raw-score cache for sensitivity-only rematches.
  ///
  /// The repository is profile-scoped by the provider, and the signature also
  /// includes every indexed video marker. A rebuild or a profile replacement
  /// therefore cannot reuse scores from a different index generation.
  final Map<String, _MaximumQueryCache> _maximumQueryCache =
      <String, _MaximumQueryCache>{};

  static const int _maximumCandidatePolicyVersion = 1;
  static const int _maximumVerificationBatchSize = 8;
  static const int _maximumInitialVideoCount = 16;

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
  Future<VideoFrameIndexCoverage> getVideoFrameIndexCoverage({
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) async {
    if (lookupPrecision == VideoFrameLookupPrecision.maximum) {
      return _getMaximumVideoFrameIndexCoverage();
    }
    final videos = await _libraryMedia(const <MediaType>{MediaType.video});
    if (videos.isEmpty) {
      return const VideoFrameIndexCoverage(totalVideos: 0, readyVideos: 0);
    }
    final cached = await _videoFrameHashDataSource?.getByMediaIds(
      videos.map((video) => video.id),
    );
    var ready = 0;
    for (final video in videos) {
      if (_hasCurrentVideoFrames(video, cached?[video.id])) {
        ready++;
      }
    }
    return VideoFrameIndexCoverage(
      totalVideos: videos.length,
      readyVideos: ready,
    );
  }

  Future<VideoFrameIndexCoverage> _getMaximumVideoFrameIndexCoverage() async {
    final videos = await _libraryMedia(const <MediaType>{MediaType.video});
    final dataSource = _videoMaximumFrameIndexDataSource;
    if (videos.isEmpty) {
      return const VideoFrameIndexCoverage(
        totalVideos: 0,
        readyVideos: 0,
        precision: VideoFrameLookupPrecision.maximum,
      );
    }
    if (dataSource == null) {
      return VideoFrameIndexCoverage(
        totalVideos: videos.length,
        readyVideos: 0,
        precision: VideoFrameLookupPrecision.maximum,
      );
    }
    final statuses = await dataSource.getStatuses(
      videos.map((video) => video.id),
    );
    var ready = 0;
    var indexedFrames = 0;
    for (final video in videos) {
      final status = statuses[video.id];
      if (!_hasCurrentMaximumVideoIndex(video, status)) {
        continue;
      }
      ready++;
      indexedFrames += status!.frameCount;
    }
    return VideoFrameIndexCoverage(
      totalVideos: videos.length,
      readyVideos: ready,
      precision: VideoFrameLookupPrecision.maximum,
      indexedFrameCount: indexedFrames,
    );
  }

  @override
  Stream<DuplicateScanProgress> hashVideoFrames({
    DuplicateScanCancellation? cancellation,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) async* {
    if (lookupPrecision == VideoFrameLookupPrecision.maximum) {
      yield* _hashMaximumVideoFrames(cancellation: cancellation);
      return;
    }
    final videos = await _libraryMedia(const <MediaType>{MediaType.video});
    final total = videos.length;
    if (total == 0) {
      yield const DuplicateScanProgress(
        processed: 0,
        total: 0,
        isComplete: true,
      );
      return;
    }
    final cached = await _videoFrameHashDataSource?.getByMediaIds(
      videos.map((video) => video.id),
    );
    final directories = await _loadDirectories();
    var processed = 0;
    var reused = 0;
    var failed = 0;
    final pending = <String, List<VideoFrameHash>>{};

    for (var index = 0; index < videos.length; index++) {
      if (cancellation?.isCancelled ?? false) {
        await _flushVideoFrames(pending);
        yield DuplicateScanProgress(
          processed: processed,
          total: total,
          reused: reused,
          failed: failed,
          isCancelled: true,
        );
        return;
      }
      final video = videos[index];
      if (_hasCurrentVideoFrames(video, cached?[video.id])) {
        reused++;
      } else {
        final bookmark =
            video.bookmarkData ??
            resolveBookmarkForPath(video.path, directories);
        final hashes = await _videoFrameHasher?.hashVideo(
          mediaId: video.id,
          path: video.path,
          size: video.size,
          lastModified: video.lastModified,
          bookmarkData: bookmark,
          cancellation: cancellation,
        );
        if (cancellation?.isCancelled ?? false) {
          await _flushVideoFrames(pending);
          yield DuplicateScanProgress(
            processed: processed,
            total: total,
            reused: reused,
            failed: failed,
            isCancelled: true,
          );
          return;
        }
        if (hashes == null) {
          failed++;
        } else {
          pending[video.id] = hashes;
          if (pending.length >= _persistBatchSize) {
            await _flushVideoFrames(pending);
          }
        }
      }
      processed++;
      final isLast = index == videos.length - 1;
      if (processed % _emitEvery == 0 || isLast) {
        yield DuplicateScanProgress(
          processed: processed,
          total: total,
          reused: reused,
          failed: failed,
          isComplete: isLast,
        );
        await Future<void>.delayed(Duration.zero);
      }
    }
    await _flushVideoFrames(pending);
  }

  Stream<DuplicateScanProgress> _hashMaximumVideoFrames({
    DuplicateScanCancellation? cancellation,
  }) async* {
    final videos = await _libraryMedia(const <MediaType>{MediaType.video});
    final dataSource = _videoMaximumFrameIndexDataSource;
    final indexer = _maximumVideoFrameIndexer;
    final total = videos.length;
    if (total == 0) {
      yield const DuplicateScanProgress(
        processed: 0,
        total: 0,
        isComplete: true,
      );
      return;
    }
    if (dataSource == null || indexer == null) {
      yield DuplicateScanProgress(
        processed: 0,
        total: total,
        failed: total,
        isComplete: true,
      );
      return;
    }

    final directories = await _loadDirectories();
    final GenerationAwareVideoMaximumFrameIndexDataSource? generationAware =
        dataSource is GenerationAwareVideoMaximumFrameIndexDataSource
        ? dataSource as GenerationAwareVideoMaximumFrameIndexDataSource
        : null;
    var processed = 0;
    var reused = 0;
    var failed = 0;
    for (final video in videos) {
      if (cancellation?.isCancelled ?? false) {
        yield DuplicateScanProgress(
          processed: processed,
          total: total,
          reused: reused,
          failed: failed,
          isCancelled: true,
        );
        return;
      }
      final existing = (await dataSource.getStatuses(<String>[
        video.id,
      ]))[video.id];
      if (_hasCurrentMaximumVideoIndex(video, existing)) {
        reused++;
      } else {
        final generation = generationAware?.generation;
        var indexed = false;
        await for (final event in _indexMaximumVideo(
          video,
          directories: directories,
          dataSource: dataSource,
          indexer: indexer,
          cancellation: cancellation,
          generation: generation,
        )) {
          if (event.isComplete) {
            indexed = event.succeeded;
          } else {
            yield DuplicateScanProgress(
              processed: processed,
              total: total,
              reused: reused,
              failed: failed,
              currentItemProcessed: event.frameCount,
              currentItemTotal: event.totalFrameCount,
            );
          }
        }
        if (cancellation?.isCancelled ?? false) {
          yield DuplicateScanProgress(
            processed: processed,
            total: total,
            reused: reused,
            failed: failed,
            isCancelled: true,
          );
          return;
        }
        if (!indexed) {
          if (generationAware != null &&
              generationAware.generation != generation) {
            yield DuplicateScanProgress(
              processed: processed,
              total: total,
              reused: reused,
              failed: failed,
              isCancelled: true,
            );
            return;
          }
          failed++;
        }
      }
      processed++;
      final isLast = processed == total;
      yield DuplicateScanProgress(
        processed: processed,
        total: total,
        reused: reused,
        failed: failed,
        isComplete: isLast,
      );
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<bool> _beginMaximumIndex(
    VideoMaximumFrameIndexDataSource dataSource,
    VideoMaximumFrameIndexStatus status,
  ) async {
    await dataSource.begin(status);
    return true;
  }

  Future<bool> _putMaximumIndexChunk(
    VideoMaximumFrameIndexDataSource dataSource,
    VideoMaximumFrameIndexChunk chunk,
  ) async {
    await dataSource.putChunk(chunk);
    return true;
  }

  Future<bool> _completeMaximumIndex(
    VideoMaximumFrameIndexDataSource dataSource,
    VideoMaximumFrameIndexStatus status,
  ) async {
    await dataSource.complete(status);
    return true;
  }

  Stream<_MaximumIndexEvent> _indexMaximumVideo(
    MediaEntity video, {
    required List<DirectoryEntity> directories,
    required VideoMaximumFrameIndexDataSource dataSource,
    required MaximumVideoFrameIndexer indexer,
    required int? generation,
    DuplicateScanCancellation? cancellation,
  }) async* {
    final GenerationAwareVideoMaximumFrameIndexDataSource? generationAware =
        dataSource is GenerationAwareVideoMaximumFrameIndexDataSource
        ? dataSource as GenerationAwareVideoMaximumFrameIndexDataSource
        : null;
    bool isCurrentGeneration() {
      return generationAware == null ||
          generationAware.generation == generation;
    }

    if (!isCurrentGeneration()) {
      yield const _MaximumIndexEvent.failure();
      return;
    }
    final fingerprint = maximumVideoFrameLookupFingerprint(
      size: video.size,
      lastModified: video.lastModified,
    );
    final building = VideoMaximumFrameIndexStatus(
      mediaId: video.id,
      fingerprint: fingerprint,
      sourceSize: video.size,
      sourceLastModified: video.lastModified,
      descriptorVersion: maximumVideoFrameDescriptorVersion,
      visionRevision: maximumVideoFrameVisionRevision,
      frameCount: 0,
      chunkCount: 0,
      state: MaximumVideoFrameIndexState.building,
      computedAt: DateTime.now(),
    );
    final began = generationAware == null
        ? await _beginMaximumIndex(dataSource, building)
        : await generationAware.beginIfCurrent(building, generation!);
    if (!began) {
      yield const _MaximumIndexEvent.failure();
      return;
    }
    final bookmark =
        resolveBookmarkForPath(video.path, directories) ?? video.bookmarkData;
    final requestId =
        'maximum-${video.id}-${DateTime.now().microsecondsSinceEpoch}';
    var frameCount = 0;
    var chunkCount = 0;
    var sawComplete = false;
    try {
      await for (final nativeChunk in indexer.index(
        requestId: requestId,
        path: video.path,
        bookmarkData: bookmark,
        cancellation: cancellation,
      )) {
        if ((cancellation?.isCancelled ?? false) || !isCurrentGeneration()) {
          if (isCurrentGeneration()) {
            await dataSource.delete(video.id);
          }
          yield const _MaximumIndexEvent.failure();
          return;
        }
        final descriptors = nativeChunk.frames
            .map((frame) {
              final presentationTime = frame.presentationTime;
              if (presentationTime == null || presentationTime.timescale <= 0) {
                throw const FormatException(
                  'Maximum-precision frame is missing its exact timestamp',
                );
              }
              return MaximumVideoFrameDescriptor(
                mediaId: video.id,
                frameIndex: frame.frameIndex,
                timestamp: frame.timestamp,
                fullFrameHash: frame.fullFrameHash,
                centerCropHash: frame.centerCropHash,
                width: frame.width,
                height: frame.height,
                presentationTime: presentationTime,
              );
            })
            .toList(growable: false);
        if (descriptors.isNotEmpty) {
          final chunk = VideoMaximumFrameIndexChunk(
            mediaId: video.id,
            chunkIndex: chunkCount,
            fingerprint: fingerprint,
            descriptors: descriptors,
            computedAt: DateTime.now(),
          );
          final persisted = generationAware == null
              ? await _putMaximumIndexChunk(dataSource, chunk)
              : await generationAware.putChunkIfCurrent(chunk, generation!);
          if (!persisted) {
            yield const _MaximumIndexEvent.failure();
            return;
          }
          frameCount += descriptors.length;
          chunkCount++;
          yield _MaximumIndexEvent.progress(frameCount);
        }
        if (nativeChunk.isComplete) {
          sawComplete = true;
          break;
        }
      }
      if ((cancellation?.isCancelled ?? false) ||
          !isCurrentGeneration() ||
          !sawComplete ||
          frameCount == 0) {
        if (isCurrentGeneration()) {
          await dataSource.delete(video.id);
        }
        yield const _MaximumIndexEvent.failure();
        return;
      }
      if (!isCurrentGeneration()) {
        yield const _MaximumIndexEvent.failure();
        return;
      }
      final completed = building.copyWith(
        frameCount: frameCount,
        chunkCount: chunkCount,
        state: MaximumVideoFrameIndexState.complete,
      );
      final completedSuccessfully = generationAware == null
          ? await _completeMaximumIndex(dataSource, completed)
          : await generationAware.completeIfCurrent(completed, generation!);
      if (!completedSuccessfully) {
        yield const _MaximumIndexEvent.failure();
        return;
      }
      yield _MaximumIndexEvent.complete(frameCount);
    } on MaximumVideoFrameIndexCancelledException {
      if (isCurrentGeneration()) {
        await dataSource.delete(video.id);
      }
      yield const _MaximumIndexEvent.failure();
    } catch (_) {
      if (isCurrentGeneration()) {
        await dataSource.delete(video.id);
      }
      yield const _MaximumIndexEvent.failure();
    } finally {
      if (!sawComplete || (cancellation?.isCancelled ?? false)) {
        try {
          await indexer.cancel(requestId);
        } catch (_) {
          // Native cleanup is best effort when the platform channel is gone.
        }
      }
    }
  }

  @override
  Future<ImageLookupBatch> findImageMatches({
    required List<ImageLookupSource> sources,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
    DuplicateScanCancellation? cancellation,
    void Function(ImageLookupProgress progress)? onProgress,
    void Function(ImageLookupUpdate update)? onUpdate,
  }) async {
    // A new search must never inherit authoritative scores from a previous
    // query set, even when a source path happens to be reused.
    _maximumQueryCache.clear();
    final queries = <ImageLookupQuery>[];
    final failedByPath = <String, ImageLookupResult>{};
    for (var index = 0; index < sources.length; index++) {
      if (cancellation?.isCancelled ?? false) {
        break;
      }
      final source = sources[index];
      if (lookupMode == MediaLookupMode.videoFromFrame &&
          source.mediaType != MediaType.image) {
        failedByPath[source.path] = ImageLookupResult(
          source: source,
          matches: const <ImageLookupMatch>[],
          errorMessage: 'Video-from-frame lookup requires an image query.',
        );
        onProgress?.call(
          ImageLookupProgress.preparingQueries(
            processed: index + 1,
            total: sources.length,
          ),
        );
        continue;
      }
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
      onProgress?.call(
        ImageLookupProgress.preparingQueries(
          processed: index + 1,
          total: sources.length,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    if (cancellation?.isCancelled ?? false) {
      return const ImageLookupBatch(
        results: <ImageLookupResult>[],
        searchedLibraryImages: 0,
      );
    }

    void emitUpdate(ImageLookupUpdate update) {
      if (failedByPath.isEmpty) {
        onUpdate?.call(update);
        return;
      }
      final matchedByPath = <String, ImageLookupResult>{
        for (final result in update.results) result.source.path: result,
      };
      final ordered = <ImageLookupResult>[
        for (final source in sources)
          if (failedByPath[source.path] case final failed?)
            failed
          else if (matchedByPath[source.path] case final matched?)
            matched,
      ];
      onUpdate?.call(
        ImageLookupUpdate(
          progress: update.progress,
          results: List<ImageLookupResult>.unmodifiable(ordered),
          verificationSummary: update.verificationSummary,
        ),
      );
    }

    final matched = await rematchImageQueries(
      queries: queries,
      sensitivity: sensitivity,
      lookupMode: lookupMode,
      lookupPrecision: lookupPrecision,
      cancellation: cancellation,
      onProgress: onProgress,
      onUpdate: emitUpdate,
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
      verificationSummary: matched.verificationSummary,
    );
  }

  @override
  Future<ImageLookupBatch> rematchImageQueries({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    MediaLookupMode lookupMode = MediaLookupMode.mediaMatches,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
    DuplicateScanCancellation? cancellation,
    void Function(ImageLookupProgress progress)? onProgress,
    void Function(ImageLookupUpdate update)? onUpdate,
  }) async {
    if (lookupMode == MediaLookupMode.videoFromFrame) {
      return _rematchVideoFrames(
        queries: queries,
        sensitivity: sensitivity,
        cancellation: cancellation,
        onProgress: onProgress,
        onUpdate: onUpdate,
        lookupPrecision: lookupPrecision,
      );
    }
    final mediaTypes = queries.map((query) => query.source.mediaType).toSet();
    final candidates = await _loadLookupCandidates(mediaTypes);
    final results = <ImageLookupResult>[];
    onProgress?.call(
      ImageLookupProgress(
        stage: ImageLookupProgressStage.searchingIndexedMedia,
        processed: 0,
        total: queries.length,
      ),
    );
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
      onProgress?.call(
        ImageLookupProgress(
          stage: ImageLookupProgressStage.searchingIndexedMedia,
          processed: index + 1,
          total: queries.length,
        ),
      );
      onUpdate?.call(
        ImageLookupUpdate(
          progress: ImageLookupProgress(
            stage: ImageLookupProgressStage.searchingIndexedMedia,
            processed: index + 1,
            total: queries.length,
          ),
          results: List<ImageLookupResult>.unmodifiable(results),
          verificationSummary: const ImageLookupVerificationSummary(),
        ),
      );
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

  Future<ImageLookupBatch> _rematchVideoFrames({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    required VideoFrameLookupPrecision lookupPrecision,
    DuplicateScanCancellation? cancellation,
    void Function(ImageLookupProgress progress)? onProgress,
    void Function(ImageLookupUpdate update)? onUpdate,
  }) async {
    if (lookupPrecision == VideoFrameLookupPrecision.maximum) {
      return _rematchMaximumVideoFrames(
        queries: queries,
        sensitivity: sensitivity,
        cancellation: cancellation,
        onProgress: onProgress,
        onUpdate: onUpdate,
      );
    }
    final videos = await _libraryMedia(const <MediaType>{MediaType.video});
    final cached = await _videoFrameHashDataSource?.getByMediaIds(
      videos.map((video) => video.id),
    );
    final readyVideos = <({MediaEntity video, List<VideoFrameHash> frames})>[
      for (final video in videos)
        if (_hasCurrentVideoFrames(video, cached?[video.id]))
          (video: video, frames: cached![video.id]!),
    ];
    final results = <ImageLookupResult>[];
    onProgress?.call(
      ImageLookupProgress(
        stage: ImageLookupProgressStage.searchingIndexedMedia,
        processed: 0,
        total: queries.length,
      ),
    );
    for (var index = 0; index < queries.length; index++) {
      if (cancellation?.isCancelled ?? false) {
        break;
      }
      final query = queries[index];
      final matches = <ImageLookupMatch>[];
      for (final readyVideo in readyVideos) {
        VideoFrameHash? bestFrame;
        var bestDistance = 65;
        for (final frame in readyVideo.frames) {
          final distance = hammingDistance(query.hash, frame.hash);
          if (distance < bestDistance ||
              (distance == bestDistance &&
                  (bestFrame == null ||
                      frame.timestamp < bestFrame.timestamp))) {
            bestFrame = frame;
            bestDistance = distance;
          }
        }
        if (bestFrame != null && bestDistance <= sensitivity.threshold) {
          matches.add(
            ImageLookupMatch(
              candidate: DuplicateCandidate(
                media: readyVideo.video,
                width: bestFrame.width,
                height: bestFrame.height,
                hash: bestFrame.hash,
              ),
              distance: bestDistance,
              matchedVideoFrame: MatchedVideoFrame(
                positionPercent: bestFrame.positionPercent,
                timestamp: bestFrame.timestamp,
              ),
            ),
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
      onProgress?.call(
        ImageLookupProgress(
          stage: ImageLookupProgressStage.searchingIndexedMedia,
          processed: index + 1,
          total: queries.length,
        ),
      );
      onUpdate?.call(
        ImageLookupUpdate(
          progress: ImageLookupProgress(
            stage: ImageLookupProgressStage.searchingIndexedMedia,
            processed: index + 1,
            total: queries.length,
          ),
          results: List<ImageLookupResult>.unmodifiable(results),
          verificationSummary: ImageLookupVerificationSummary(
            eligibleVideoCount: readyVideos.length,
            verifiedVideoCount: readyVideos.length,
            candidatePolicyVersion: _maximumCandidatePolicyVersion,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }
    return ImageLookupBatch(
      results: List<ImageLookupResult>.unmodifiable(results),
      searchedLibraryImages: readyVideos.length,
    );
  }

  Future<ImageLookupBatch> _rematchMaximumVideoFrames({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    DuplicateScanCancellation? cancellation,
    void Function(ImageLookupProgress progress)? onProgress,
    void Function(ImageLookupUpdate update)? onUpdate,
  }) async {
    final videos = await _libraryMedia(const <MediaType>{MediaType.video});
    final dataSource = _videoMaximumFrameIndexDataSource;
    if (dataSource == null) {
      return ImageLookupBatch(
        results: <ImageLookupResult>[
          for (final query in queries)
            ImageLookupResult(
              source: query.source,
              query: query,
              matches: const <ImageLookupMatch>[],
            ),
        ],
        searchedLibraryImages: 0,
      );
    }
    final statuses = await dataSource.getStatuses(
      videos.map((video) => video.id),
    );
    final readyVideos = <MediaEntity>[];
    for (final video in videos) {
      if (_hasCurrentMaximumVideoIndex(video, statuses[video.id])) {
        readyVideos.add(video);
      }
    }
    final cacheSignature = _maximumIndexSignature(
      videos: videos,
      statuses: statuses,
      generation: dataSource is GenerationAwareVideoMaximumFrameIndexDataSource
          ? (dataSource as GenerationAwareVideoMaximumFrameIndexDataSource)
                .generation
          : null,
    );
    // Check the in-memory signature first. A cold search has no reusable
    // entry, so it should not stat every eligible video merely to discover
    // that fact. Live source validation is required only for a cache hit.
    final cacheCandidate = _readMaximumCache(
      queries: queries,
      sensitivity: sensitivity,
      signature: cacheSignature,
      eligibleVideoCount: readyVideos.length,
    );
    final cached =
        cacheCandidate != null &&
            await _videoSourceSnapshotsMatch(readyVideos) &&
            await _querySourceSnapshotsMatch(queries)
        ? cacheCandidate
        : null;
    if (cached != null) {
      final progress = ImageLookupProgress(
        stage: ImageLookupProgressStage.verifyingVideoFrames,
        processed: readyVideos.length,
        total: readyVideos.length,
      );
      onProgress?.call(progress);
      onUpdate?.call(
        ImageLookupUpdate(
          progress: progress,
          results: cached.results,
          verificationSummary: cached.summary,
        ),
      );
      return ImageLookupBatch(
        results: cached.results,
        searchedLibraryImages: readyVideos.length,
        verificationSummary: cached.summary,
      );
    }
    final queryDescriptors = <NativeCompactImageDescriptor?>[];
    onProgress?.call(
      ImageLookupProgress(
        stage: ImageLookupProgressStage.preparingDescriptors,
        processed: 0,
        total: queries.length,
      ),
    );
    for (var queryIndex = 0; queryIndex < queries.length; queryIndex++) {
      if (cancellation?.isCancelled ?? false) {
        return ImageLookupBatch(
          results: const <ImageLookupResult>[],
          searchedLibraryImages: readyVideos.length,
        );
      }
      queryDescriptors.add(await _queryDescriptor(queries[queryIndex]));
      onProgress?.call(
        ImageLookupProgress(
          stage: ImageLookupProgressStage.preparingDescriptors,
          processed: queryIndex + 1,
          total: queries.length,
        ),
      );
    }

    // Every eligible video is scanned exactly once. Native verification starts
    // with one best window for the first 16 videos, then continues through
    // additional windows for every eligible video in bounded batches.
    final searchShortlists = <_MaximumSearchShortlist>[
      for (var index = 0; index < queries.length; index++)
        _MaximumSearchShortlist(),
    ];
    onProgress?.call(
      ImageLookupProgress(
        stage: ImageLookupProgressStage.scanningVideoFrames,
        processed: 0,
        total: readyVideos.length,
      ),
    );
    final directories = await _loadDirectories();
    var cancelled = false;
    var invalidIndexVideoCount = 0;
    for (var videoIndex = 0; videoIndex < readyVideos.length; videoIndex++) {
      if (cancellation?.isCancelled ?? false) {
        cancelled = true;
        break;
      }
      final video = readyVideos[videoIndex];
      final status = statuses[video.id]!;
      onProgress?.call(
        ImageLookupProgress(
          stage: ImageLookupProgressStage.scanningVideoFrames,
          processed: videoIndex,
          total: readyVideos.length,
          currentItemTotal: status.frameCount,
        ),
      );
      final scan = await _scanMaximumVideo(
        dataSource: dataSource,
        video: video,
        status: status,
        queryDescriptors: queryDescriptors,
        cancellation: cancellation,
        onProgress: (processed) {
          onProgress?.call(
            ImageLookupProgress(
              stage: ImageLookupProgressStage.scanningVideoFrames,
              processed: videoIndex,
              total: readyVideos.length,
              currentItemProcessed: processed,
              currentItemTotal: status.frameCount,
            ),
          );
        },
      );
      if (scan.cancelled) {
        cancelled = true;
        break;
      }
      if (!scan.isValid) {
        // A completion marker without exactly the recorded chunks is stale or
        // corrupt and must never be treated as searchable coverage.
        invalidIndexVideoCount++;
        continue;
      }

      for (var queryIndex = 0; queryIndex < queries.length; queryIndex++) {
        final shortlist = scan.shortlists[queryIndex];
        if (shortlist == null || shortlist.candidates.isEmpty) {
          continue;
        }
        searchShortlists[queryIndex].add(shortlist);
      }
      onProgress?.call(
        ImageLookupProgress(
          stage: ImageLookupProgressStage.scanningVideoFrames,
          processed: videoIndex + 1,
          total: readyVideos.length,
          currentItemProcessed: scan.frameCount,
          currentItemTotal: status.frameCount,
        ),
      );
    }

    if (cancelled) {
      return ImageLookupBatch(
        results: const <ImageLookupResult>[],
        searchedLibraryImages: readyVideos.length,
      );
    }

    final verifiedByQuery = <Map<String, ImageLookupMatch>>[
      for (var index = 0; index < queries.length; index++)
        <String, ImageLookupMatch>{},
    ];

    void mergeVerifiedMatches(
      int queryIndex,
      Map<String, ImageLookupMatch> incoming,
    ) {
      final target = verifiedByQuery[queryIndex];
      for (final entry in incoming.entries) {
        final previous = target[entry.key];
        if (previous == null ||
            _compareVisionMatches(entry.value, previous) < 0) {
          target[entry.key] = entry.value;
        }
      }
    }

    final initialShortlistsByQuery = <List<_MaximumFrameShortlist>>[
      for (var index = 0; index < searchShortlists.length; index++)
        <_MaximumFrameShortlist>[],
    ];
    final remainingShortlistsByQuery = <List<_MaximumFrameShortlist>>[
      for (var index = 0; index < searchShortlists.length; index++)
        <_MaximumFrameShortlist>[],
    ];
    for (
      var queryIndex = 0;
      queryIndex < searchShortlists.length;
      queryIndex++
    ) {
      final ranked = searchShortlists[queryIndex].shortlists;
      for (var rank = 0; rank < ranked.length; rank++) {
        final shortlist = ranked[rank];
        if (rank < _maximumInitialVideoCount) {
          initialShortlistsByQuery[queryIndex].add(
            shortlist.withCandidates(shortlist.candidates.take(1)),
          );
          if (shortlist.candidates.length > 1) {
            remainingShortlistsByQuery[queryIndex].add(
              shortlist.withCandidates(shortlist.candidates.skip(1)),
            );
          }
        } else {
          remainingShortlistsByQuery[queryIndex].add(shortlist);
        }
      }
    }

    List<String> verificationVideoOrder(
      List<List<_MaximumFrameShortlist>> shortlistsByQuery,
    ) {
      final result = <String>[];
      final seen = <String>{};
      final maximumShortlistCount = shortlistsByQuery.fold<int>(
        0,
        (maximum, shortlists) =>
            shortlists.length > maximum ? shortlists.length : maximum,
      );
      for (var rank = 0; rank < maximumShortlistCount; rank++) {
        for (final shortlists in shortlistsByQuery) {
          if (rank >= shortlists.length) {
            continue;
          }
          final videoId = shortlists[rank].video.id;
          if (seen.add(videoId)) {
            result.add(videoId);
          }
        }
      }
      return result;
    }

    final phases =
        <
          ({
            ImageLookupVerificationPhase phase,
            List<List<_MaximumFrameShortlist>> shortlistsByQuery,
            List<String> videoOrder,
          })
        >[
          (
            phase: ImageLookupVerificationPhase.initial,
            shortlistsByQuery: initialShortlistsByQuery,
            videoOrder: verificationVideoOrder(initialShortlistsByQuery),
          ),
          (
            phase: ImageLookupVerificationPhase.remaining,
            shortlistsByQuery: remainingShortlistsByQuery,
            videoOrder: verificationVideoOrder(remainingShortlistsByQuery),
          ),
        ];
    final verifiedVideoIds = <String>{};
    final failedVideoIds = <String>{};

    List<ImageLookupResult> buildVerificationResults() {
      final results = <ImageLookupResult>[];
      for (var index = 0; index < queries.length; index++) {
        final query = queries[index];
        final queryDescriptor = queryDescriptors[index];
        final matches =
            verifiedByQuery[index].values
                .where(
                  (match) =>
                      (match.visionDistance ?? double.infinity) <=
                      sensitivity.visionThreshold,
                )
                .toList(growable: false)
              ..sort(_compareVisionMatches);
        results.add(
          ImageLookupResult(
            source: query.source,
            query: query,
            matches: List<ImageLookupMatch>.unmodifiable(matches),
            errorMessage: queryDescriptor == null
                ? 'The image could not be read or decoded.'
                : null,
          ),
        );
      }
      return results;
    }

    void publishVerificationUpdate({
      required ImageLookupProgress progress,
      required List<ImageLookupResult> results,
    }) {
      onProgress?.call(progress);
      onUpdate?.call(
        ImageLookupUpdate(
          progress: progress,
          results: List<ImageLookupResult>.unmodifiable(results),
          verificationSummary: ImageLookupVerificationSummary(
            eligibleVideoCount: readyVideos.length,
            verifiedVideoCount: verifiedVideoIds.length,
            failedVideoCount: failedVideoIds.length,
            invalidIndexVideoCount: invalidIndexVideoCount,
            candidatePolicyVersion: _maximumCandidatePolicyVersion,
          ),
        ),
      );
    }

    if (phases.every((phase) => phase.videoOrder.isEmpty)) {
      publishVerificationUpdate(
        progress: const ImageLookupProgress(
          stage: ImageLookupProgressStage.verifyingVideoFrames,
          processed: 0,
          total: 0,
          verificationPhase: ImageLookupVerificationPhase.remaining,
        ),
        results: buildVerificationResults(),
      );
    }

    final sessionMatcher = _visionFrameMatcher is SessionVisionFrameMatcher
        ? _visionFrameMatcher as SessionVisionFrameMatcher
        : null;
    final sessionId =
        'lookup-${DateTime.now().microsecondsSinceEpoch}-${queries.length}';
    var sessionStarted = false;
    if (sessionMatcher != null &&
        phases.any((phase) => phase.videoOrder.isNotEmpty) &&
        queryDescriptors.any((descriptor) => descriptor != null)) {
      try {
        await sessionMatcher.startSession(
          sessionId: sessionId,
          queries: [
            for (var index = 0; index < queries.length; index++)
              if (queryDescriptors[index] != null)
                VisionSessionQuery(
                  queryId: _maximumQueryKey(queries[index]),
                  path: queries[index].source.path,
                  bookmarkData: queries[index].source.bookmarkData,
                  sourceFingerprint: _maximumQueryKey(queries[index]),
                ),
          ],
          cancellation: cancellation,
        );
        sessionStarted = true;
      } on VisionFrameMatchingCancelledException {
        cancelled = true;
      } catch (_) {
        // Older native revisions may not support sessions. Fall back to the
        // established per-query matcher while retaining the same candidates.
      }
    }
    try {
      for (final phase in phases) {
        for (
          var batchStart = 0;
          batchStart < phase.videoOrder.length;
          batchStart += _maximumVerificationBatchSize
        ) {
          if (cancellation?.isCancelled ?? false) {
            cancelled = true;
            break;
          }
          final batchEnd = (batchStart + _maximumVerificationBatchSize).clamp(
            0,
            phase.videoOrder.length,
          );
          final batchVideoIds = phase.videoOrder
              .sublist(batchStart, batchEnd)
              .toSet();
          final selectedByQuery = <List<_MaximumFrameShortlist>>[
            for (var index = 0; index < queries.length; index++)
              <_MaximumFrameShortlist>[],
          ];
          for (var index = 0; index < queries.length; index++) {
            final selectedInBatch = phase.shortlistsByQuery[index]
                .where(
                  (shortlist) => batchVideoIds.contains(shortlist.video.id),
                )
                .toList(growable: false);
            if (selectedInBatch.isEmpty || queryDescriptors[index] == null) {
              continue;
            }
            selectedByQuery[index].addAll(selectedInBatch);
          }
          if (sessionMatcher != null && sessionStarted) {
            try {
              final verified = await _verifyMaximumSessionBatch(
                matcher: sessionMatcher,
                sessionId: sessionId,
                requestId: '$sessionId-${phase.phase.name}-$batchStart',
                queries: queries,
                shortlistsByQuery: selectedByQuery,
                directories: directories,
                cancellation: cancellation,
                onPartial: (update, partialMatchesByQuery) {
                  for (
                    var index = 0;
                    index < partialMatchesByQuery.length;
                    index++
                  ) {
                    mergeVerifiedMatches(index, partialMatchesByQuery[index]);
                  }
                  if (update.failureMessage != null) {
                    failedVideoIds.add(update.mediaId);
                    verifiedVideoIds.remove(update.mediaId);
                  } else {
                    if (!failedVideoIds.contains(update.mediaId)) {
                      verifiedVideoIds.add(update.mediaId);
                    }
                  }
                  final processed = (batchStart + update.completedVideoCount)
                      .clamp(0, phase.videoOrder.length);
                  publishVerificationUpdate(
                    progress: ImageLookupProgress(
                      stage: ImageLookupProgressStage.verifyingVideoFrames,
                      processed: processed,
                      total: phase.videoOrder.length,
                      currentItemProcessed: update.completedVideoCount,
                      currentItemTotal: batchVideoIds.length,
                      verificationPhase: phase.phase,
                    ),
                    results: buildVerificationResults(),
                  );
                },
              );
              for (
                var index = 0;
                index < verified.matchesByQuery.length;
                index++
              ) {
                mergeVerifiedMatches(index, verified.matchesByQuery[index]);
              }
              failedVideoIds.addAll(verified.failedVideoIds);
              verifiedVideoIds.removeAll(failedVideoIds);
              verifiedVideoIds.addAll(
                verified.verifiedVideoIds.where(
                  (mediaId) => !failedVideoIds.contains(mediaId),
                ),
              );
            } catch (_) {
              failedVideoIds.addAll(batchVideoIds);
              verifiedVideoIds.removeAll(batchVideoIds);
            }
          } else {
            for (var index = 0; index < queries.length; index++) {
              final selected = selectedByQuery[index];
              if (selected.isEmpty) {
                continue;
              }
              try {
                final verified = await _verifyMaximumShortlists(
                  query: queries[index],
                  shortlists: selected,
                  directories: directories,
                  cancellation: cancellation,
                );
                mergeVerifiedMatches(index, verified);
                verifiedVideoIds.addAll(
                  selected
                      .map((shortlist) => shortlist.video.id)
                      .where((mediaId) => !failedVideoIds.contains(mediaId)),
                );
              } catch (_) {
                final failed = selected.map((shortlist) => shortlist.video.id);
                failedVideoIds.addAll(failed);
                verifiedVideoIds.removeAll(failed);
              }
            }
          }
          if (cancellation?.isCancelled ?? false) {
            cancelled = true;
            break;
          }
          final progress = ImageLookupProgress(
            stage: ImageLookupProgressStage.verifyingVideoFrames,
            processed: batchEnd,
            total: phase.videoOrder.length,
            currentItemProcessed: batchVideoIds.length,
            currentItemTotal: readyVideos.length,
            verificationPhase: phase.phase,
          );
          publishVerificationUpdate(
            progress: progress,
            results: buildVerificationResults(),
          );
          await Future<void>.delayed(Duration.zero);
        }
        if (cancelled) {
          break;
        }
      }
    } finally {
      if (cancellation?.isCancelled ?? false) {
        cancelled = true;
      }
      if (sessionMatcher != null && sessionStarted) {
        try {
          if (cancelled) {
            await sessionMatcher.cancelSession(sessionId);
          } else {
            await sessionMatcher.endSession(sessionId);
          }
        } catch (_) {
          // Session cleanup is best effort after a completed or cancelled batch.
        }
      }
    }

    final results = <ImageLookupResult>[];
    for (var index = 0; index < queries.length; index++) {
      final query = queries[index];
      final queryDescriptor = queryDescriptors[index];
      final matches =
          verifiedByQuery[index].values
              .where(
                (match) =>
                    (match.visionDistance ?? double.infinity) <=
                    sensitivity.visionThreshold,
              )
              .toList(growable: false)
            ..sort(_compareVisionMatches);
      results.add(
        ImageLookupResult(
          source: query.source,
          query: query,
          matches: List<ImageLookupMatch>.unmodifiable(matches),
          errorMessage: queryDescriptor == null
              ? 'The image could not be read or decoded.'
              : null,
        ),
      );
    }
    if (cancelled) {
      return ImageLookupBatch(
        results: List<ImageLookupResult>.unmodifiable(results),
        searchedLibraryImages: readyVideos.length,
        verificationSummary: ImageLookupVerificationSummary(
          eligibleVideoCount: readyVideos.length,
          verifiedVideoCount: verifiedVideoIds.length,
          failedVideoCount: failedVideoIds.length,
          invalidIndexVideoCount: invalidIndexVideoCount,
          stopped: true,
          candidatePolicyVersion: _maximumCandidatePolicyVersion,
        ),
      );
    }
    final summary = ImageLookupVerificationSummary(
      eligibleVideoCount: readyVideos.length,
      verifiedVideoCount: verifiedVideoIds.length,
      failedVideoCount: failedVideoIds.length,
      invalidIndexVideoCount: invalidIndexVideoCount,
      candidatePolicyVersion: _maximumCandidatePolicyVersion,
    );
    for (var index = 0; index < queries.length; index++) {
      if (queryDescriptors[index] == null ||
          failedVideoIds.isNotEmpty ||
          invalidIndexVideoCount != 0) {
        continue;
      }
      _maximumQueryCache[_maximumQueryKey(queries[index])] = _MaximumQueryCache(
        signature: cacheSignature,
        rawMatches: Map<String, ImageLookupMatch>.unmodifiable(
          verifiedByQuery[index],
        ),
        summary: summary,
      );
    }
    return ImageLookupBatch(
      results: List<ImageLookupResult>.unmodifiable(results),
      searchedLibraryImages: readyVideos.length,
      verificationSummary: summary,
    );
  }

  Future<_MaximumVideoScanResult> _scanMaximumVideo({
    required VideoMaximumFrameIndexDataSource dataSource,
    required MediaEntity video,
    required VideoMaximumFrameIndexStatus status,
    required List<NativeCompactImageDescriptor?> queryDescriptors,
    required void Function(int processed) onProgress,
    DuplicateScanCancellation? cancellation,
  }) async {
    final shortlists = <_MaximumFrameShortlist?>[
      for (final queryDescriptor in queryDescriptors)
        queryDescriptor == null ? null : _MaximumFrameShortlist(video: video),
    ];
    var expectedChunkIndex = 0;
    var frameCount = 0;
    var cancelled = false;
    var valid = true;
    MaximumVideoFrameDescriptor? previousDescriptor;
    final shouldMaterialize = List<bool>.filled(queryDescriptors.length, false);

    void consumeDescriptor(MaximumVideoFrameDescriptor descriptor) {
      if (cancelled || !valid) {
        return;
      }
      if (descriptor.mediaId != video.id ||
          descriptor.frameIndex != frameCount) {
        valid = false;
        return;
      }
      for (
        var queryIndex = 0;
        queryIndex < queryDescriptors.length;
        queryIndex++
      ) {
        final queryDescriptor = queryDescriptors[queryIndex];
        final shortlist = shortlists[queryIndex];
        if (queryDescriptor == null || shortlist == null) {
          continue;
        }
        shortlist.updateSuccessor(
          predecessorFrameIndex: descriptor.frameIndex - 1,
          successor: descriptor,
        );
        shortlist.addAllPairings(
          queryDescriptor,
          descriptor,
          predecessor: previousDescriptor,
        );
      }
      previousDescriptor = descriptor;
      frameCount++;
      if (cancellation?.isCancelled ?? false) {
        cancelled = true;
      }
    }

    void consumePackedRecord(
      MaximumVideoFramePackedRecords records,
      int recordIndex,
    ) {
      if (cancelled || !valid) {
        return;
      }
      final frameIndex = records.frameIndexAt(recordIndex);
      if (frameIndex != frameCount) {
        valid = false;
        return;
      }
      final fullFrameHash = records.fullFrameHashAt(recordIndex);
      final centerCropHash = records.centerCropHashAt(recordIndex);
      final timestampMilliseconds = records.timestampMillisecondsAt(
        recordIndex,
      );
      var needsCurrentDescriptor = false;
      var needsPredecessorDescriptor = false;
      for (
        var queryIndex = 0;
        queryIndex < queryDescriptors.length;
        queryIndex++
      ) {
        final query = queryDescriptors[queryIndex];
        final shortlist = shortlists[queryIndex];
        if (query == null || shortlist == null) {
          shouldMaterialize[queryIndex] = false;
          continue;
        }
        final fullFullDistance = hammingDistance(
          query.fullFrameHash,
          fullFrameHash,
        );
        final centerCenterDistance = hammingDistance(
          query.centerCropHash,
          centerCropHash,
        );
        final fullCenterDistance = hammingDistance(
          query.fullFrameHash,
          centerCropHash,
        );
        final centerFullDistance = hammingDistance(
          query.centerCropHash,
          fullFrameHash,
        );
        var bestDistance = fullFullDistance;
        if (centerCenterDistance < bestDistance) {
          bestDistance = centerCenterDistance;
        }
        if (fullCenterDistance < bestDistance) {
          bestDistance = fullCenterDistance;
        }
        if (centerFullDistance < bestDistance) {
          bestDistance = centerFullDistance;
        }
        final shouldAdd = shortlist.shouldConsiderPacked(
          timestampMilliseconds: timestampMilliseconds,
          legacyDistance: fullFullDistance < centerCenterDistance
              ? fullFullDistance
              : centerCenterDistance,
          bestDistance: bestDistance,
        );
        shouldMaterialize[queryIndex] = shouldAdd;
        needsCurrentDescriptor =
            needsCurrentDescriptor ||
            shouldAdd ||
            shortlist.hasCandidateFrameIndex(frameIndex - 1);
        needsPredecessorDescriptor = needsPredecessorDescriptor || shouldAdd;
      }
      if (needsCurrentDescriptor) {
        final descriptor = records.descriptorAt(recordIndex);
        final predecessor = needsPredecessorDescriptor
            ? recordIndex > 0
                  ? records.descriptorAt(recordIndex - 1)
                  : previousDescriptor
            : null;
        for (
          var queryIndex = 0;
          queryIndex < queryDescriptors.length;
          queryIndex++
        ) {
          final shortlist = shortlists[queryIndex];
          if (shortlist == null) {
            continue;
          }
          shortlist.updateSuccessor(
            predecessorFrameIndex: frameIndex - 1,
            successor: descriptor,
          );
          if (shouldMaterialize[queryIndex]) {
            final query = queryDescriptors[queryIndex];
            if (query != null) {
              shortlist.addAllPairings(
                query,
                descriptor,
                predecessor: predecessor,
              );
            }
          }
        }
      }
      frameCount++;
      if (cancellation?.isCancelled ?? false) {
        cancelled = true;
      }
    }

    void consumeChunk({
      required String mediaId,
      required int chunkIndex,
      required String fingerprint,
      required void Function() consumeRecords,
    }) {
      if (cancelled || !valid) {
        return;
      }
      if (mediaId != video.id ||
          chunkIndex != expectedChunkIndex ||
          fingerprint != status.fingerprint) {
        valid = false;
        return;
      }
      expectedChunkIndex++;
      consumeRecords();
      if (expectedChunkIndex % _emitEvery == 0 ||
          frameCount >= status.frameCount) {
        onProgress(frameCount);
      }
    }

    final packed = dataSource is PackedVideoMaximumFrameIndexDataSource
        ? dataSource as PackedVideoMaximumFrameIndexDataSource
        : null;
    try {
      if (packed != null) {
        await for (final chunk in packed.streamEncodedChunks(video.id)) {
          if (cancellation?.isCancelled ?? false) {
            cancelled = true;
            break;
          }
          try {
            consumeChunk(
              mediaId: chunk.mediaId,
              chunkIndex: chunk.chunkIndex,
              fingerprint: chunk.fingerprint,
              consumeRecords: () {
                final records = const MaximumVideoFrameDescriptorCodec()
                    .readPacked(
                      mediaId: chunk.mediaId,
                      bytes: chunk.descriptorBytes,
                    );
                for (var index = 0; index < records.count; index++) {
                  consumePackedRecord(records, index);
                  if (!valid || cancelled) {
                    break;
                  }
                }
                if (records.count > 0 && valid && !cancelled) {
                  // Retain one boundary descriptor so a candidate at record
                  // zero of the next chunk still receives its true temporal
                  // predecessor without materializing every record.
                  previousDescriptor = records.descriptorAt(records.count - 1);
                }
              },
            );
          } on FormatException {
            valid = false;
          }
          if (!valid || cancelled) {
            break;
          }
        }
      } else {
        await for (final chunk in dataSource.streamChunks(video.id)) {
          if (cancellation?.isCancelled ?? false) {
            cancelled = true;
            break;
          }
          consumeChunk(
            mediaId: chunk.mediaId,
            chunkIndex: chunk.chunkIndex,
            fingerprint: chunk.fingerprint,
            consumeRecords: () {
              for (final descriptor in chunk.descriptors) {
                consumeDescriptor(descriptor);
                if (!valid || cancelled) {
                  break;
                }
              }
            },
          );
          if (!valid || cancelled) {
            break;
          }
        }
      }
    } catch (_) {
      valid = false;
    }
    if (cancellation?.isCancelled ?? false) {
      cancelled = true;
    }
    valid =
        valid &&
        expectedChunkIndex == status.chunkCount &&
        frameCount == status.frameCount;
    return _MaximumVideoScanResult(
      shortlists: shortlists,
      frameCount: frameCount,
      isValid: valid,
      cancelled: cancelled,
    );
  }

  String _maximumQueryKey(ImageLookupQuery query) {
    final source = query.source;
    return '${source.path}|${source.size}|'
        '${source.lastModified.microsecondsSinceEpoch}|'
        '${source.mediaType.name}|${source.bookmarkData ?? '-'}|'
        '${query.hash}|${query.width}x${query.height}';
  }

  String _maximumVideoSourceFingerprint(MediaEntity video) {
    return '${video.id}|${video.path}|${video.size}|'
        '${video.lastModified.microsecondsSinceEpoch}';
  }

  String _maximumIndexSignature({
    required List<MediaEntity> videos,
    required Map<String, VideoMaximumFrameIndexStatus> statuses,
    required int? generation,
  }) {
    final entries = <String>[
      'policy=$_maximumCandidatePolicyVersion',
      'generation=${generation ?? -1}',
      for (final video in videos)
        '${video.id}:${video.path}:${video.size}:'
            '${video.lastModified.microsecondsSinceEpoch}:'
            '${statuses[video.id]?.fingerprint ?? '-'}:'
            '${statuses[video.id]?.computedAt.microsecondsSinceEpoch ?? -1}:'
            '${statuses[video.id]?.frameCount ?? -1}:'
            '${statuses[video.id]?.chunkCount ?? -1}:'
            '${statuses[video.id]?.state.name ?? '-'}:'
            '${statuses[video.id]?.sourceSize ?? -1}:'
            '${statuses[video.id]?.sourceLastModified.microsecondsSinceEpoch ?? -1}:'
            '${statuses[video.id]?.descriptorVersion ?? -1}:'
            '${statuses[video.id]?.visionRevision ?? -1}',
    ]..sort();
    return entries.join('|');
  }

  _CachedMaximumResults? _readMaximumCache({
    required List<ImageLookupQuery> queries,
    required DuplicateSensitivity sensitivity,
    required String signature,
    required int eligibleVideoCount,
  }) {
    if (queries.isEmpty) {
      return const _CachedMaximumResults(
        results: <ImageLookupResult>[],
        summary: ImageLookupVerificationSummary(),
      );
    }
    final entries = <_MaximumQueryCache>[];
    for (final query in queries) {
      final entry = _maximumQueryCache[_maximumQueryKey(query)];
      if (entry == null ||
          entry.signature != signature ||
          entry.summary.stopped ||
          entry.summary.failedVideoCount != 0 ||
          entry.summary.invalidIndexVideoCount != 0) {
        return null;
      }
      entries.add(entry);
    }
    final results = <ImageLookupResult>[];
    for (var index = 0; index < queries.length; index++) {
      final query = queries[index];
      final matches =
          entries[index].rawMatches.values
              .where(
                (match) =>
                    (match.visionDistance ?? double.infinity) <=
                    sensitivity.visionThreshold,
              )
              .toList(growable: false)
            ..sort(_compareVisionMatches);
      results.add(
        ImageLookupResult(
          source: query.source,
          query: query,
          matches: List<ImageLookupMatch>.unmodifiable(matches),
        ),
      );
    }
    final summary = entries.first.summary.copyWith(
      eligibleVideoCount: eligibleVideoCount,
    );
    return _CachedMaximumResults(
      results: List<ImageLookupResult>.unmodifiable(results),
      summary: summary,
    );
  }

  Future<NativeCompactImageDescriptor?> _queryDescriptor(
    ImageLookupQuery query,
  ) async {
    final generator = _compactDescriptorGenerator;
    if (generator == null) {
      // This fallback keeps the model usable in pure-Dart tests. Production
      // macOS providers always inject the native descriptor generator.
      return NativeCompactImageDescriptor(
        fullFrameHash: query.hash,
        centerCropHash: query.hash,
        width: query.width,
        height: query.height,
      );
    }
    return generator.generate(
      path: query.source.path,
      bookmarkData: query.source.bookmarkData,
    );
  }

  /// Avoids reusing Vision scores when a query file changed after selection.
  ///
  /// Query paths restored from a security-scoped history entry may not be
  /// stat-able until native code reopens their bookmark. In that case cache
  /// reuse is rejected until the source can be validated again.
  Future<bool> _videoSourceSnapshotsMatch(List<MediaEntity> videos) async {
    final validator = _videoSourceSnapshotValidator;
    if (validator != null) {
      return validator(videos);
    }
    for (final video in videos) {
      try {
        final stat = await File(video.path).stat();
        if (stat.type != FileSystemEntityType.file ||
            stat.size != video.size ||
            !stat.modified.isAtSameMomentAs(video.lastModified)) {
          return false;
        }
      } on FileSystemException {
        return false;
      }
    }
    return true;
  }

  /// Query paths restored from a security-scoped history entry may not be
  /// stat-able until native code reopens their bookmark. In that case cache
  /// reuse is rejected until the source can be validated again.
  Future<bool> _querySourceSnapshotsMatch(
    List<ImageLookupQuery> queries,
  ) async {
    for (final query in queries) {
      try {
        final stat = await File(query.source.path).stat();
        if (stat.type != FileSystemEntityType.file) {
          return false;
        }
        if (stat.size != query.source.size ||
            !stat.modified.isAtSameMomentAs(query.source.lastModified)) {
          return false;
        }
      } on FileSystemException {
        // A missing or inaccessible query cannot be proven unchanged.
        return false;
      }
    }
    return true;
  }

  Future<Map<String, ImageLookupMatch>> _verifyMaximumShortlists({
    required ImageLookupQuery query,
    required List<_MaximumFrameShortlist> shortlists,
    required List<DirectoryEntity> directories,
    DuplicateScanCancellation? cancellation,
  }) async {
    final matcher = _visionFrameMatcher;
    if (matcher == null || shortlists.isEmpty) {
      return const <String, ImageLookupMatch>{};
    }
    final requests = <VisionFrameCandidateRequest>[];
    for (final shortlist in shortlists) {
      for (final candidate in shortlist.candidates) {
        if (cancellation?.isCancelled ?? false) {
          return const <String, ImageLookupMatch>{};
        }
        requests.add(
          VisionFrameCandidateRequest(
            mediaId: shortlist.video.id,
            path: shortlist.video.path,
            timestamp: candidate.descriptor.timestamp,
            queryId: _maximumQueryKey(query),
            sourceFingerprint: _maximumQueryKey(query),
            verificationTimestamps: candidate.verificationTimestamps,
            presentationTime: candidate.descriptor.presentationTime,
            verificationPresentationTimes:
                candidate.verificationPresentationTimes,
            bookmarkData:
                resolveBookmarkForPath(shortlist.video.path, directories) ??
                shortlist.video.bookmarkData,
          ),
        );
      }
    }
    final nativeMatches = await _runVisionMatch(
      matcher: matcher,
      query: query,
      candidates: requests,
      cancellation: cancellation,
    );
    final matches = <String, ImageLookupMatch>{};
    for (final nativeMatch in nativeMatches) {
      // Keep the raw Vision score. Sensitivity is applied only when building
      // the result snapshot so rematching a completed search never rescans
      // the index or invokes Vision again.
      MediaEntity? video;
      _MaximumFrameShortlist? matchingShortlist;
      for (final shortlist in shortlists) {
        if (shortlist.video.id == nativeMatch.mediaId) {
          video = shortlist.video;
          matchingShortlist = shortlist;
          break;
        }
      }
      if (video == null) {
        continue;
      }
      final candidate = _closestDescriptor(
        matchingShortlist!.verificationDescriptors,
        nativeMatch.timestamp,
        presentationTime: nativeMatch.presentationTime,
      );
      if (candidate == null) {
        continue;
      }
      final imageMatch = ImageLookupMatch(
        candidate: DuplicateCandidate(
          media: video,
          width: candidate.width,
          height: candidate.height,
          hash: candidate.fullFrameHash,
        ),
        distance: _compactDistanceFromQuery(candidate, query),
        visionDistance: nativeMatch.distance,
        matchedVideoFrame: MatchedVideoFrame(
          positionPercent: nativeMatch.positionPercent,
          timestamp: nativeMatch.timestamp,
          presentationTime: nativeMatch.presentationTime,
        ),
      );
      final previous = matches[video.id];
      if (previous == null || _compareVisionMatches(imageMatch, previous) < 0) {
        matches[video.id] = imageMatch;
      }
    }
    return matches;
  }

  Future<_MaximumSessionVerificationBatch> _verifyMaximumSessionBatch({
    required SessionVisionFrameMatcher matcher,
    required String sessionId,
    required String requestId,
    required List<ImageLookupQuery> queries,
    required List<List<_MaximumFrameShortlist>> shortlistsByQuery,
    required List<DirectoryEntity> directories,
    DuplicateScanCancellation? cancellation,
    void Function(
      VisionSessionBatchUpdate update,
      List<Map<String, ImageLookupMatch>> partial,
    )?
    onPartial,
  }) async {
    final requests = <VisionFrameCandidateRequest>[];
    for (var queryIndex = 0; queryIndex < queries.length; queryIndex++) {
      final query = queries[queryIndex];
      for (final shortlist in shortlistsByQuery[queryIndex]) {
        for (final candidate in shortlist.candidates) {
          requests.add(
            VisionFrameCandidateRequest(
              mediaId: shortlist.video.id,
              path: shortlist.video.path,
              timestamp: candidate.descriptor.timestamp,
              queryId: _maximumQueryKey(query),
              sourceFingerprint: _maximumVideoSourceFingerprint(
                shortlist.video,
              ),
              verificationTimestamps: candidate.verificationTimestamps,
              presentationTime: candidate.descriptor.presentationTime,
              verificationPresentationTimes:
                  candidate.verificationPresentationTimes,
              bookmarkData:
                  resolveBookmarkForPath(shortlist.video.path, directories) ??
                  shortlist.video.bookmarkData,
            ),
          );
        }
      }
    }
    final matchesByQuery = <Map<String, ImageLookupMatch>>[
      for (var index = 0; index < queries.length; index++)
        <String, ImageLookupMatch>{},
    ];
    final queryIndexes = <String, int>{
      for (var index = 0; index < queries.length; index++)
        _maximumQueryKey(queries[index]): index,
    };
    void mergeMatches(Iterable<VisionFrameMatch> nativeMatches) {
      for (final nativeMatch in nativeMatches) {
        final queryIndex = queryIndexes[nativeMatch.queryId];
        if (queryIndex == null) {
          continue;
        }
        final shortlists = shortlistsByQuery[queryIndex];
        _MaximumFrameShortlist? matchingShortlist;
        for (final shortlist in shortlists) {
          if (shortlist.video.id == nativeMatch.mediaId) {
            matchingShortlist = shortlist;
            break;
          }
        }
        if (matchingShortlist == null) {
          continue;
        }
        final candidate = _closestDescriptor(
          matchingShortlist.verificationDescriptors,
          nativeMatch.timestamp,
          presentationTime: nativeMatch.presentationTime,
        );
        if (candidate == null) {
          continue;
        }
        final query = queries[queryIndex];
        final imageMatch = ImageLookupMatch(
          candidate: DuplicateCandidate(
            media: matchingShortlist.video,
            width: candidate.width,
            height: candidate.height,
            hash: candidate.fullFrameHash,
          ),
          distance: _compactDistanceFromQuery(candidate, query),
          visionDistance: nativeMatch.distance,
          matchedVideoFrame: MatchedVideoFrame(
            positionPercent: nativeMatch.positionPercent,
            timestamp: nativeMatch.timestamp,
            presentationTime: nativeMatch.presentationTime,
          ),
        );
        final previous = matchesByQuery[queryIndex][nativeMatch.mediaId];
        if (previous == null ||
            _compareVisionMatches(imageMatch, previous) < 0) {
          matchesByQuery[queryIndex][nativeMatch.mediaId] = imageMatch;
        }
      }
    }

    final result = await matcher.verifyBatch(
      sessionId: sessionId,
      requestId: requestId,
      candidates: requests,
      cancellation: cancellation,
      onUpdate: (update) {
        mergeMatches(update.matches);
        onPartial?.call(update, [
          for (final matches in matchesByQuery)
            Map<String, ImageLookupMatch>.unmodifiable(matches),
        ]);
      },
    );
    mergeMatches(result.matches);
    final failedVideoIds = result.failures
        .map((failure) => failure.mediaId)
        .toSet();
    final verifiedVideoIds = requests
        .map((candidate) => candidate.mediaId)
        .where((mediaId) => !failedVideoIds.contains(mediaId))
        .toSet();
    return _MaximumSessionVerificationBatch(
      matchesByQuery: matchesByQuery,
      failedVideoIds: failedVideoIds,
      verifiedVideoIds: verifiedVideoIds,
    );
  }

  Future<List<VisionFrameMatch>> _runVisionMatch({
    required VisionFrameMatcher matcher,
    required ImageLookupQuery query,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) async {
    final cancellable = matcher is CancellableVisionFrameMatcher
        ? matcher
        : null;
    final requestId =
        'vision-${DateTime.now().microsecondsSinceEpoch}-${query.source.path}';
    var completed = false;
    try {
      final matches = cancellable == null
          ? await matcher.match(
              queryPath: query.source.path,
              queryBookmarkData: query.source.bookmarkData,
              candidates: candidates,
              cancellation: cancellation,
            )
          : await cancellable.matchCancellable(
              requestId: requestId,
              queryPath: query.source.path,
              queryBookmarkData: query.source.bookmarkData,
              candidates: candidates,
              cancellation: cancellation,
            );
      if (cancellation?.isCancelled ?? false) {
        return const <VisionFrameMatch>[];
      }
      completed = true;
      return matches;
    } on VisionFrameMatchingCancelledException {
      return const <VisionFrameMatch>[];
    } finally {
      if (cancellable != null && !completed) {
        try {
          await cancellable.cancel(requestId);
        } catch (_) {
          // Native cleanup is best effort when the platform channel is gone.
        }
      }
    }
  }

  int _compareVisionMatches(ImageLookupMatch first, ImageLookupMatch second) {
    final firstVision = first.visionDistance ?? double.infinity;
    final secondVision = second.visionDistance ?? double.infinity;
    final byVision = firstVision.compareTo(secondVision);
    if (byVision != 0) {
      return byVision;
    }
    final byPath = first.candidate.media.path.compareTo(
      second.candidate.media.path,
    );
    if (byPath != 0) {
      return byPath;
    }
    final byPresentationTime = _comparePresentationTimes(
      first.matchedVideoFrame?.presentationTime,
      second.matchedVideoFrame?.presentationTime,
    );
    if (byPresentationTime != 0) {
      return byPresentationTime;
    }
    final firstTimestamp = first.matchedVideoFrame?.timestamp;
    final secondTimestamp = second.matchedVideoFrame?.timestamp;
    if (firstTimestamp != null && secondTimestamp != null) {
      final byTimestamp = firstTimestamp.compareTo(secondTimestamp);
      if (byTimestamp != 0) {
        return byTimestamp;
      }
    } else if (firstTimestamp != null) {
      return -1;
    } else if (secondTimestamp != null) {
      return 1;
    }
    return 0;
  }

  int _comparePresentationTimes(
    VideoFramePresentationTime? first,
    VideoFramePresentationTime? second,
  ) {
    if (first == null && second == null) {
      return 0;
    }
    if (first == null) {
      return 1;
    }
    if (second == null) {
      return -1;
    }
    final left = BigInt.from(first.value) * BigInt.from(second.timescale);
    final right = BigInt.from(second.value) * BigInt.from(first.timescale);
    return left.compareTo(right);
  }

  int _compactDistanceFromQuery(
    MaximumVideoFrameDescriptor descriptor,
    ImageLookupQuery query,
  ) {
    final full = hammingDistance(query.hash, descriptor.fullFrameHash);
    final center = hammingDistance(query.hash, descriptor.centerCropHash);
    return full < center ? full : center;
  }

  MaximumVideoFrameDescriptor? _closestDescriptor(
    List<MaximumVideoFrameDescriptor> descriptors,
    Duration timestamp, {
    VideoFramePresentationTime? presentationTime,
  }) {
    if (descriptors.isEmpty) {
      return null;
    }
    if (presentationTime != null) {
      for (final descriptor in descriptors) {
        if (descriptor.presentationTime == presentationTime) {
          return descriptor;
        }
      }
    }
    return descriptors.reduce(
      (first, second) =>
          (first.timestamp - timestamp).abs() <=
              (second.timestamp - timestamp).abs()
          ? first
          : second,
    );
  }

  bool _hasCurrentVideoFrames(MediaEntity video, List<VideoFrameHash>? frames) {
    if (frames == null || frames.length != videoFrameSamplePercents.length) {
      return false;
    }
    final expectedFingerprint = videoFrameLookupFingerprint(
      size: video.size,
      lastModified: video.lastModified,
    );
    return frames.every((frame) => frame.fingerprint == expectedFingerprint) &&
        frames
            .map((frame) => frame.positionPercent)
            .toSet()
            .containsAll(videoFrameSamplePercents);
  }

  bool _hasCurrentMaximumVideoIndex(
    MediaEntity video,
    VideoMaximumFrameIndexStatus? status,
  ) {
    if (status == null || !status.isComplete) {
      return false;
    }
    return status.fingerprint ==
            maximumVideoFrameLookupFingerprint(
              size: video.size,
              lastModified: video.lastModified,
              descriptorVersion: maximumVideoFrameDescriptorVersion,
              visionRevision: maximumVideoFrameVisionRevision,
            ) &&
        status.sourceSize == video.size &&
        status.sourceLastModified.isAtSameMomentAs(video.lastModified) &&
        status.descriptorVersion == maximumVideoFrameDescriptorVersion &&
        status.visionRevision == maximumVideoFrameVisionRevision &&
        status.frameCount > 0 &&
        status.chunkCount > 0;
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

  Future<void> _flushVideoFrames(
    Map<String, List<VideoFrameHash>> pending,
  ) async {
    if (pending.isEmpty) {
      return;
    }
    final dataSource = _videoFrameHashDataSource;
    if (dataSource != null) {
      await dataSource.replaceAll(
        Map<String, List<VideoFrameHash>>.from(pending),
      );
    }
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

class _MaximumIndexEvent {
  const _MaximumIndexEvent.progress(this.frameCount)
    : isComplete = false,
      succeeded = false,
      totalFrameCount = 0;

  const _MaximumIndexEvent.complete(this.frameCount)
    : isComplete = true,
      succeeded = true,
      totalFrameCount = 0;

  const _MaximumIndexEvent.failure()
    : frameCount = 0,
      isComplete = true,
      succeeded = false,
      totalFrameCount = 0;

  final int frameCount;
  final int totalFrameCount;
  final bool isComplete;
  final bool succeeded;
}

/// Keeps the shortlist bounded and avoids repeatedly verifying adjacent frames
/// from the same temporal neighborhood.
class _MaximumFrameShortlist {
  _MaximumFrameShortlist({
    required this.video,
    List<_MaximumFrameCandidate>? candidates,
    _MaximumFrameCandidate? legacyCandidate,
  }) : _candidates = candidates == null
           ? <_MaximumFrameCandidate>[]
           : List<_MaximumFrameCandidate>.from(candidates),
       _legacyCandidate = legacyCandidate;

  static const int maximumCandidates = 4;
  static const int _minimumSeparationMilliseconds = 250;

  final MediaEntity video;
  final List<_MaximumFrameCandidate> _candidates;
  _MaximumFrameCandidate? _legacyCandidate;

  int get bestDistance => _candidates.isEmpty ? 64 : _candidates.first.distance;

  List<_MaximumFrameCandidate> get candidates =>
      List<_MaximumFrameCandidate>.unmodifiable(_candidates);

  _MaximumFrameShortlist withCandidates(
    Iterable<_MaximumFrameCandidate> candidates,
  ) {
    final selected = candidates.toList(growable: false);
    return _MaximumFrameShortlist(
      video: video,
      candidates: selected,
      legacyCandidate: selected.contains(_legacyCandidate)
          ? _legacyCandidate
          : null,
    );
  }

  bool hasCandidateFrameIndex(int frameIndex) {
    return _candidates.any(
      (candidate) => candidate.descriptor.frameIndex == frameIndex,
    );
  }

  bool shouldConsiderPacked({
    required int timestampMilliseconds,
    required int legacyDistance,
    required int bestDistance,
  }) {
    if (_candidates.length < maximumCandidates) {
      return true;
    }
    final currentLegacyDistance = _legacyCandidate?.distance ?? 64;
    if (legacyDistance < currentLegacyDistance) {
      return true;
    }
    for (final candidate in _candidates) {
      if ((candidate.descriptor.timestamp.inMilliseconds -
                  timestampMilliseconds)
              .abs() <
          _minimumSeparationMilliseconds) {
        return true;
      }
    }
    return bestDistance < _candidates.last.distance;
  }

  List<MaximumVideoFrameDescriptor> get verificationDescriptors => [
    for (final candidate in candidates) ...candidate.verificationDescriptors,
  ];

  void updateSuccessor({
    required int predecessorFrameIndex,
    required MaximumVideoFrameDescriptor successor,
  }) {
    for (final candidate in _candidates) {
      if (candidate.descriptor.frameIndex == predecessorFrameIndex) {
        candidate.successor = successor;
      }
    }
  }

  void addAllPairings(
    NativeCompactImageDescriptor query,
    MaximumVideoFrameDescriptor descriptor, {
    MaximumVideoFrameDescriptor? predecessor,
  }) {
    final pairings = <int>[
      hammingDistance(query.fullFrameHash, descriptor.fullFrameHash),
      hammingDistance(query.centerCropHash, descriptor.centerCropHash),
      hammingDistance(query.fullFrameHash, descriptor.centerCropHash),
      hammingDistance(query.centerCropHash, descriptor.fullFrameHash),
    ];
    // Pairings 0 and 1 are the original maximum-precision selection policy.
    // Keep its best window pinned while the three additional windows are
    // filled from all four pairings below.
    _considerLegacyCandidate(
      descriptor,
      pairings[0],
      pairing: 0,
      predecessor: predecessor,
    );
    _considerLegacyCandidate(
      descriptor,
      pairings[1],
      pairing: 1,
      predecessor: predecessor,
    );
    for (var pairing = 0; pairing < pairings.length; pairing++) {
      _add(
        descriptor,
        pairings[pairing],
        pairing: pairing,
        predecessor: predecessor,
      );
    }
  }

  void _considerLegacyCandidate(
    MaximumVideoFrameDescriptor descriptor,
    int distance, {
    required int pairing,
    required MaximumVideoFrameDescriptor? predecessor,
  }) {
    final improvesLegacy =
        _legacyCandidate == null || distance < _legacyCandidate!.distance;
    if (!improvesLegacy) {
      // Extra-window maintenance, including cross-pairing replacements, is
      // handled by [_add]. This path must not evict a better existing window.
      return;
    }
    _candidates.removeWhere(
      (entry) =>
          (entry.descriptor.timestamp - descriptor.timestamp)
              .abs()
              .inMilliseconds <
          _minimumSeparationMilliseconds,
    );
    final candidate = _MaximumFrameCandidate(
      descriptor: descriptor,
      distance: distance,
      pairing: pairing,
      predecessor: predecessor,
    );
    _candidates.add(candidate);
    _legacyCandidate = candidate;
    _trimCandidates();
  }

  void _add(
    MaximumVideoFrameDescriptor descriptor,
    int distance, {
    required int pairing,
    MaximumVideoFrameDescriptor? predecessor,
  }) {
    for (var index = 0; index < _candidates.length; index++) {
      final entry = _candidates[index];
      if ((entry.descriptor.timestamp - descriptor.timestamp)
              .abs()
              .inMilliseconds <
          _minimumSeparationMilliseconds) {
        if (identical(entry, _legacyCandidate)) {
          return;
        }
        if (distance < entry.distance) {
          _candidates[index] = _MaximumFrameCandidate(
            descriptor: descriptor,
            distance: distance,
            pairing: pairing,
            predecessor: predecessor,
          );
          break;
        }
        return;
      }
    }
    if (!_candidates.any(
      (entry) => entry.descriptor.frameIndex == descriptor.frameIndex,
    )) {
      _candidates.add(
        _MaximumFrameCandidate(
          descriptor: descriptor,
          distance: distance,
          pairing: pairing,
          predecessor: predecessor,
        ),
      );
    }
    _candidates.sort(_compareCandidates);
    _trimCandidates();
  }

  void _trimCandidates() {
    _candidates.sort(_compareCandidates);
    while (_candidates.length > maximumCandidates) {
      final removableIndex = _candidates.lastIndexWhere(
        (candidate) => !identical(candidate, _legacyCandidate),
      );
      if (removableIndex < 0) {
        break;
      }
      _candidates.removeAt(removableIndex);
    }
  }

  int _compareCandidates(
    _MaximumFrameCandidate first,
    _MaximumFrameCandidate second,
  ) {
    if (identical(first, _legacyCandidate)) {
      return identical(second, _legacyCandidate) ? 0 : -1;
    }
    if (identical(second, _legacyCandidate)) {
      return 1;
    }
    final byDistance = first.distance.compareTo(second.distance);
    if (byDistance != 0) {
      return byDistance;
    }
    return first.descriptor.timestamp.compareTo(second.descriptor.timestamp);
  }
}

/// Retains every valid video's bounded candidate windows for one query.
///
/// Candidate selection is deliberately independent of sensitivity. Vision is
/// the only authoritative acceptance filter, so changing sensitivity cannot
/// make a valid coarse candidate disappear before verification.
class _MaximumSearchShortlist {
  final List<_MaximumFrameShortlist> _shortlists = <_MaximumFrameShortlist>[];

  List<_MaximumFrameShortlist> get shortlists {
    final result = List<_MaximumFrameShortlist>.from(_shortlists)
      ..sort(_compareShortlists);
    return List<_MaximumFrameShortlist>.unmodifiable(result);
  }

  void add(_MaximumFrameShortlist shortlist) {
    if (shortlist.candidates.isEmpty) {
      return;
    }
    _shortlists.add(shortlist);
  }

  int _compareShortlists(
    _MaximumFrameShortlist first,
    _MaximumFrameShortlist second,
  ) {
    final byDistance = first.bestDistance.compareTo(second.bestDistance);
    if (byDistance != 0) {
      return byDistance;
    }
    return first.video.path.compareTo(second.video.path);
  }
}

class _MaximumFrameCandidate {
  _MaximumFrameCandidate({
    required this.descriptor,
    required this.distance,
    required this.pairing,
    this.predecessor,
  });

  final MaximumVideoFrameDescriptor descriptor;
  final int distance;
  final int pairing;
  final MaximumVideoFrameDescriptor? predecessor;
  MaximumVideoFrameDescriptor? successor;

  List<MaximumVideoFrameDescriptor> get verificationDescriptors {
    final result = <MaximumVideoFrameDescriptor>[];
    if (predecessor != null) {
      result.add(predecessor!);
    }
    result.add(descriptor);
    if (successor != null) {
      result.add(successor!);
    }
    final seen = <int>{};
    return result
        .where((value) => seen.add(value.frameIndex))
        .toList(growable: false);
  }

  List<Duration> get verificationTimestamps => verificationDescriptors
      .map((descriptor) => descriptor.timestamp)
      .toList(growable: false);

  List<VideoFramePresentationTime> get verificationPresentationTimes =>
      verificationDescriptors
          .map((descriptor) => descriptor.presentationTime)
          .whereType<VideoFramePresentationTime>()
          .toList(growable: false);
}

final class _MaximumQueryCache {
  const _MaximumQueryCache({
    required this.signature,
    required this.rawMatches,
    required this.summary,
  });

  final String signature;
  final Map<String, ImageLookupMatch> rawMatches;
  final ImageLookupVerificationSummary summary;
}

final class _CachedMaximumResults {
  const _CachedMaximumResults({required this.results, required this.summary});

  final List<ImageLookupResult> results;
  final ImageLookupVerificationSummary summary;
}

final class _MaximumVideoScanResult {
  const _MaximumVideoScanResult({
    required this.shortlists,
    required this.frameCount,
    required this.isValid,
    required this.cancelled,
  });

  final List<_MaximumFrameShortlist?> shortlists;
  final int frameCount;
  final bool isValid;
  final bool cancelled;
}

final class _MaximumSessionVerificationBatch {
  const _MaximumSessionVerificationBatch({
    required this.matchesByQuery,
    required this.failedVideoIds,
    required this.verifiedVideoIds,
  });

  final List<Map<String, ImageLookupMatch>> matchesByQuery;
  final Set<String> failedVideoIds;
  final Set<String> verifiedVideoIds;
}

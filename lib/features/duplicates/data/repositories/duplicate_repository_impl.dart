import '../../../media_library/domain/entities/media_entity.dart';
import '../../../media_library/domain/repositories/media_repository.dart';
import '../../domain/entities/duplicate_candidate.dart';
import '../../domain/entities/duplicate_group.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/duplicate_sensitivity.dart';
import '../../domain/entities/keeper_strategy.dart';
import '../../domain/entities/perceptual_hash.dart';
import '../../domain/repositories/duplicate_repository.dart';
import '../data_sources/dismissed_group_data_source.dart';
import '../data_sources/perceptual_hash_data_source.dart';
import '../services/duplicate_clusterer.dart';
import '../services/perceptual_hasher.dart';

class DuplicateRepositoryImpl implements DuplicateRepository {
  DuplicateRepositoryImpl({
    required MediaRepository mediaRepository,
    required PerceptualHashDataSource hashDataSource,
    required DismissedGroupDataSource dismissedDataSource,
    PerceptualHasher hasher = const PerceptualHasher(),
    DuplicateClusterer clusterer = const DuplicateClusterer(),
  }) : _mediaRepository = mediaRepository,
       _hashDataSource = hashDataSource,
       _dismissedDataSource = dismissedDataSource,
       _hasher = hasher,
       _clusterer = clusterer;

  final MediaRepository _mediaRepository;
  final PerceptualHashDataSource _hashDataSource;
  final DismissedGroupDataSource _dismissedDataSource;
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
  Future<List<MediaEntity>> _libraryImages() async {
    final media = await _mediaRepository.getAllMedia();
    return media
        .where((item) => item.type == MediaType.image)
        .toList(growable: false);
  }

  @override
  Stream<DuplicateScanProgress> hashLibrary({
    DuplicateScanCancellation? cancellation,
  }) async* {
    final images = await _libraryImages();
    final total = images.length;
    if (total == 0) {
      yield const DuplicateScanProgress(
        processed: 0,
        total: 0,
        isComplete: true,
      );
      return;
    }

    final cached = await _hashDataSource.getByMediaIds(
      images.map((image) => image.id),
    );

    var processed = 0;
    var reused = 0;
    var failed = 0;
    final pending = <PerceptualHash>[];

    for (var i = 0; i < images.length; i++) {
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

      final image = images[i];
      final fingerprint = perceptualFingerprint(
        size: image.size,
        lastModified: image.lastModified,
      );
      final existing = cached[image.id];

      if (existing != null && existing.fingerprint == fingerprint) {
        reused++;
      } else {
        final result = await _hasher.hashFile(image.path);
        if (result == null) {
          failed++;
        } else {
          pending.add(
            PerceptualHash(
              mediaId: image.id,
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

      final isLast = i == images.length - 1;
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

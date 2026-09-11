import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/models/media_lookup_mode.dart';
import 'package:media_fast_view/core/models/video_frame_lookup_precision.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/features/duplicates/data/services/image_lookup_file_picker.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_library_coverage.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_candidate.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_batch.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_match.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_result.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_session.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_update.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_verification_summary.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_index_coverage.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/duplicate_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/image_lookup_history_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/find_image_matches_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/get_duplicate_library_coverage_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/get_video_frame_index_coverage_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/prepare_video_frame_index_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/scan_for_duplicates_use_case.dart';
import 'package:media_fast_view/features/duplicates/presentation/view_models/image_lookup_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _FakeDuplicateRepository implements DuplicateRepository {
  DuplicateLibraryCoverage coverage = const DuplicateLibraryCoverage(
    totalImages: 1,
    readyImages: 1,
  );
  VideoFrameIndexCoverage videoFrameCoverage = const VideoFrameIndexCoverage(
    totalVideos: 0,
    readyVideos: 0,
  );
  late ImageLookupBatch batch;
  ImageLookupBatch? rematchedBatch;
  final Completer<void> scanGate = Completer<void>();
  final Completer<void> findStarted = Completer<void>();
  Completer<void>? videoPreparationGate;
  Completer<void>? findGate;
  void Function(ImageLookupUpdate update)? findUpdate;
  var rematchCalls = 0;
  Set<MediaType>? coverageMediaTypes;
  Set<MediaType>? scanMediaTypes;
  MediaLookupMode? lookupMode;
  VideoFrameLookupPrecision? lookupPrecision;
  bool failVideoPreparation = false;

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
    this.lookupMode = lookupMode;
    this.lookupPrecision = lookupPrecision;
    findUpdate = onUpdate;
    if (!findStarted.isCompleted) {
      findStarted.complete();
    }
    onProgress?.call(
      ImageLookupProgress(
        stage: ImageLookupProgressStage.searchingIndexedMedia,
        processed: sources.length,
        total: sources.length,
      ),
    );
    final gate = findGate;
    if (gate != null) {
      await gate.future;
    }
    final summary =
        batch.verificationSummary ?? const ImageLookupVerificationSummary();
    onUpdate?.call(
      ImageLookupUpdate(
        progress: ImageLookupProgress(
          stage: ImageLookupProgressStage.verifyingVideoFrames,
          processed: summary.verifiedVideoCount,
          total: summary.eligibleVideoCount,
        ),
        results: batch.results,
        verificationSummary: summary,
      ),
    );
    return batch;
  }

  @override
  Future<VideoFrameIndexCoverage> getVideoFrameIndexCoverage({
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) async {
    return videoFrameCoverage;
  }

  @override
  Future<DuplicateLibraryCoverage> getLibraryCoverage({
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) async {
    coverageMediaTypes = mediaTypes;
    return coverage;
  }

  @override
  Stream<DuplicateScanProgress> hashVideoFrames({
    DuplicateScanCancellation? cancellation,
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) async* {
    this.lookupPrecision = lookupPrecision;
    yield const DuplicateScanProgress(processed: 0, total: 1);
    final gate = videoPreparationGate;
    if (gate != null) {
      await gate.future;
    }
    yield DuplicateScanProgress(
      processed: 1,
      total: 1,
      failed: failVideoPreparation ? 1 : 0,
      isComplete: !(cancellation?.isCancelled ?? false),
      isCancelled: cancellation?.isCancelled ?? false,
    );
  }

  @override
  Stream<DuplicateScanProgress> hashLibrary({
    DuplicateScanCancellation? cancellation,
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) async* {
    scanMediaTypes = mediaTypes;
    yield const DuplicateScanProgress(processed: 0, total: 1);
    await scanGate.future;
    yield DuplicateScanProgress(
      processed: 0,
      total: 1,
      isCancelled: cancellation?.isCancelled ?? false,
      isComplete: !(cancellation?.isCancelled ?? false),
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
    rematchCalls++;
    onProgress?.call(
      ImageLookupProgress(
        stage: ImageLookupProgressStage.searchingIndexedMedia,
        processed: queries.length,
        total: queries.length,
      ),
    );
    onUpdate?.call(
      ImageLookupUpdate(
        progress: ImageLookupProgress(
          stage: ImageLookupProgressStage.searchingIndexedMedia,
          processed: queries.length,
          total: queries.length,
        ),
        results: (rematchedBatch ?? batch).results,
        verificationSummary:
            (rematchedBatch ?? batch).verificationSummary ??
            const ImageLookupVerificationSummary(),
      ),
    );
    return rematchedBatch ?? batch;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeFilePicker implements MediaLookupFilePicker {
  _FakeFilePicker(this.sources);

  final List<ImageLookupSource> sources;
  Set<MediaType>? allowedMediaTypes;

  @override
  Future<List<ImageLookupSource>> pickMedia({
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  }) async {
    this.allowedMediaTypes = allowedMediaTypes;
    return sources;
  }

  @override
  Future<List<ImageLookupSource>> sourcesFromPaths(
    Iterable<String> paths, {
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  }) async {
    this.allowedMediaTypes = allowedMediaTypes;
    return sources;
  }
}

class _FakeHistoryRepository implements ImageLookupHistoryRepository {
  final List<ImageLookupSession> sessions = <ImageLookupSession>[];

  @override
  Future<void> clear(String profileId) async {
    sessions.removeWhere((session) => session.profileId == profileId);
  }

  @override
  Future<void> delete(String sessionId) async {
    sessions.removeWhere((session) => session.id == sessionId);
  }

  @override
  Future<List<ImageLookupSession>> load(String profileId) async => sessions
      .where((session) => session.profileId == profileId)
      .toList(growable: false);

  @override
  Future<void> save(ImageLookupSession session) async {
    sessions.removeWhere((existing) => existing.id == session.id);
    sessions.add(session);
  }
}

ImageLookupSource _source({MediaType mediaType = MediaType.image}) =>
    ImageLookupSource(
      path: mediaType == MediaType.video ? '/query.mov' : '/query.jpg',
      name: mediaType == MediaType.video ? 'query.mov' : 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
      mediaType: mediaType,
    );

ImageLookupBatch _batch(
  ImageLookupSource source, {
  int searchedLibraryImages = 4,
  List<ImageLookupMatch> matches = const <ImageLookupMatch>[],
  ImageLookupVerificationSummary? verificationSummary,
}) => ImageLookupBatch(
  searchedLibraryImages: searchedLibraryImages,
  verificationSummary: verificationSummary,
  results: <ImageLookupResult>[
    ImageLookupResult(
      source: source,
      query: ImageLookupQuery(source: source, hash: 0, width: 800, height: 600),
      matches: matches,
    ),
  ],
);

ImageLookupMatch _testMatch() => ImageLookupMatch(
  candidate: DuplicateCandidate(
    media: MediaEntity(
      id: 'matched-media',
      path: '/library/matched.jpg',
      name: 'matched.jpg',
      type: MediaType.image,
      size: 200,
      lastModified: DateTime(2024),
      tagIds: const <String>[],
      directoryId: 'directory',
    ),
    width: 800,
    height: 600,
    hash: 1,
  ),
  distance: 0,
);

ImageLookupViewModel _viewModel({
  required _FakeDuplicateRepository duplicateRepository,
  required _FakeHistoryRepository historyRepository,
  bool historyEnabled = true,
  MediaLookupMode initialLookupMode = MediaLookupMode.mediaMatches,
  Future<void> Function(MediaLookupMode mode)? saveLookupMode,
  _FakeFilePicker? filePicker,
  VideoFrameLookupPrecision initialLookupPrecision =
      VideoFrameLookupPrecision.standard,
  Future<void> Function(VideoFrameLookupPrecision precision)?
  saveLookupPrecision,
}) {
  final source = _source();
  return ImageLookupViewModel(
    profileId: 'profile-a',
    scanUseCase: ScanForDuplicatesUseCase(duplicateRepository),
    coverageUseCase: GetDuplicateLibraryCoverageUseCase(duplicateRepository),
    videoFrameCoverageUseCase: GetVideoFrameIndexCoverageUseCase(
      duplicateRepository,
    ),
    prepareVideoFramesUseCase: PrepareVideoFrameIndexUseCase(
      duplicateRepository,
    ),
    findMatchesUseCase: FindImageMatchesUseCase(duplicateRepository),
    filePicker: filePicker ?? _FakeFilePicker(<ImageLookupSource>[source]),
    historyRepository: historyRepository,
    bookmarkService: BookmarkService.instance,
    isHistoryEnabled: () => historyEnabled,
    saveLookupMode: saveLookupMode ?? (_) async {},
    initialLookupMode: initialLookupMode,
    initialLookupPrecision: initialLookupPrecision,
    saveLookupPrecision: saveLookupPrecision,
  );
}

void main() {
  test(
    'completed lookup is exposed and saved when history is enabled',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..batch = _batch(source);
      final historyRepository = _FakeHistoryRepository();
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: historyRepository,
      );

      await viewModel.startLookup(<ImageLookupSource>[source]);

      final phase = viewModel.state.phase as ImageLookupResults;
      expect(phase.session.results.single.source.path, source.path);
      expect(phase.session.searchedLibraryImages, 4);
      expect(historyRepository.sessions, hasLength(1));
      viewModel.dispose();
    },
  );

  test('video lookup prepares and searches only indexed videos', () async {
    final source = _source(mediaType: MediaType.video);
    final duplicateRepository = _FakeDuplicateRepository()
      ..batch = _batch(source);
    final viewModel = ImageLookupViewModel(
      profileId: 'profile-a',
      scanUseCase: ScanForDuplicatesUseCase(duplicateRepository),
      coverageUseCase: GetDuplicateLibraryCoverageUseCase(duplicateRepository),
      videoFrameCoverageUseCase: GetVideoFrameIndexCoverageUseCase(
        duplicateRepository,
      ),
      prepareVideoFramesUseCase: PrepareVideoFrameIndexUseCase(
        duplicateRepository,
      ),
      findMatchesUseCase: FindImageMatchesUseCase(duplicateRepository),
      filePicker: _FakeFilePicker(<ImageLookupSource>[source]),
      historyRepository: _FakeHistoryRepository(),
      bookmarkService: BookmarkService.instance,
      isHistoryEnabled: () => false,
      saveLookupMode: (_) async {},
    );

    await viewModel.startLookup(<ImageLookupSource>[source]);

    expect(duplicateRepository.coverageMediaTypes, <MediaType>{
      MediaType.video,
    });
    expect(viewModel.state.phase, isA<ImageLookupResults>());
    viewModel.dispose();
  });

  test(
    'video-from-frame mode searches the frame index and requests images',
    () async {
      final source = _source();
      final picker = _FakeFilePicker(<ImageLookupSource>[source]);
      final duplicateRepository = _FakeDuplicateRepository()
        ..videoFrameCoverage = const VideoFrameIndexCoverage(
          totalVideos: 2,
          readyVideos: 2,
        )
        ..batch = _batch(source, searchedLibraryImages: 2);
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        historyEnabled: false,
        initialLookupMode: MediaLookupMode.videoFromFrame,
        filePicker: picker,
      );

      await viewModel.pickMedia();

      expect(picker.allowedMediaTypes, <MediaType>{MediaType.image});
      expect(duplicateRepository.lookupMode, MediaLookupMode.videoFromFrame);
      final phase = viewModel.state.phase as ImageLookupResults;
      expect(phase.session.lookupMode, MediaLookupMode.videoFromFrame);
      viewModel.dispose();
    },
  );

  test(
    'maximum precision changes apply only after an explicit search again',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..videoFrameCoverage = const VideoFrameIndexCoverage(
          totalVideos: 1,
          readyVideos: 1,
        )
        ..batch = _batch(source, searchedLibraryImages: 1);
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        historyEnabled: false,
        initialLookupMode: MediaLookupMode.videoFromFrame,
      );

      await viewModel.startLookup(<ImageLookupSource>[source]);
      await viewModel.setLookupPrecision(VideoFrameLookupPrecision.maximum);

      expect(viewModel.canSearchAgain, isTrue);
      expect(
        (viewModel.state.phase as ImageLookupResults).session.lookupPrecision,
        VideoFrameLookupPrecision.standard,
      );

      await viewModel.searchAgain();

      expect(
        duplicateRepository.lookupPrecision,
        VideoFrameLookupPrecision.maximum,
      );
      expect(viewModel.canSearchAgain, isFalse);
      viewModel.dispose();
    },
  );

  test(
    'maximum precision preparation failures remain visible for retry',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..videoFrameCoverage = const VideoFrameIndexCoverage(
          totalVideos: 1,
          readyVideos: 0,
        )
        ..failVideoPreparation = true
        ..batch = _batch(source);
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        historyEnabled: false,
        initialLookupMode: MediaLookupMode.videoFromFrame,
        initialLookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      await viewModel.startLookup(<ImageLookupSource>[source]);

      expect(viewModel.state.phase, isA<ImageLookupFailure>());
      expect(
        (viewModel.state.phase as ImageLookupFailure).message,
        contains('could not be indexed'),
      );
      viewModel.dispose();
    },
  );

  test(
    'changing lookup mode resets results and persists the preference',
    () async {
      final savedModes = <MediaLookupMode>[];
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..batch = _batch(source);
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        saveLookupMode: (mode) async => savedModes.add(mode),
      );
      await viewModel.startLookup(<ImageLookupSource>[source]);

      await viewModel.setLookupMode(MediaLookupMode.videoFromFrame);

      expect(viewModel.state.lookupMode, MediaLookupMode.videoFromFrame);
      expect(viewModel.state.phase, isA<ImageLookupIdle>());
      expect(savedModes, <MediaLookupMode>[MediaLookupMode.videoFromFrame]);
      viewModel.dispose();
    },
  );

  test(
    'sensitivity rematches cached queries without a new query hash',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..batch = _batch(source)
        ..rematchedBatch = _batch(source, searchedLibraryImages: 8);
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
      );
      await viewModel.startLookup(<ImageLookupSource>[source]);

      await viewModel.setSensitivity(DuplicateSensitivity.loose);

      final phase = viewModel.state.phase as ImageLookupResults;
      expect(phase.session.sensitivity, DuplicateSensitivity.loose);
      expect(phase.session.searchedLibraryImages, 8);
      expect(duplicateRepository.rematchCalls, 1);
      viewModel.dispose();
    },
  );

  test(
    'skip starts maximum-precision search before preparation cleanup finishes',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..videoFrameCoverage = const VideoFrameIndexCoverage(
          totalVideos: 2,
          readyVideos: 1,
        )
        ..videoPreparationGate = Completer<void>()
        ..batch = _batch(source);
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        historyEnabled: false,
        initialLookupMode: MediaLookupMode.videoFromFrame,
        initialLookupPrecision: VideoFrameLookupPrecision.maximum,
      );

      final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.phase, isA<ImageLookupPreparing>());

      viewModel.skipPreparation();
      final searchingPhase = viewModel.state.phase as ImageLookupSearching;
      expect(searchingPhase.hasPartialCoverage, isTrue);
      expect(duplicateRepository.videoPreparationGate!.isCompleted, isFalse);

      await duplicateRepository.findStarted.future;
      await Future<void>.delayed(Duration.zero);

      final phase = viewModel.state.phase as ImageLookupResults;
      expect(phase.session.hasPartialCoverage, isTrue);
      expect(duplicateRepository.videoPreparationGate!.isCompleted, isFalse);

      duplicateRepository.videoPreparationGate!.complete();
      await lookup;
      expect(viewModel.state.phase, same(phase));
      viewModel.dispose();
    },
  );

  test(
    'progressive updates are retained and stop saves a partial snapshot',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..batch = _batch(source, searchedLibraryImages: 3)
        ..findGate = Completer<void>();
      final historyRepository = _FakeHistoryRepository();
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: historyRepository,
      );
      final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
      await duplicateRepository.findStarted.future;
      await Future<void>.delayed(Duration.zero);

      final earlierMatch = _batch(
        source,
        matches: <ImageLookupMatch>[_testMatch()],
      ).results.single;
      final remainingSource = source.copyWith(
        path: '/query-remaining.jpg',
        name: 'query-remaining.jpg',
      );
      final remainingQuery = ImageLookupResult(
        source: remainingSource,
        query: ImageLookupQuery(
          source: remainingSource,
          hash: 1,
          width: 800,
          height: 600,
        ),
        matches: const <ImageLookupMatch>[],
      );
      final update = ImageLookupUpdate(
        progress: const ImageLookupProgress(
          stage: ImageLookupProgressStage.verifyingVideoFrames,
          processed: 2,
          total: 3,
          currentItemProcessed: 2,
          currentItemTotal: 4,
          verificationPhase: ImageLookupVerificationPhase.remaining,
        ),
        results: <ImageLookupResult>[earlierMatch, remainingQuery],
        verificationSummary: const ImageLookupVerificationSummary(
          eligibleVideoCount: 3,
          verifiedVideoCount: 2,
        ),
      );
      duplicateRepository.findUpdate!.call(update);
      await Future<void>.delayed(Duration.zero);

      final searching = viewModel.state.phase as ImageLookupSearching;
      expect(searching.results, hasLength(2));
      expect(searching.results.first.matches, hasLength(1));
      expect(searching.verificationSummary?.verifiedVideoCount, 2);
      viewModel.syncLookupPrecisionFromSettings(
        VideoFrameLookupPrecision.maximum,
      );

      await viewModel.stopAndKeepResults();

      final results = viewModel.state.phase as ImageLookupResults;
      expect(results.session.hasStoppedVerification, isTrue);
      expect(results.session.hasPartialCoverage, isFalse);
      expect(results.session.results, hasLength(2));
      expect(results.session.results.first.matches, hasLength(1));
      expect(
        results.session.lookupPrecision,
        VideoFrameLookupPrecision.standard,
      );
      expect(
        viewModel.state.lookupPrecision,
        VideoFrameLookupPrecision.maximum,
      );
      expect(historyRepository.sessions.single.hasStoppedVerification, isTrue);

      final rematchedSummary = const ImageLookupVerificationSummary(
        eligibleVideoCount: 8,
        verifiedVideoCount: 8,
      );
      duplicateRepository.rematchedBatch = ImageLookupBatch(
        results: results.session.results,
        searchedLibraryImages: 8,
        verificationSummary: rematchedSummary,
      );
      await viewModel.setSensitivity(DuplicateSensitivity.loose);

      final rematched = viewModel.state.phase as ImageLookupResults;
      expect(rematched.session.sensitivity, DuplicateSensitivity.loose);
      expect(rematched.session.hasStoppedVerification, isFalse);
      expect(rematched.session.verificationSummary, rematchedSummary);
      expect(rematched.session.searchedLibraryImages, 8);
      expect(historyRepository.sessions.single.hasStoppedVerification, isFalse);

      duplicateRepository.findGate!.complete();
      await lookup;
      expect(viewModel.state.phase, isA<ImageLookupResults>());
      viewModel.dispose();
    },
  );

  test(
    'cancel discards progressive results and ignores late callbacks',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..batch = _batch(source)
        ..findGate = Completer<void>();
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        historyEnabled: false,
      );
      final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
      await duplicateRepository.findStarted.future;
      await Future<void>.delayed(Duration.zero);
      duplicateRepository.findUpdate!.call(
        ImageLookupUpdate(
          progress: const ImageLookupProgress(
            stage: ImageLookupProgressStage.verifyingVideoFrames,
            processed: 1,
            total: 2,
          ),
          results: _batch(source).results,
          verificationSummary: const ImageLookupVerificationSummary(
            eligibleVideoCount: 2,
            verifiedVideoCount: 1,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      await viewModel.cancel();
      expect(viewModel.state.phase, isA<ImageLookupIdle>());
      duplicateRepository.findUpdate!.call(
        ImageLookupUpdate(
          progress: const ImageLookupProgress(
            stage: ImageLookupProgressStage.verifyingVideoFrames,
            processed: 2,
            total: 2,
          ),
          results: _batch(source).results,
          verificationSummary: const ImageLookupVerificationSummary(),
        ),
      );
      expect(viewModel.state.phase, isA<ImageLookupIdle>());

      duplicateRepository.findGate!.complete();
      await lookup;
      viewModel.dispose();
    },
  );

  test('early stop does not present query progress as video counts', () async {
    final source = _source();
    final duplicateRepository = _FakeDuplicateRepository()
      ..batch = _batch(source)
      ..findGate = Completer<void>();
    final viewModel = _viewModel(
      duplicateRepository: duplicateRepository,
      historyRepository: _FakeHistoryRepository(),
      historyEnabled: false,
    );
    final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
    await duplicateRepository.findStarted.future;
    await Future<void>.delayed(Duration.zero);

    await viewModel.stopAndKeepResults();

    final results = viewModel.state.phase as ImageLookupResults;
    expect(results.session.hasStoppedVerification, isTrue);
    expect(results.session.verificationSummary?.eligibleVideoCount, 0);
    expect(results.session.verificationSummary?.verifiedVideoCount, 0);

    duplicateRepository.findGate!.complete();
    await lookup;
    viewModel.dispose();
  });

  test(
    'background search stays active until the terminal batch arrives',
    () async {
      final source = _source();
      final duplicateRepository = _FakeDuplicateRepository()
        ..batch = _batch(source)
        ..findGate = Completer<void>();
      final viewModel = _viewModel(
        duplicateRepository: duplicateRepository,
        historyRepository: _FakeHistoryRepository(),
        historyEnabled: false,
      );
      final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
      await duplicateRepository.findStarted.future;
      await Future<void>.delayed(Duration.zero);

      viewModel.runInBackground();
      expect(viewModel.state.isRunningInBackground, isTrue);
      duplicateRepository.findUpdate!.call(
        ImageLookupUpdate(
          progress: const ImageLookupProgress(
            stage: ImageLookupProgressStage.verifyingVideoFrames,
            processed: 1,
            total: 2,
            verificationPhase: ImageLookupVerificationPhase.remaining,
          ),
          results: _batch(source).results,
          verificationSummary: const ImageLookupVerificationSummary(
            eligibleVideoCount: 2,
            verifiedVideoCount: 1,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.state.isRunningInBackground, isTrue);

      duplicateRepository.findGate!.complete();
      await lookup;
      expect(viewModel.state.isRunningInBackground, isFalse);
      viewModel.dispose();
    },
  );

  test('disposing during a delayed search ignores late updates', () async {
    final source = _source();
    final duplicateRepository = _FakeDuplicateRepository()
      ..batch = _batch(source)
      ..findGate = Completer<void>();
    final viewModel = _viewModel(
      duplicateRepository: duplicateRepository,
      historyRepository: _FakeHistoryRepository(),
      historyEnabled: false,
    );
    final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
    await duplicateRepository.findStarted.future;
    await Future<void>.delayed(Duration.zero);
    final update = duplicateRepository.findUpdate!;
    viewModel.dispose();

    update(
      ImageLookupUpdate(
        progress: const ImageLookupProgress(
          stage: ImageLookupProgressStage.verifyingVideoFrames,
          processed: 1,
          total: 2,
        ),
        results: _batch(source).results,
        verificationSummary: const ImageLookupVerificationSummary(
          eligibleVideoCount: 2,
          verifiedVideoCount: 1,
        ),
      ),
    );
    duplicateRepository.findGate!.complete();
    await lookup;
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_session.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_match.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_result.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_update.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_verification_summary.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/matched_video_frame.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/video_frame_index_coverage.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/duplicate_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/image_lookup_history_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/find_image_matches_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/get_duplicate_library_coverage_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/get_video_frame_index_coverage_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/prepare_video_frame_index_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/scan_for_duplicates_use_case.dart';
import 'package:media_fast_view/features/duplicates/presentation/screens/image_lookup_screen.dart';
import 'package:media_fast_view/features/duplicates/presentation/view_models/image_lookup_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _UnusedDuplicateRepository implements DuplicateRepository {
  @override
  Future<DuplicateLibraryCoverage> getLibraryCoverage({
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) async => const DuplicateLibraryCoverage(totalImages: 0, readyImages: 0);

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
  }) async => const ImageLookupBatch(
    results: <ImageLookupResult>[],
    searchedLibraryImages: 0,
  );

  @override
  Future<VideoFrameIndexCoverage> getVideoFrameIndexCoverage({
    VideoFrameLookupPrecision lookupPrecision =
        VideoFrameLookupPrecision.standard,
  }) async {
    return const VideoFrameIndexCoverage(totalVideos: 0, readyVideos: 0);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedPicker implements MediaLookupFilePicker {
  @override
  Future<List<ImageLookupSource>> pickMedia({
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  }) async => const <ImageLookupSource>[];

  @override
  Future<List<ImageLookupSource>> sourcesFromPaths(
    Iterable<String> paths, {
    Set<MediaType> allowedMediaTypes = const <MediaType>{
      MediaType.image,
      MediaType.video,
    },
  }) async => const <ImageLookupSource>[];
}

class _EmptyHistory implements ImageLookupHistoryRepository {
  @override
  Future<void> clear(String profileId) async {}

  @override
  Future<void> delete(String sessionId) async {}

  @override
  Future<List<ImageLookupSession>> load(String profileId) async =>
      const <ImageLookupSession>[];

  @override
  Future<void> save(ImageLookupSession session) async {}
}

class _TestImageLookupViewModel extends ImageLookupViewModel {
  _TestImageLookupViewModel()
    : super(
        profileId: 'profile',
        scanUseCase: ScanForDuplicatesUseCase(_UnusedDuplicateRepository()),
        coverageUseCase: GetDuplicateLibraryCoverageUseCase(
          _UnusedDuplicateRepository(),
        ),
        videoFrameCoverageUseCase: GetVideoFrameIndexCoverageUseCase(
          _UnusedDuplicateRepository(),
        ),
        prepareVideoFramesUseCase: PrepareVideoFrameIndexUseCase(
          _UnusedDuplicateRepository(),
        ),
        findMatchesUseCase: FindImageMatchesUseCase(
          _UnusedDuplicateRepository(),
        ),
        filePicker: _UnusedPicker(),
        historyRepository: _EmptyHistory(),
        bookmarkService: BookmarkService.instance,
        isHistoryEnabled: () => false,
        saveLookupMode: (_) async {},
      );

  void emit(ImageLookupViewState value) {
    state = value;
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _TestImageLookupViewModel viewModel,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        imageLookupViewModelProvider.overrideWith((ref) => viewModel),
      ],
      child: const MaterialApp(home: ImageLookupScreen()),
    ),
  );
}

void main() {
  testWidgets('idle screen explains picker and drop input', (tester) async {
    final viewModel = _TestImageLookupViewModel();
    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Find Media Matches'), findsOneWidget);
    expect(
      find.text('Check images or videos against your library'),
      findsOneWidget,
    );
    expect(find.text('Choose Media'), findsOneWidget);
    expect(find.byIcon(Icons.perm_media_outlined), findsWidgets);
  });

  testWidgets('video-from-frame mode explains five-frame image lookup', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    viewModel.emit(
      const ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Find a video from one of its frames'), findsOneWidget);
    expect(find.text('Choose Image Frames'), findsOneWidget);
    expect(find.textContaining('10%, 30%, 50%, 70%, and 90%'), findsOneWidget);
  });

  testWidgets('lookup options exposes and toggles maximum precision', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    viewModel.emit(
      const ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.tap(find.byTooltip('Lookup options'));
    await tester.pumpAndSettle();

    expect(find.text('Maximum precision video-frame search'), findsOneWidget);
    expect(
      find.textContaining('requires additional cache space'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch).last);
    await tester.pump();

    expect(viewModel.state.lookupPrecision, VideoFrameLookupPrecision.maximum);
    expect(find.byType(Switch).last, findsOneWidget);
  });

  testWidgets('video results show the active scope and searched video count', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/frame.jpg',
      name: 'frame.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        phase: ImageLookupResults(
          session: ImageLookupSession(
            id: 'video-scope-session',
            profileId: 'profile',
            createdAt: DateTime(2024),
            sensitivity: DuplicateSensitivity.balanced,
            lookupMode: MediaLookupMode.videoFromFrame,
            hasPartialCoverage: false,
            searchedLibraryImages: 3,
            results: <ImageLookupResult>[
              ImageLookupResult(
                source: source,
                query: ImageLookupQuery(
                  source: source,
                  hash: 0,
                  width: 800,
                  height: 600,
                ),
                matches: const <ImageLookupMatch>[],
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Lookup scope: Video from frame'), findsOneWidget);
    expect(find.text('Searched 3 indexed videos'), findsOneWidget);
    expect(
      find.byTooltip('Active lookup mode: Video from frame'),
      findsOneWidget,
    );
    expect(
      find.text('No matches found in the currently indexed library.'),
      findsOneWidget,
    );
  });

  testWidgets('preparation exposes skip cancel and background controls', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        phase: ImageLookupPreparing(
          sources: <ImageLookupSource>[source],
          progress: const DuplicateScanProgress(processed: 2, total: 10),
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Preparing Library'), findsOneWidget);
    expect(find.text('Skip & Search'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Run in Background'), findsOneWidget);
  });

  testWidgets('partial matching identifies the indexed-video scope', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        phase: ImageLookupSearching(
          sources: <ImageLookupSource>[source],
          progress: const ImageLookupProgress.preparingQueries(
            processed: 0,
            total: 1,
          ),
          hasPartialCoverage: true,
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Finding Matches in Indexed Videos'), findsOneWidget);
    expect(
      find.text('Preparing the query image before searching the index…'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('ready query shows an active index-loading stage', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        phase: ImageLookupSearching(
          sources: <ImageLookupSource>[source],
          progress: const ImageLookupProgress.preparingQueries(
            processed: 1,
            total: 1,
          ),
          hasPartialCoverage: true,
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(
      find.text('Query image ready. Loading the indexed library…'),
      findsOneWidget,
    );
    expect(find.textContaining('Processed 1 of 1'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('maximum search displays live video and frame progress', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        phase: ImageLookupSearching(
          sources: <ImageLookupSource>[source],
          progress: const ImageLookupProgress(
            stage: ImageLookupProgressStage.scanningVideoFrames,
            processed: 1,
            total: 4,
            currentItemProcessed: 250,
            currentItemTotal: 1000,
          ),
          hasPartialCoverage: true,
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(
      find.text('Scanning video 2 of 4 · 250 of 1000 frames'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.3125, 0.0001),
    );
  });

  testWidgets('maximum search explains the bounded Vision verification pass', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        lookupPrecision: VideoFrameLookupPrecision.maximum,
        phase: ImageLookupSearching(
          sources: <ImageLookupSource>[source],
          progress: const ImageLookupProgress(
            stage: ImageLookupProgressStage.verifyingVideoFrames,
            processed: 0,
            total: 1,
            currentItemTotal: 12,
          ),
          hasPartialCoverage: true,
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.textContaining('Checking likely scenes'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
  });

  testWidgets('searching view shows accumulated results and stop action', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    final invalidSource = source.copyWith(
      path: '/invalid.jpg',
      name: 'invalid.jpg',
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        phase: ImageLookupSearching(
          sources: <ImageLookupSource>[source],
          progress: const ImageLookupProgress(
            stage: ImageLookupProgressStage.verifyingVideoFrames,
            processed: 2,
            total: 4,
            currentItemProcessed: 2,
            currentItemTotal: 4,
            verificationPhase: ImageLookupVerificationPhase.remaining,
          ),
          hasPartialCoverage: false,
          results: <ImageLookupResult>[
            ImageLookupResult(
              source: source,
              query: ImageLookupQuery(
                source: source,
                hash: 0,
                width: 800,
                height: 600,
              ),
              matches: const <ImageLookupMatch>[],
            ),
            ImageLookupResult(
              source: invalidSource,
              errorMessage: 'The image could not be read or decoded.',
              matches: const <ImageLookupMatch>[],
            ),
          ],
          verificationSummary: const ImageLookupVerificationSummary(
            eligibleVideoCount: 4,
            verifiedVideoCount: 2,
          ),
          startedAt: DateTime(2024),
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(
      find.text(
        'Checking likely scenes in the remaining videos · 2 of 4 videos checked · '
        '2 of 4 videos in this pass…',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Checked 2 of 4 videos · 2 verified · 0 matches so far'),
      findsOneWidget,
    );
    expect(find.textContaining('1 result so far'), findsNothing);
    expect(find.text('Stop & Keep Results'), findsOneWidget);
    expect(find.text('query.jpg'), findsOneWidget);
    expect(
      find.text('Results will appear here as videos are checked.'),
      findsNothing,
    );
    expect(
      find.text('Still checking this query against the indexed library…'),
      findsOneWidget,
    );
    expect(
      find.text('No matches found in the currently indexed library.'),
      findsNothing,
    );
    final searching = viewModel.state.phase as ImageLookupSearching;
    expect(searching.results, hasLength(2));
    expect(searching.results.last.hasError, isTrue);
  });

  testWidgets('video results identify and render the generated miniature', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.mov',
      name: 'query.mov',
      size: 5000,
      lastModified: DateTime(2024),
      mediaType: MediaType.video,
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        phase: ImageLookupResults(
          session: ImageLookupSession(
            id: 'video-session',
            profileId: 'profile',
            createdAt: DateTime(2024),
            sensitivity: DuplicateSensitivity.balanced,
            hasPartialCoverage: false,
            searchedLibraryImages: 2,
            results: <ImageLookupResult>[
              ImageLookupResult(
                source: source,
                query: ImageLookupQuery(
                  source: source,
                  hash: 0,
                  width: 512,
                  height: 288,
                ),
                matches: const [],
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Video'), findsOneWidget);
    expect(find.textContaining('Video miniature · 512 × 288'), findsOneWidget);
    expect(
      find.text('No matches found in the currently indexed library.'),
      findsOneWidget,
    );
  });

  testWidgets('stopped verification is distinct from skipped index coverage', (
    tester,
  ) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/query.jpg',
      name: 'query.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        phase: ImageLookupResults(
          session: ImageLookupSession(
            id: 'stopped-session',
            profileId: 'profile',
            createdAt: DateTime(2024),
            sensitivity: DuplicateSensitivity.balanced,
            lookupMode: MediaLookupMode.videoFromFrame,
            hasPartialCoverage: false,
            searchedLibraryImages: 4,
            verificationSummary: const ImageLookupVerificationSummary(
              eligibleVideoCount: 4,
              verifiedVideoCount: 2,
              stopped: true,
            ),
            results: <ImageLookupResult>[
              ImageLookupResult(
                source: source,
                query: ImageLookupQuery(
                  source: source,
                  hash: 0,
                  width: 800,
                  height: 600,
                ),
                matches: const <ImageLookupMatch>[],
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(
      find.text(
        'Verification was stopped after checking 2 of 4 eligible videos. '
        'The results below are partial.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Library preparation was skipped'),
      findsNothing,
    );
  });

  testWidgets('frame results show the best sample timestamp', (tester) async {
    final viewModel = _TestImageLookupViewModel();
    final source = ImageLookupSource(
      path: '/frame.jpg',
      name: 'frame.jpg',
      size: 100,
      lastModified: DateTime(2024),
    );
    final video = MediaEntity(
      id: 'video',
      path: '/video.mov',
      name: 'video.mov',
      type: MediaType.video,
      size: 5000,
      lastModified: DateTime(2024),
      tagIds: const <String>[],
      directoryId: 'directory',
    );
    viewModel.emit(
      ImageLookupViewState(
        isHistoryLoading: false,
        lookupMode: MediaLookupMode.videoFromFrame,
        phase: ImageLookupResults(
          session: ImageLookupSession(
            id: 'frame-session',
            profileId: 'profile',
            createdAt: DateTime(2024),
            sensitivity: DuplicateSensitivity.balanced,
            lookupMode: MediaLookupMode.videoFromFrame,
            hasPartialCoverage: false,
            searchedLibraryImages: 1,
            results: <ImageLookupResult>[
              ImageLookupResult(
                source: source,
                query: ImageLookupQuery(
                  source: source,
                  hash: 0,
                  width: 800,
                  height: 600,
                ),
                matches: <ImageLookupMatch>[
                  ImageLookupMatch(
                    candidate: DuplicateCandidate(
                      media: video,
                      width: 512,
                      height: 288,
                      hash: 0,
                    ),
                    distance: 0,
                    matchedVideoFrame: const MatchedVideoFrame(
                      positionPercent: 30,
                      timestamp: Duration(minutes: 2, seconds: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpScreen(tester, viewModel);
    await tester.pump();

    expect(find.text('Matched around 02:13 · 30%'), findsOneWidget);
  });
}

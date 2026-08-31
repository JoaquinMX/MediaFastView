import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/features/duplicates/data/services/image_lookup_file_picker.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_library_coverage.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_batch.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_session.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_result.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/duplicate_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/image_lookup_history_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/find_image_matches_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/get_duplicate_library_coverage_use_case.dart';
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
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) async => const ImageLookupBatch(
    results: <ImageLookupResult>[],
    searchedLibraryImages: 0,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _UnusedPicker implements MediaLookupFilePicker {
  @override
  Future<List<ImageLookupSource>> pickMedia() async =>
      const <ImageLookupSource>[];

  @override
  Future<List<ImageLookupSource>> sourcesFromPaths(
    Iterable<String> paths,
  ) async => const <ImageLookupSource>[];
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
        findMatchesUseCase: FindImageMatchesUseCase(
          _UnusedDuplicateRepository(),
        ),
        filePicker: _UnusedPicker(),
        historyRepository: _EmptyHistory(),
        bookmarkService: BookmarkService.instance,
        isHistoryEnabled: () => false,
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
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Run in Background'), findsOneWidget);
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
}

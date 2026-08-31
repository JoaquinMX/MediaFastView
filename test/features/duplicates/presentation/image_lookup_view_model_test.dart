import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/bookmark_service.dart';
import 'package:media_fast_view/features/duplicates/data/services/image_lookup_file_picker.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_library_coverage.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_scan_progress.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_sensitivity.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_batch.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_match.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_query.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_result.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_session.dart';
import 'package:media_fast_view/features/duplicates/domain/entities/image_lookup_source.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/duplicate_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/repositories/image_lookup_history_repository.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/find_image_matches_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/get_duplicate_library_coverage_use_case.dart';
import 'package:media_fast_view/features/duplicates/domain/use_cases/scan_for_duplicates_use_case.dart';
import 'package:media_fast_view/features/duplicates/presentation/view_models/image_lookup_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

class _FakeDuplicateRepository implements DuplicateRepository {
  DuplicateLibraryCoverage coverage = const DuplicateLibraryCoverage(
    totalImages: 1,
    readyImages: 1,
  );
  late ImageLookupBatch batch;
  ImageLookupBatch? rematchedBatch;
  final Completer<void> scanGate = Completer<void>();
  var rematchCalls = 0;
  Set<MediaType>? coverageMediaTypes;
  Set<MediaType>? scanMediaTypes;

  @override
  Future<ImageLookupBatch> findImageMatches({
    required List<ImageLookupSource> sources,
    required DuplicateSensitivity sensitivity,
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) async {
    onProgress?.call(sources.length, sources.length);
    return batch;
  }

  @override
  Future<DuplicateLibraryCoverage> getLibraryCoverage({
    Set<MediaType> mediaTypes = const <MediaType>{MediaType.image},
  }) async {
    coverageMediaTypes = mediaTypes;
    return coverage;
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
    DuplicateScanCancellation? cancellation,
    void Function(int processed, int total)? onProgress,
  }) async {
    rematchCalls++;
    onProgress?.call(queries.length, queries.length);
    return rematchedBatch ?? batch;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeFilePicker implements MediaLookupFilePicker {
  _FakeFilePicker(this.sources);

  final List<ImageLookupSource> sources;

  @override
  Future<List<ImageLookupSource>> pickMedia() async => sources;

  @override
  Future<List<ImageLookupSource>> sourcesFromPaths(
    Iterable<String> paths,
  ) async => sources;
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
}) => ImageLookupBatch(
  searchedLibraryImages: searchedLibraryImages,
  results: <ImageLookupResult>[
    ImageLookupResult(
      source: source,
      query: ImageLookupQuery(source: source, hash: 0, width: 800, height: 600),
      matches: const <ImageLookupMatch>[],
    ),
  ],
);

ImageLookupViewModel _viewModel({
  required _FakeDuplicateRepository duplicateRepository,
  required _FakeHistoryRepository historyRepository,
  bool historyEnabled = true,
}) {
  final source = _source();
  return ImageLookupViewModel(
    profileId: 'profile-a',
    scanUseCase: ScanForDuplicatesUseCase(duplicateRepository),
    coverageUseCase: GetDuplicateLibraryCoverageUseCase(duplicateRepository),
    findMatchesUseCase: FindImageMatchesUseCase(duplicateRepository),
    filePicker: _FakeFilePicker(<ImageLookupSource>[source]),
    historyRepository: historyRepository,
    bookmarkService: BookmarkService.instance,
    isHistoryEnabled: () => historyEnabled,
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
      findMatchesUseCase: FindImageMatchesUseCase(duplicateRepository),
      filePicker: _FakeFilePicker(<ImageLookupSource>[source]),
      historyRepository: _FakeHistoryRepository(),
      bookmarkService: BookmarkService.instance,
      isHistoryEnabled: () => false,
    );

    await viewModel.startLookup(<ImageLookupSource>[source]);

    expect(duplicateRepository.coverageMediaTypes, <MediaType>{
      MediaType.video,
    });
    expect(viewModel.state.phase, isA<ImageLookupResults>());
    viewModel.dispose();
  });

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

  test('skip stops preparation and marks the result as partial', () async {
    final source = _source();
    final duplicateRepository = _FakeDuplicateRepository()
      ..coverage = const DuplicateLibraryCoverage(
        totalImages: 2,
        readyImages: 1,
      )
      ..batch = _batch(source);
    final viewModel = _viewModel(
      duplicateRepository: duplicateRepository,
      historyRepository: _FakeHistoryRepository(),
    );

    final lookup = viewModel.startLookup(<ImageLookupSource>[source]);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(viewModel.state.phase, isA<ImageLookupPreparing>());

    viewModel.skipPreparation();
    duplicateRepository.scanGate.complete();
    await lookup;

    final phase = viewModel.state.phase as ImageLookupResults;
    expect(phase.session.hasPartialCoverage, isTrue);
    viewModel.dispose();
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/media_lookup_mode.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../shared/providers/active_profile_provider.dart';
import '../../../../shared/providers/duplicate_providers.dart';
import '../../../../shared/providers/repository_providers.dart';
import '../../../../shared/providers/settings_providers.dart';
import '../../../media_library/domain/entities/media_entity.dart';
import '../../../settings/presentation/view_models/settings_view_model.dart';
import '../../data/services/image_lookup_file_picker.dart';
import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/duplicate_sensitivity.dart';
import '../../domain/entities/image_lookup_query.dart';
import '../../domain/entities/image_lookup_result.dart';
import '../../domain/entities/image_lookup_session.dart';
import '../../domain/entities/image_lookup_source.dart';
import '../../domain/repositories/image_lookup_history_repository.dart';
import '../../domain/use_cases/find_image_matches_use_case.dart';
import '../../domain/use_cases/get_duplicate_library_coverage_use_case.dart';
import '../../domain/use_cases/get_video_frame_index_coverage_use_case.dart';
import '../../domain/use_cases/prepare_video_frame_index_use_case.dart';
import '../../domain/use_cases/scan_for_duplicates_use_case.dart';

sealed class ImageLookupPhase {
  const ImageLookupPhase();
}

class ImageLookupIdle extends ImageLookupPhase {
  const ImageLookupIdle();
}

class ImageLookupPreparing extends ImageLookupPhase {
  const ImageLookupPreparing({required this.sources, required this.progress});

  final List<ImageLookupSource> sources;
  final DuplicateScanProgress progress;
}

class ImageLookupSearching extends ImageLookupPhase {
  const ImageLookupSearching({
    required this.sources,
    required this.processed,
    required this.total,
    required this.hasPartialCoverage,
  });

  final List<ImageLookupSource> sources;
  final int processed;
  final int total;
  final bool hasPartialCoverage;

  double get fraction => total == 0 ? 0 : processed / total;
}

class ImageLookupResults extends ImageLookupPhase {
  const ImageLookupResults({
    required this.session,
    this.isHistorySnapshot = false,
  });

  final ImageLookupSession session;
  final bool isHistorySnapshot;
}

class ImageLookupFailure extends ImageLookupPhase {
  const ImageLookupFailure(this.message);

  final String message;
}

/// Route-independent state for lookup progress, results, and saved history.
class ImageLookupViewState {
  const ImageLookupViewState({
    this.phase = const ImageLookupIdle(),
    this.sensitivity = DuplicateSensitivity.balanced,
    this.lookupMode = MediaLookupMode.mediaMatches,
    this.history = const <ImageLookupSession>[],
    this.isHistoryLoading = true,
    this.isRunningInBackground = false,
  });

  final ImageLookupPhase phase;
  final DuplicateSensitivity sensitivity;
  final MediaLookupMode lookupMode;
  final List<ImageLookupSession> history;
  final bool isHistoryLoading;
  final bool isRunningInBackground;

  bool get isBusy =>
      phase is ImageLookupPreparing || phase is ImageLookupSearching;

  ImageLookupViewState copyWith({
    ImageLookupPhase? phase,
    DuplicateSensitivity? sensitivity,
    MediaLookupMode? lookupMode,
    List<ImageLookupSession>? history,
    bool? isHistoryLoading,
    bool? isRunningInBackground,
  }) {
    return ImageLookupViewState(
      phase: phase ?? this.phase,
      sensitivity: sensitivity ?? this.sensitivity,
      lookupMode: lookupMode ?? this.lookupMode,
      history: history ?? this.history,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      isRunningInBackground:
          isRunningInBackground ?? this.isRunningInBackground,
    );
  }
}

/// Runs multi-media lookup work and intentionally outlives the lookup route.
class ImageLookupViewModel extends StateNotifier<ImageLookupViewState> {
  ImageLookupViewModel({
    required String profileId,
    required ScanForDuplicatesUseCase scanUseCase,
    required GetDuplicateLibraryCoverageUseCase coverageUseCase,
    required GetVideoFrameIndexCoverageUseCase videoFrameCoverageUseCase,
    required PrepareVideoFrameIndexUseCase prepareVideoFramesUseCase,
    required FindImageMatchesUseCase findMatchesUseCase,
    required MediaLookupFilePicker filePicker,
    required ImageLookupHistoryRepository historyRepository,
    required BookmarkService bookmarkService,
    required bool Function() isHistoryEnabled,
    required Future<void> Function(MediaLookupMode mode) saveLookupMode,
    Future<MediaLookupMode> Function()? loadLookupMode,
    MediaLookupMode initialLookupMode = MediaLookupMode.mediaMatches,
    Uuid uuid = const Uuid(),
  }) : _profileId = profileId,
       _scanUseCase = scanUseCase,
       _coverageUseCase = coverageUseCase,
       _videoFrameCoverageUseCase = videoFrameCoverageUseCase,
       _prepareVideoFramesUseCase = prepareVideoFramesUseCase,
       _findMatchesUseCase = findMatchesUseCase,
       _filePicker = filePicker,
       _historyRepository = historyRepository,
       _bookmarkService = bookmarkService,
       _isHistoryEnabled = isHistoryEnabled,
       _saveLookupMode = saveLookupMode,
       _loadLookupMode = loadLookupMode,
       _uuid = uuid,
       super(ImageLookupViewState(lookupMode: initialLookupMode)) {
    unawaited(_loadHistory());
    if (_loadLookupMode != null) {
      unawaited(_restoreLookupMode());
    }
  }

  final String _profileId;
  final ScanForDuplicatesUseCase _scanUseCase;
  final GetDuplicateLibraryCoverageUseCase _coverageUseCase;
  final GetVideoFrameIndexCoverageUseCase _videoFrameCoverageUseCase;
  final PrepareVideoFrameIndexUseCase _prepareVideoFramesUseCase;
  final FindImageMatchesUseCase _findMatchesUseCase;
  final MediaLookupFilePicker _filePicker;
  final ImageLookupHistoryRepository _historyRepository;
  final BookmarkService _bookmarkService;
  final bool Function() _isHistoryEnabled;
  final Future<void> Function(MediaLookupMode mode) _saveLookupMode;
  final Future<MediaLookupMode> Function()? _loadLookupMode;
  final Uuid _uuid;

  DuplicateScanCancellation? _cancellation;
  final List<String> _activeBookmarks = <String>[];
  int _operation = 0;
  int? _skipOperation;

  Future<void> pickMedia() async {
    try {
      final sources = await _filePicker.pickMedia(
        allowedMediaTypes: _allowedQueryMediaTypes,
      );
      if (sources.isNotEmpty) {
        await startLookup(sources);
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          phase: ImageLookupFailure('Could not select media: $error'),
        );
      }
    }
  }

  Future<void> startFromPaths(Iterable<String> paths) async {
    try {
      final sources = await _filePicker.sourcesFromPaths(
        paths,
        allowedMediaTypes: _allowedQueryMediaTypes,
      );
      if (sources.isEmpty) {
        state = state.copyWith(
          phase: ImageLookupFailure(
            state.lookupMode == MediaLookupMode.videoFromFrame
                ? 'No supported image frames were selected.'
                : 'No supported image or video files were selected.',
          ),
        );
        return;
      }
      await startLookup(sources);
    } catch (error) {
      if (mounted) {
        state = state.copyWith(
          phase: ImageLookupFailure(
            'Could not read the selected media: $error',
          ),
        );
      }
    }
  }

  Future<void> startLookup(List<ImageLookupSource> sources) async {
    final operation = ++_operation;
    _cancellation?.cancel();
    _skipOperation = null;
    await _releaseBookmarks();
    final activeSources = await _activateSources(sources);
    if (!mounted || operation != _operation) {
      return;
    }

    state = state.copyWith(
      phase: ImageLookupPreparing(
        sources: activeSources,
        progress: const DuplicateScanProgress.initial(),
      ),
      isRunningInBackground: false,
    );

    try {
      if (state.lookupMode == MediaLookupMode.videoFromFrame) {
        final coverage = await _videoFrameCoverageUseCase();
        if (!mounted || operation != _operation) {
          return;
        }
        if (coverage.isComplete) {
          await _search(
            operation: operation,
            sources: activeSources,
            hasPartialCoverage: false,
          );
          return;
        }
        await _prepareVideoFrames(operation, activeSources);
        return;
      }
      final mediaTypes = activeSources
          .map((source) => source.mediaType)
          .toSet();
      final coverage = await _coverageUseCase(mediaTypes: mediaTypes);
      if (!mounted || operation != _operation) {
        return;
      }
      if (coverage.isComplete) {
        await _search(
          operation: operation,
          sources: activeSources,
          hasPartialCoverage: false,
        );
        return;
      }
      await _prepare(operation, activeSources, mediaTypes);
    } catch (error) {
      if (mounted && operation == _operation) {
        state = state.copyWith(
          phase: ImageLookupFailure('Media lookup failed: $error'),
          isRunningInBackground: false,
        );
      }
    }
  }

  Future<void> _prepareVideoFrames(
    int operation,
    List<ImageLookupSource> sources,
  ) async {
    final cancellation = DuplicateScanCancellation();
    _cancellation = cancellation;
    await for (final progress in _prepareVideoFramesUseCase(
      cancellation: cancellation,
    )) {
      if (!mounted || operation != _operation) {
        return;
      }
      state = state.copyWith(
        phase: ImageLookupPreparing(sources: sources, progress: progress),
      );
    }
    if (!mounted || operation != _operation) {
      return;
    }
    final wasSkipped = _skipOperation == operation;
    _skipOperation = null;
    await _search(
      operation: operation,
      sources: sources,
      hasPartialCoverage: wasSkipped,
    );
  }

  Future<void> setLookupMode(MediaLookupMode mode) async {
    if (mode == state.lookupMode || state.isBusy) {
      return;
    }
    _operation++;
    _skipOperation = null;
    _cancellation?.cancel();
    await _releaseBookmarks();
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      lookupMode: mode,
      phase: const ImageLookupIdle(),
      isRunningInBackground: false,
    );
    await _saveLookupMode(mode);
  }

  Future<void> _restoreLookupMode() async {
    final operation = _operation;
    try {
      final mode = await _loadLookupMode!();
      if (mounted &&
          operation == _operation &&
          state.phase is ImageLookupIdle) {
        state = state.copyWith(lookupMode: mode);
      }
    } catch (_) {
      // The safe default remains active when preferences cannot be read.
    }
  }

  Future<void> _prepare(
    int operation,
    List<ImageLookupSource> sources,
    Set<MediaType> mediaTypes,
  ) async {
    final cancellation = DuplicateScanCancellation();
    _cancellation = cancellation;
    await for (final progress in _scanUseCase(
      cancellation: cancellation,
      mediaTypes: mediaTypes,
    )) {
      if (!mounted || operation != _operation) {
        return;
      }
      state = state.copyWith(
        phase: ImageLookupPreparing(sources: sources, progress: progress),
      );
    }
    if (!mounted || operation != _operation) {
      return;
    }
    final wasSkipped = _skipOperation == operation;
    _skipOperation = null;
    await _search(
      operation: operation,
      sources: sources,
      hasPartialCoverage: wasSkipped,
    );
  }

  void skipPreparation() {
    if (state.phase is! ImageLookupPreparing) {
      return;
    }
    _skipOperation = _operation;
    _cancellation?.cancel();
  }

  Future<void> cancel() async {
    _operation++;
    _skipOperation = null;
    _cancellation?.cancel();
    state = state.copyWith(
      phase: const ImageLookupIdle(),
      isRunningInBackground: false,
    );
    await _releaseBookmarks();
  }

  void runInBackground() {
    if (!state.isBusy) {
      return;
    }
    state = state.copyWith(isRunningInBackground: true);
  }

  void markForeground() {
    if (state.isRunningInBackground) {
      state = state.copyWith(isRunningInBackground: false);
    }
  }

  Future<void> _search({
    required int operation,
    required List<ImageLookupSource> sources,
    required bool hasPartialCoverage,
  }) async {
    final cancellation = DuplicateScanCancellation();
    _cancellation = cancellation;
    state = state.copyWith(
      phase: ImageLookupSearching(
        sources: sources,
        processed: 0,
        total: sources.length,
        hasPartialCoverage: hasPartialCoverage,
      ),
    );
    final batch = await _findMatchesUseCase(
      sources: sources,
      sensitivity: state.sensitivity,
      lookupMode: state.lookupMode,
      cancellation: cancellation,
      onProgress: (processed, total) {
        if (!mounted || operation != _operation) {
          return;
        }
        state = state.copyWith(
          phase: ImageLookupSearching(
            sources: sources,
            processed: processed,
            total: total,
            hasPartialCoverage: hasPartialCoverage,
          ),
        );
      },
    );
    if (!mounted || operation != _operation || cancellation.isCancelled) {
      return;
    }

    final session = ImageLookupSession(
      id: _uuid.v4(),
      profileId: _profileId,
      createdAt: DateTime.now(),
      sensitivity: state.sensitivity,
      lookupMode: state.lookupMode,
      results: batch.results,
      hasPartialCoverage: hasPartialCoverage,
      searchedLibraryImages: batch.searchedLibraryImages,
    );
    state = state.copyWith(
      phase: ImageLookupResults(session: session),
      isRunningInBackground: false,
    );
    await _persistIfEnabled(session);
  }

  Future<void> setSensitivity(DuplicateSensitivity sensitivity) async {
    if (sensitivity == state.sensitivity) {
      return;
    }
    final phase = state.phase;
    state = state.copyWith(sensitivity: sensitivity);
    if (phase is! ImageLookupResults || phase.isHistorySnapshot) {
      return;
    }

    final operation = ++_operation;
    _cancellation?.cancel();
    final queries = phase.session.results
        .map((result) => result.query)
        .whereType<ImageLookupQuery>()
        .toList(growable: false);
    final failedByPath = <String, ImageLookupResult>{
      for (final result in phase.session.results)
        if (result.query == null) result.source.path: result,
    };
    final sources = phase.session.results
        .map((result) => result.source)
        .toList(growable: false);
    final cancellation = DuplicateScanCancellation();
    _cancellation = cancellation;
    state = state.copyWith(
      phase: ImageLookupSearching(
        sources: sources,
        processed: 0,
        total: queries.length,
        hasPartialCoverage: phase.session.hasPartialCoverage,
      ),
    );
    try {
      final batch = await _findMatchesUseCase.rematch(
        queries: queries,
        sensitivity: sensitivity,
        lookupMode: phase.session.lookupMode,
        cancellation: cancellation,
        onProgress: (processed, total) {
          if (!mounted || operation != _operation) {
            return;
          }
          state = state.copyWith(
            phase: ImageLookupSearching(
              sources: sources,
              processed: processed,
              total: total,
              hasPartialCoverage: phase.session.hasPartialCoverage,
            ),
          );
        },
      );
      if (!mounted || operation != _operation || cancellation.isCancelled) {
        return;
      }
      final matchedByPath = <String, ImageLookupResult>{
        for (final result in batch.results) result.source.path: result,
      };
      final results = <ImageLookupResult>[
        for (final previous in phase.session.results)
          failedByPath[previous.source.path] ??
              matchedByPath[previous.source.path]!,
      ];
      final session = phase.session.copyWith(
        sensitivity: sensitivity,
        results: results,
        searchedLibraryImages: batch.searchedLibraryImages,
      );
      state = state.copyWith(phase: ImageLookupResults(session: session));
      await _persistIfEnabled(session);
    } catch (error) {
      if (mounted && operation == _operation) {
        state = state.copyWith(
          phase: ImageLookupFailure('Could not update sensitivity: $error'),
        );
      }
    }
  }

  Future<void> openHistory(ImageLookupSession session) async {
    final operation = ++_operation;
    _cancellation?.cancel();
    await _releaseBookmarks();
    final sources = await _activateSources(
      session.results.map((result) => result.source).toList(growable: false),
    );
    if (!mounted || operation != _operation) {
      return;
    }
    final results = <ImageLookupResult>[
      for (var index = 0; index < session.results.length; index++)
        session.results[index].copyWith(
          source: sources[index],
          query: session.results[index].query?.copyWith(source: sources[index]),
        ),
    ];
    final activeSession = session.copyWith(results: results);
    state = state.copyWith(
      phase: ImageLookupResults(
        session: activeSession,
        isHistorySnapshot: true,
      ),
      sensitivity: session.sensitivity,
      lookupMode: session.lookupMode,
      isRunningInBackground: false,
    );
    await _saveLookupMode(session.lookupMode);
  }

  Set<MediaType> get _allowedQueryMediaTypes {
    return state.lookupMode == MediaLookupMode.videoFromFrame
        ? const <MediaType>{MediaType.image}
        : const <MediaType>{MediaType.image, MediaType.video};
  }

  Future<void> deleteHistory(String sessionId) async {
    await _historyRepository.delete(sessionId);
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      history: state.history
          .where((session) => session.id != sessionId)
          .toList(growable: false),
    );
  }

  Future<void> clearHistory() async {
    await _historyRepository.clear(_profileId);
    if (mounted) {
      state = state.copyWith(history: const <ImageLookupSession>[]);
    }
  }

  Future<void> _persistIfEnabled(ImageLookupSession session) async {
    if (!_isHistoryEnabled()) {
      return;
    }
    try {
      await _historyRepository.save(session);
      await _loadHistory();
    } catch (_) {
      // History failure is non-fatal and must not hide completed results.
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _historyRepository.load(_profileId);
      if (mounted) {
        state = state.copyWith(history: history, isHistoryLoading: false);
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isHistoryLoading: false);
      }
    }
  }

  Future<List<ImageLookupSource>> _activateSources(
    List<ImageLookupSource> sources,
  ) async {
    final active = <ImageLookupSource>[];
    for (final source in sources) {
      final bookmarkData = source.bookmarkData;
      if (bookmarkData == null || bookmarkData.isEmpty) {
        active.add(source);
        continue;
      }
      try {
        final resolvedPath = await _bookmarkService.startAccessingBookmark(
          bookmarkData,
        );
        _activeBookmarks.add(bookmarkData);
        active.add(source.copyWith(path: resolvedPath));
      } catch (_) {
        active.add(source);
      }
    }
    return List<ImageLookupSource>.unmodifiable(active);
  }

  Future<void> _releaseBookmarks() async {
    final bookmarks = List<String>.from(_activeBookmarks);
    _activeBookmarks.clear();
    for (final bookmark in bookmarks) {
      await _bookmarkService.stopAccessingBookmark(bookmark);
    }
  }

  @override
  void dispose() {
    _operation++;
    _cancellation?.cancel();
    unawaited(_releaseBookmarks());
    super.dispose();
  }
}

final imageLookupViewModelProvider =
    StateNotifierProvider<ImageLookupViewModel, ImageLookupViewState>((ref) {
      final profileId = ref.watch(activeProfileIdProvider);
      final initialLookupMode = ref.read(mediaLookupModeProvider);
      return ImageLookupViewModel(
        profileId: profileId,
        scanUseCase: ref.watch(scanForDuplicatesUseCaseProvider),
        coverageUseCase: ref.watch(getDuplicateLibraryCoverageUseCaseProvider),
        videoFrameCoverageUseCase: ref.watch(
          getVideoFrameIndexCoverageUseCaseProvider,
        ),
        prepareVideoFramesUseCase: ref.watch(
          prepareVideoFrameIndexUseCaseProvider,
        ),
        findMatchesUseCase: ref.watch(findImageMatchesUseCaseProvider),
        filePicker: ref.watch(mediaLookupFilePickerProvider),
        historyRepository: ref.watch(imageLookupHistoryRepositoryProvider),
        bookmarkService: ref.watch(bookmarkServiceProvider),
        isHistoryEnabled: () => ref.read(imageLookupHistoryEnabledProvider),
        saveLookupMode: (mode) => ref
            .read(settingsViewModelProvider.notifier)
            .updateMediaLookupMode(mode),
        loadLookupMode: () async {
          final settings = await ref.read(settingsViewModelProvider.future);
          return settings.mediaLookupMode;
        },
        initialLookupMode: initialLookupMode,
      );
    });

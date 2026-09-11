import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/models/media_lookup_mode.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';
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
import '../../domain/entities/image_lookup_progress.dart';
import '../../domain/entities/image_lookup_result.dart';
import '../../domain/entities/image_lookup_session.dart';
import '../../domain/entities/image_lookup_source.dart';
import '../../domain/entities/image_lookup_update.dart';
import '../../domain/entities/image_lookup_verification_summary.dart';
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
  ImageLookupSearching({
    required this.sources,
    required this.progress,
    required this.hasPartialCoverage,
    List<ImageLookupResult> results = const <ImageLookupResult>[],
    this.verificationSummary,
    this.startedAt,
  }) : results = List<ImageLookupResult>.unmodifiable(results);

  final List<ImageLookupSource> sources;
  final ImageLookupProgress progress;
  final bool hasPartialCoverage;
  final List<ImageLookupResult> results;
  final ImageLookupVerificationSummary? verificationSummary;
  final DateTime? startedAt;
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
  const ImageLookupFailure(
    this.message, {
    this.sources = const <ImageLookupSource>[],
  });

  final String message;
  final List<ImageLookupSource> sources;
}

/// Route-independent state for lookup progress, results, and saved history.
class ImageLookupViewState {
  const ImageLookupViewState({
    this.phase = const ImageLookupIdle(),
    this.sensitivity = DuplicateSensitivity.balanced,
    this.lookupMode = MediaLookupMode.mediaMatches,
    this.lookupPrecision = VideoFrameLookupPrecision.standard,
    this.history = const <ImageLookupSession>[],
    this.isHistoryLoading = true,
    this.isRunningInBackground = false,
  });

  final ImageLookupPhase phase;
  final DuplicateSensitivity sensitivity;
  final MediaLookupMode lookupMode;
  final VideoFrameLookupPrecision lookupPrecision;
  final List<ImageLookupSession> history;
  final bool isHistoryLoading;
  final bool isRunningInBackground;

  bool get isBusy =>
      phase is ImageLookupPreparing || phase is ImageLookupSearching;

  ImageLookupViewState copyWith({
    ImageLookupPhase? phase,
    DuplicateSensitivity? sensitivity,
    MediaLookupMode? lookupMode,
    VideoFrameLookupPrecision? lookupPrecision,
    List<ImageLookupSession>? history,
    bool? isHistoryLoading,
    bool? isRunningInBackground,
  }) {
    return ImageLookupViewState(
      phase: phase ?? this.phase,
      sensitivity: sensitivity ?? this.sensitivity,
      lookupMode: lookupMode ?? this.lookupMode,
      lookupPrecision: lookupPrecision ?? this.lookupPrecision,
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
    Future<void> Function(VideoFrameLookupPrecision precision)?
    saveLookupPrecision,
    Future<VideoFrameLookupPrecision> Function()? loadLookupPrecision,
    VideoFrameLookupPrecision initialLookupPrecision =
        VideoFrameLookupPrecision.standard,
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
       _saveLookupPrecision = saveLookupPrecision,
       _loadLookupPrecision = loadLookupPrecision,
       _uuid = uuid,
       super(
         ImageLookupViewState(
           lookupMode: initialLookupMode,
           lookupPrecision: initialLookupPrecision,
         ),
       ) {
    unawaited(_loadHistory());
    if (_loadLookupMode != null) {
      unawaited(_restoreLookupMode());
    }
    if (_loadLookupPrecision != null) {
      unawaited(_restoreLookupPrecision());
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
  final Future<void> Function(VideoFrameLookupPrecision precision)?
  _saveLookupPrecision;
  final Future<VideoFrameLookupPrecision> Function()? _loadLookupPrecision;
  final Uuid _uuid;

  DuplicateScanCancellation? _cancellation;
  final List<String> _activeBookmarks = <String>[];
  int _operation = 0;
  VideoFrameLookupPrecision? _pendingSettingsPrecision;

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
        final coverage = await _videoFrameCoverageUseCase(
          lookupPrecision: state.lookupPrecision,
        );
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
    DuplicateScanProgress? lastProgress;
    await for (final progress in _prepareVideoFramesUseCase(
      cancellation: cancellation,
      lookupPrecision: state.lookupPrecision,
    )) {
      lastProgress = progress;
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
    if ((lastProgress?.failed ?? 0) > 0) {
      state = state.copyWith(
        phase: ImageLookupFailure(
          '${lastProgress!.failed} video${lastProgress.failed == 1 ? '' : 's'} '
          'could not be indexed. Retry preparation or choose new media.',
          sources: sources,
        ),
        isRunningInBackground: false,
      );
      return;
    }
    await _search(
      operation: operation,
      sources: sources,
      hasPartialCoverage: false,
    );
  }

  /// Retries a failed video-frame preparation using the originally selected
  /// sources, keeping the failure screen actionable without reopening the
  /// picker.
  Future<void> retryPreparation() async {
    final phase = state.phase;
    if (phase is! ImageLookupFailure || phase.sources.isEmpty || state.isBusy) {
      return;
    }
    await startLookup(List<ImageLookupSource>.from(phase.sources));
  }

  Future<void> setLookupMode(MediaLookupMode mode) async {
    if (mode == state.lookupMode || state.isBusy) {
      return;
    }
    _operation++;
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

  /// Changes the tier for the next video-from-frame search.
  ///
  /// A completed result remains visible until [searchAgain] is selected. This
  /// avoids unexpectedly starting a potentially long every-frame indexing pass
  /// from a settings toggle.
  Future<void> setLookupPrecision(VideoFrameLookupPrecision precision) async {
    if (precision == state.lookupPrecision || state.isBusy) {
      return;
    }
    state = state.copyWith(lookupPrecision: precision);
    final save = _saveLookupPrecision;
    if (save != null) {
      await save(precision);
    }
  }

  /// Applies a settings change without writing it back through the settings
  /// repository. Busy operations keep their captured tier and apply the new
  /// preference as soon as they finish, making the next search explicit.
  void syncLookupPrecisionFromSettings(VideoFrameLookupPrecision precision) {
    if (state.isBusy) {
      _pendingSettingsPrecision = precision;
      return;
    }
    _pendingSettingsPrecision = null;
    if (precision != state.lookupPrecision) {
      state = state.copyWith(lookupPrecision: precision);
    }
  }

  bool get canSearchAgain {
    final phase = state.phase;
    return phase is ImageLookupResults &&
        !phase.isHistorySnapshot &&
        state.lookupMode == MediaLookupMode.videoFromFrame &&
        phase.session.lookupPrecision != state.lookupPrecision;
  }

  Future<void> searchAgain() async {
    final phase = state.phase;
    if (phase is! ImageLookupResults ||
        phase.isHistorySnapshot ||
        state.isBusy) {
      return;
    }
    await startLookup(
      phase.session.results
          .map((result) => result.source)
          .toList(growable: false),
    );
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

  Future<void> _restoreLookupPrecision() async {
    final operation = _operation;
    try {
      final precision = await _loadLookupPrecision!();
      if (mounted &&
          operation == _operation &&
          state.phase is ImageLookupIdle) {
        state = state.copyWith(lookupPrecision: precision);
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
    await _search(
      operation: operation,
      sources: sources,
      hasPartialCoverage: false,
    );
  }

  /// Stops preparation and immediately searches indexes already marked
  /// complete. Cleanup for the abandoned preparation continues independently.
  void skipPreparation() {
    final phase = state.phase;
    if (phase is! ImageLookupPreparing) {
      return;
    }
    final preparationCancellation = _cancellation;
    final searchOperation = ++_operation;
    preparationCancellation?.cancel();
    unawaited(
      _searchAfterSkippedPreparation(
        operation: searchOperation,
        sources: phase.sources,
      ),
    );
  }

  Future<void> _searchAfterSkippedPreparation({
    required int operation,
    required List<ImageLookupSource> sources,
  }) async {
    try {
      await _search(
        operation: operation,
        sources: sources,
        hasPartialCoverage: true,
      );
    } catch (error) {
      if (mounted && operation == _operation) {
        state = state.copyWith(
          phase: ImageLookupFailure('Media lookup failed: $error'),
          isRunningInBackground: false,
        );
      }
    }
  }

  Future<void> cancel() async {
    _operation++;
    _cancellation?.cancel();
    state = state.copyWith(
      phase: const ImageLookupIdle(),
      isRunningInBackground: false,
    );
    final pendingPrecision = _pendingSettingsPrecision;
    _pendingSettingsPrecision = null;
    if (pendingPrecision != null && pendingPrecision != state.lookupPrecision) {
      state = state.copyWith(lookupPrecision: pendingPrecision);
    }
    await _releaseBookmarks();
  }

  /// Stops active verification while preserving the results received so far.
  ///
  /// Unlike [cancel], this creates a clearly marked partial history snapshot.
  /// The operation token is advanced before cancelling so late native or
  /// repository callbacks cannot overwrite the saved snapshot.
  Future<void> stopAndKeepResults() async {
    final phase = state.phase;
    if (phase is! ImageLookupSearching) {
      return;
    }
    final operation = ++_operation;
    _cancellation?.cancel();
    // Progress totals can represent queries or a shortlist batch, not the
    // eligible-video population. When native verification has not supplied a
    // summary yet, keep counts unknown instead of presenting those totals as
    // video counts.
    final summary =
        (phase.verificationSummary ?? const ImageLookupVerificationSummary())
            .copyWith(stopped: true);
    final session = ImageLookupSession(
      id: _uuid.v4(),
      profileId: _profileId,
      createdAt: DateTime.now(),
      sensitivity: state.sensitivity,
      lookupMode: state.lookupMode,
      lookupPrecision: state.lookupPrecision,
      results: List<ImageLookupResult>.unmodifiable(phase.results),
      hasPartialCoverage: phase.hasPartialCoverage,
      searchedLibraryImages: summary.eligibleVideoCount,
      verificationSummary: summary,
    );
    if (!mounted || operation != _operation) {
      return;
    }
    state = state.copyWith(
      phase: ImageLookupResults(session: session),
      isRunningInBackground: false,
    );
    final pendingPrecision = _pendingSettingsPrecision;
    _pendingSettingsPrecision = null;
    if (pendingPrecision != null && pendingPrecision != state.lookupPrecision) {
      state = state.copyWith(lookupPrecision: pendingPrecision);
    }
    await _persistIfEnabled(session);
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
    final startedAt = DateTime.now();
    state = state.copyWith(
      phase: ImageLookupSearching(
        sources: sources,
        progress: ImageLookupProgress.preparingQueries(
          processed: 0,
          total: sources.length,
        ),
        hasPartialCoverage: hasPartialCoverage,
        startedAt: startedAt,
      ),
    );
    final batch = await _findMatchesUseCase(
      sources: sources,
      sensitivity: state.sensitivity,
      lookupMode: state.lookupMode,
      lookupPrecision: state.lookupPrecision,
      cancellation: cancellation,
      onUpdate: (update) {
        if (!mounted || operation != _operation || cancellation.isCancelled) {
          return;
        }
        _applySearchUpdate(
          operation: operation,
          sources: sources,
          hasPartialCoverage: hasPartialCoverage,
          startedAt: startedAt,
          update: update,
        );
      },
      onProgress: (progress) {
        if (!mounted || operation != _operation) {
          return;
        }
        final currentPhase = state.phase;
        state = state.copyWith(
          phase: ImageLookupSearching(
            sources: sources,
            progress: progress,
            hasPartialCoverage: hasPartialCoverage,
            results: currentPhase is ImageLookupSearching
                ? currentPhase.results
                : const <ImageLookupResult>[],
            verificationSummary: currentPhase is ImageLookupSearching
                ? currentPhase.verificationSummary
                : null,
            startedAt: startedAt,
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
      lookupPrecision: state.lookupPrecision,
      results: batch.results,
      hasPartialCoverage: hasPartialCoverage,
      searchedLibraryImages: batch.searchedLibraryImages,
      verificationSummary: batch.verificationSummary,
    );
    state = state.copyWith(
      phase: ImageLookupResults(session: session),
      isRunningInBackground: false,
    );
    final pendingPrecision = _pendingSettingsPrecision;
    _pendingSettingsPrecision = null;
    if (pendingPrecision != null && pendingPrecision != state.lookupPrecision) {
      state = state.copyWith(lookupPrecision: pendingPrecision);
    }
    await _persistIfEnabled(session);
  }

  void _applySearchUpdate({
    required int operation,
    required List<ImageLookupSource> sources,
    required bool hasPartialCoverage,
    required DateTime startedAt,
    required ImageLookupUpdate update,
  }) {
    if (!mounted || operation != _operation) {
      return;
    }
    state = state.copyWith(
      phase: ImageLookupSearching(
        sources: sources,
        progress: update.progress,
        hasPartialCoverage: hasPartialCoverage,
        results: update.results,
        verificationSummary: update.verificationSummary,
        startedAt: startedAt,
      ),
    );
  }

  Future<void> setSensitivity(DuplicateSensitivity sensitivity) async {
    if (sensitivity == state.sensitivity || state.isBusy) {
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
    final phaseStartedAt = DateTime.now();
    state = state.copyWith(
      phase: ImageLookupSearching(
        sources: sources,
        progress: ImageLookupProgress(
          stage: ImageLookupProgressStage.searchingIndexedMedia,
          processed: 0,
          total: queries.length,
        ),
        hasPartialCoverage: phase.session.hasPartialCoverage,
        results: phase.session.results,
        verificationSummary: phase.session.verificationSummary,
        startedAt: phaseStartedAt,
      ),
    );
    try {
      final batch = await _findMatchesUseCase.rematch(
        queries: queries,
        sensitivity: sensitivity,
        lookupMode: phase.session.lookupMode,
        lookupPrecision: phase.session.lookupPrecision,
        cancellation: cancellation,
        onUpdate: (update) {
          if (!mounted || operation != _operation || cancellation.isCancelled) {
            return;
          }
          _applySearchUpdate(
            operation: operation,
            sources: sources,
            hasPartialCoverage: phase.session.hasPartialCoverage,
            startedAt: phaseStartedAt,
            update: update,
          );
        },
        onProgress: (progress) {
          if (!mounted || operation != _operation) {
            return;
          }
          final currentPhase = state.phase;
          final currentResults = currentPhase is ImageLookupSearching
              ? currentPhase.results
              : phase.session.results;
          final currentSummary = currentPhase is ImageLookupSearching
              ? currentPhase.verificationSummary
              : phase.session.verificationSummary;
          state = state.copyWith(
            phase: ImageLookupSearching(
              sources: sources,
              progress: progress,
              hasPartialCoverage: phase.session.hasPartialCoverage,
              results: currentResults,
              verificationSummary: currentSummary,
              startedAt: phaseStartedAt,
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
        verificationSummary: batch.verificationSummary,
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
      lookupPrecision: session.lookupPrecision,
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
      final initialLookupPrecision = ref.read(
        videoFrameLookupPrecisionProvider,
      );
      final viewModel = ImageLookupViewModel(
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
        saveLookupPrecision: (precision) => ref
            .read(settingsViewModelProvider.notifier)
            .updateVideoFrameLookupPrecision(precision),
        loadLookupPrecision: () async {
          final settings = await ref.read(settingsViewModelProvider.future);
          return settings.videoFrameLookupPrecision;
        },
        initialLookupPrecision: initialLookupPrecision,
      );
      ref.listen<VideoFrameLookupPrecision>(
        videoFrameLookupPrecisionProvider,
        (_, precision) => viewModel.syncLookupPrecisionFromSettings(precision),
      );
      return viewModel;
    });

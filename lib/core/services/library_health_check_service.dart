import 'dart:async';

import 'package:path/path.dart' as p;

import '../../features/media_library/data/data_sources/local_directory_data_source.dart';
import '../../features/media_library/domain/entities/directory_entity.dart';
import '../../features/media_library/domain/repositories/directory_repository.dart';
import '../../shared/utils/directory_id_utils.dart';
import 'logging_service.dart';
import 'permission_service.dart';

/// Summary information about a health check execution.
class HealthCheckSummary {
  const HealthCheckSummary({
    required this.inProgress,
    required this.startedAt,
    this.completedAt,
    this.duration = Duration.zero,
    this.totalDirectories = 0,
    this.accessibleCount = 0,
    this.permissionIssueCount = 0,
    this.bookmarkIssueCount = 0,
    this.idMismatchCount = 0,
    this.repairedCount = 0,
  });

  final bool inProgress;
  final DateTime startedAt;
  final DateTime? completedAt;
  final Duration duration;
  final int totalDirectories;
  final int accessibleCount;
  final int permissionIssueCount;
  final int bookmarkIssueCount;
  final int idMismatchCount;
  final int repairedCount;

  HealthCheckSummary copyWith({
    bool? inProgress,
    DateTime? startedAt,
    DateTime? completedAt,
    Duration? duration,
    int? totalDirectories,
    int? accessibleCount,
    int? permissionIssueCount,
    int? bookmarkIssueCount,
    int? idMismatchCount,
    int? repairedCount,
  }) {
    return HealthCheckSummary(
      inProgress: inProgress ?? this.inProgress,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      duration: duration ?? this.duration,
      totalDirectories: totalDirectories ?? this.totalDirectories,
      accessibleCount: accessibleCount ?? this.accessibleCount,
      permissionIssueCount: permissionIssueCount ?? this.permissionIssueCount,
      bookmarkIssueCount: bookmarkIssueCount ?? this.bookmarkIssueCount,
      idMismatchCount: idMismatchCount ?? this.idMismatchCount,
      repairedCount: repairedCount ?? this.repairedCount,
    );
  }
}

/// Report emitted by the scheduler describing the current health state.
class LibraryHealthCheckReport {
  const LibraryHealthCheckReport._({
    required this.summary,
    this.accessibleDirectories = const [],
    this.permissionRevokedDirectories = const [],
    this.bookmarkInvalidDirectories = const [],
    this.repairedDirectories = const [],
    this.idMismatchDirectories = const [],
  });

  factory LibraryHealthCheckReport.inProgress(HealthCheckSummary summary) {
    return LibraryHealthCheckReport._(summary: summary);
  }

  factory LibraryHealthCheckReport.completed({
    required HealthCheckSummary summary,
    required List<DirectoryEntity> accessibleDirectories,
    required List<DirectoryEntity> permissionRevokedDirectories,
    required List<DirectoryEntity> bookmarkInvalidDirectories,
    required List<DirectoryEntity> repairedDirectories,
    required List<DirectoryEntity> idMismatchDirectories,
  }) {
    return LibraryHealthCheckReport._(
      summary: summary,
      accessibleDirectories: accessibleDirectories,
      permissionRevokedDirectories: permissionRevokedDirectories,
      bookmarkInvalidDirectories: bookmarkInvalidDirectories,
      repairedDirectories: repairedDirectories,
      idMismatchDirectories: idMismatchDirectories,
    );
  }

  final HealthCheckSummary summary;
  final List<DirectoryEntity> accessibleDirectories;
  final List<DirectoryEntity> permissionRevokedDirectories;
  final List<DirectoryEntity> bookmarkInvalidDirectories;
  final List<DirectoryEntity> repairedDirectories;
  final List<DirectoryEntity> idMismatchDirectories;

  bool get inProgress => summary.inProgress;
}

class _DirectoryHealthResult {
  _DirectoryHealthResult({
    required this.originalDirectory,
    required this.currentDirectory,
    required this.accessible,
    required this.permissionRevoked,
    required this.bookmarkInvalid,
    required this.idMismatchDetected,
    required this.repaired,
  });

  final DirectoryEntity originalDirectory;
  final DirectoryEntity currentDirectory;
  final bool accessible;
  final bool permissionRevoked;
  final bool bookmarkInvalid;
  final bool idMismatchDetected;
  final bool repaired;
}

/// Periodically validates library state and emits reports describing results.
class LibraryHealthCheckScheduler {
  LibraryHealthCheckScheduler({
    required DirectoryRepository directoryRepository,
    required LocalDirectoryDataSource localDirectoryDataSource,
    required PermissionService permissionService,
    Duration interval = const Duration(minutes: 5),
    DateTime Function()? clock,
  })  : _directoryRepository = directoryRepository,
        _localDirectoryDataSource = localDirectoryDataSource,
        _permissionService = permissionService,
        _interval = interval,
        _clock = clock ?? DateTime.now;

  final DirectoryRepository _directoryRepository;
  final LocalDirectoryDataSource _localDirectoryDataSource;
  final PermissionService _permissionService;
  final Duration _interval;
  final DateTime Function() _clock;

  final StreamController<LibraryHealthCheckReport> _controller =
      StreamController<LibraryHealthCheckReport>.broadcast();

  Timer? _timer;
  bool _isRunning = false;
  bool _started = false;

  Stream<LibraryHealthCheckReport> get reports => _controller.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    await runHealthCheckNow();
    _timer = Timer.periodic(_interval, (_) => runHealthCheckNow());
  }

  Future<void> runHealthCheckNow() async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;
    final startedAt = _clock();

    try {
      final directories = await _directoryRepository.getDirectories();
      final inProgressSummary = HealthCheckSummary(
        inProgress: true,
        startedAt: startedAt,
        totalDirectories: directories.length,
      );
      _controller.add(LibraryHealthCheckReport.inProgress(inProgressSummary));
      LoggingService.instance.healthCheck('started', context: {
        'directories': directories.length,
      });

      final results = <_DirectoryHealthResult>[];
      for (final directory in directories) {
        final result = await _checkDirectory(directory);
        results.add(result);
      }

      final accessible = results
          .where((result) =>
              result.accessible &&
              !result.permissionRevoked &&
              !result.bookmarkInvalid)
          .map((result) => result.currentDirectory)
          .toList();
      final permissionRevoked = results
          .where((result) => result.permissionRevoked)
          .map((result) => result.currentDirectory)
          .toList();
      final bookmarkInvalid = results
          .where((result) => result.bookmarkInvalid)
          .map((result) => result.currentDirectory)
          .toList();
      final idMismatches = results
          .where((result) => result.idMismatchDetected)
          .map((result) => result.currentDirectory)
          .toList();
      final repaired = results
          .where((result) => result.repaired)
          .map((result) => result.currentDirectory)
          .toList();

      final completedAt = _clock();
      final summary = HealthCheckSummary(
        inProgress: false,
        startedAt: startedAt,
        completedAt: completedAt,
        duration: completedAt.difference(startedAt),
        totalDirectories: directories.length,
        accessibleCount: accessible.length,
        permissionIssueCount: permissionRevoked.length,
        bookmarkIssueCount: bookmarkInvalid.length,
        idMismatchCount: idMismatches.length,
        repairedCount: repaired.length,
      );

      LoggingService.instance.healthCheck('completed', context: {
        'durationMs': summary.duration.inMilliseconds,
        'accessible': summary.accessibleCount,
        'permissionIssues': summary.permissionIssueCount,
        'bookmarkIssues': summary.bookmarkIssueCount,
        'idMismatches': summary.idMismatchCount,
        'repaired': summary.repairedCount,
      });

      _controller.add(
        LibraryHealthCheckReport.completed(
          summary: summary,
          accessibleDirectories: accessible,
          permissionRevokedDirectories: permissionRevoked,
          bookmarkInvalidDirectories: bookmarkInvalid,
          repairedDirectories: repaired,
          idMismatchDirectories: idMismatches,
        ),
      );
    } catch (error, stackTrace) {
      LoggingService.instance.healthCheck(
        'failed',
        level: LogLevel.error,
        context: {
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        },
      );
    } finally {
      _isRunning = false;
    }
  }

  Future<_DirectoryHealthResult> _checkDirectory(
    DirectoryEntity directory,
  ) async {
    DirectoryEntity current = directory;
    var bookmarkInvalid = false;
    var permissionRevoked = false;
    var idMismatchDetected = false;
    var repaired = false;

    try {
      final bookmarkData = current.bookmarkData;
      if (bookmarkData != null && bookmarkData.isNotEmpty) {
        final bookmarkValidation = await _permissionService
            .validateAndRenewBookmark(bookmarkData, current.path);

        if (bookmarkValidation.renewedBookmarkData != null &&
            bookmarkValidation.renewedBookmarkData != bookmarkData) {
          await _directoryRepository.updateDirectoryBookmark(
            current.id,
            bookmarkValidation.renewedBookmarkData,
          );
          current = current.copyWith(
            bookmarkData: bookmarkValidation.renewedBookmarkData,
          );
          repaired = true;
        }

        if (bookmarkValidation.resolvedPath != null &&
            bookmarkValidation.resolvedPath!.isNotEmpty &&
            bookmarkValidation.resolvedPath != current.path) {
          final updated = await _directoryRepository.updateDirectoryPathAndId(
            current.id,
            bookmarkValidation.resolvedPath!,
          );
          current = updated ??
              current.copyWith(
                path: bookmarkValidation.resolvedPath!,
                id: generateDirectoryId(bookmarkValidation.resolvedPath!),
                name: p.basename(bookmarkValidation.resolvedPath!),
              );
          repaired = true;
          idMismatchDetected = true;
        }

        if (!bookmarkValidation.isValid) {
          bookmarkInvalid = true;
        }
      }

      final expectedId = generateDirectoryId(current.path);
      if (expectedId != current.id) {
        final updated = await _directoryRepository.updateDirectoryPathAndId(
          current.id,
          current.path,
        );
        current = updated ?? current.copyWith(id: expectedId);
        idMismatchDetected = true;
        repaired = true;
      }

      if (bookmarkInvalid) {
        permissionRevoked = true;
        return _DirectoryHealthResult(
          originalDirectory: directory,
          currentDirectory: current,
          accessible: false,
          permissionRevoked: true,
          bookmarkInvalid: true,
          idMismatchDetected: idMismatchDetected,
          repaired: repaired,
        );
      }

      final accessible = await _localDirectoryDataSource.validateDirectory(current);
      if (!accessible) {
        final status = await _permissionService.checkDirectoryAccess(current.path);
        permissionRevoked = status == PermissionStatus.denied ||
            status == PermissionStatus.error ||
            status == PermissionStatus.notFound;
      }

      return _DirectoryHealthResult(
        originalDirectory: directory,
        currentDirectory: current,
        accessible: accessible,
        permissionRevoked: permissionRevoked,
        bookmarkInvalid: bookmarkInvalid,
        idMismatchDetected: idMismatchDetected,
        repaired: repaired,
      );
    } catch (error) {
      LoggingService.instance.healthCheck(
        'directory_check_failed',
        level: LogLevel.error,
        context: {
          'directoryId': directory.id,
          'path': directory.path,
          'error': error.toString(),
        },
      );
      return _DirectoryHealthResult(
        originalDirectory: directory,
        currentDirectory: current,
        accessible: false,
        permissionRevoked: true,
        bookmarkInvalid: bookmarkInvalid,
        idMismatchDetected: idMismatchDetected,
        repaired: repaired,
      );
    }
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

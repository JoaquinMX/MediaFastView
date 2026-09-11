import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/video_frame_presentation_time.dart';

/// One candidate frame sent to native Vision verification.
class VisionFrameCandidateRequest {
  const VisionFrameCandidateRequest({
    required this.mediaId,
    required this.path,
    required this.timestamp,
    this.queryId,
    this.sourceFingerprint,
    this.verificationTimestamps = const <Duration>[],
    this.presentationTime,
    this.verificationPresentationTimes = const <VideoFramePresentationTime>[],
    this.bookmarkData,
  });

  final String mediaId;
  final String path;
  final Duration timestamp;

  /// Identifies the query when a native session verifies several queries.
  ///
  /// It is optional to retain compatibility with the original one-query
  /// matcher contract.
  final String? queryId;

  /// Stable source identity used by the native session frame-print cache.
  final String? sourceFingerprint;
  final List<Duration> verificationTimestamps;
  final VideoFramePresentationTime? presentationTime;
  final List<VideoFramePresentationTime> verificationPresentationTimes;
  final String? bookmarkData;
}

/// Authoritative Vision score and the actual AVFoundation timestamp returned.
class VisionFrameMatch {
  const VisionFrameMatch({
    required this.mediaId,
    required this.distance,
    required this.timestamp,
    this.queryId,
    this.positionPercent = 0,
    this.presentationTime,
  });

  final String mediaId;
  final double distance;
  final Duration timestamp;

  /// Identifies the originating query in a multi-query native session.
  final String? queryId;
  final int positionPercent;
  final VideoFramePresentationTime? presentationTime;
}

/// A query whose Vision feature prints are prepared once for a session.
class VisionSessionQuery {
  const VisionSessionQuery({
    required this.queryId,
    required this.path,
    this.bookmarkData,
    this.sourceFingerprint,
  });

  final String queryId;
  final String path;
  final String? bookmarkData;
  final String? sourceFingerprint;
}

/// A video that could not be verified while the rest of a batch continued.
class VisionSessionVideoFailure {
  const VisionSessionVideoFailure({
    required this.mediaId,
    required this.message,
  });

  final String mediaId;
  final String message;
}

/// Results and progress for one native session verification batch.
class VisionSessionBatchResult {
  const VisionSessionBatchResult({
    required this.matches,
    required this.failures,
    required this.verifiedVideoCount,
    this.completedVideoCount = 0,
  });

  final List<VisionFrameMatch> matches;
  final List<VisionSessionVideoFailure> failures;

  /// Number of videos finished, including individual failures.
  final int completedVideoCount;

  /// Number of videos that completed without a native verification failure.
  final int verifiedVideoCount;
}

/// Incremental result emitted after one video in a session batch finishes.
class VisionSessionBatchUpdate {
  const VisionSessionBatchUpdate({
    required this.sessionId,
    required this.requestId,
    required this.mediaId,
    required this.matches,
    required this.verifiedVideoCount,
    this.completedVideoCount = 0,
    this.failureMessage,
  });

  final String sessionId;
  final String requestId;
  final String mediaId;
  final List<VisionFrameMatch> matches;
  final int completedVideoCount;
  final int verifiedVideoCount;
  final String? failureMessage;
}

abstract interface class VisionFrameMatcher {
  Future<List<VisionFrameMatch>> match({
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  });
}

/// Optional extension implemented by native matchers that can cancel work
/// already running outside the Dart isolate.
abstract interface class CancellableVisionFrameMatcher
    implements VisionFrameMatcher {
  Future<List<VisionFrameMatch>> matchCancellable({
    required String requestId,
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  });

  Future<void> cancel(String requestId);
}

/// Session API used when multiple queries are verified against shared videos.
///
/// Implementations must retain query feature prints only for the lifetime of
/// the session. Candidate batches are intentionally finite so callers can
/// publish results and progress between batches.
abstract interface class SessionVisionFrameMatcher {
  Future<void> startSession({
    required String sessionId,
    required List<VisionSessionQuery> queries,
    DuplicateScanCancellation? cancellation,
  });

  Future<VisionSessionBatchResult> verifyBatch({
    required String sessionId,
    required String requestId,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
    void Function(VisionSessionBatchUpdate update)? onUpdate,
  });

  Future<void> endSession(String sessionId);

  Future<void> cancelSession(String sessionId);
}

/// Method-channel adapter for fixed-revision Apple Vision feature prints.
class NativeVisionFrameMatcher
    implements CancellableVisionFrameMatcher, SessionVisionFrameMatcher {
  NativeVisionFrameMatcher({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName) {
    _channel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static const String _channelName = 'com.joaquinmx.media_fast_view/thumbnails';

  final MethodChannel _channel;
  final Set<String> _cancelledRequestIds = <String>{};
  final Map<String, _VisionSessionUpdateRegistration> _sessionUpdateCallbacks =
      <String, _VisionSessionUpdateRegistration>{};

  @override
  Future<List<VisionFrameMatch>> match({
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) {
    return matchCancellable(
      requestId: 'vision-${DateTime.now().microsecondsSinceEpoch}',
      queryPath: queryPath,
      queryBookmarkData: queryBookmarkData,
      candidates: candidates,
      cancellation: cancellation,
    );
  }

  @override
  Future<List<VisionFrameMatch>> matchCancellable({
    required String requestId,
    required String queryPath,
    String? queryBookmarkData,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
  }) async {
    if (candidates.isEmpty) {
      return const <VisionFrameMatch>[];
    }
    if (cancellation?.isCancelled ?? false) {
      throw const VisionFrameMatchingCancelledException();
    }
    final removeCancellationListener = cancellation?.addListener(
      () => unawaited(cancel(requestId)),
    );
    var completed = false;
    try {
      if (cancellation?.isCancelled ?? false) {
        throw const VisionFrameMatchingCancelledException();
      }
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'matchVideoFrameVision',
        <String, dynamic>{
          'requestId': requestId,
          'queryPath': queryPath,
          if (queryBookmarkData != null) 'queryBookmarkData': queryBookmarkData,
          'candidates': candidates
              .map((candidate) {
                final exactVerificationTimes =
                    candidate.verificationPresentationTimes.length ==
                        candidate.verificationTimestamps.length
                    ? candidate.verificationPresentationTimes
                    : const <VideoFramePresentationTime>[];
                return <String, dynamic>{
                  'mediaId': candidate.mediaId,
                  'path': candidate.path,
                  'timestampMilliseconds': candidate.timestamp.inMilliseconds,
                  if (candidate.presentationTime != null)
                    'presentationTimeValue': candidate.presentationTime!.value,
                  if (candidate.presentationTime != null)
                    'presentationTimeScale':
                        candidate.presentationTime!.timescale,
                  'verificationTimestampMilliseconds': candidate
                      .verificationTimestamps
                      .map((timestamp) => timestamp.inMilliseconds)
                      .toList(growable: false),
                  'verificationPresentationTimes': exactVerificationTimes
                      .map(
                        (time) => <String, int>{
                          'value': time.value,
                          'timescale': time.timescale,
                        },
                      )
                      .toList(growable: false),
                  if (candidate.bookmarkData != null)
                    'bookmarkData': candidate.bookmarkData,
                };
              })
              .toList(growable: false),
        },
      );
      final rawMatches = response?['matches'];
      if (rawMatches is! List) {
        throw const FormatException('Native Vision response was incomplete');
      }
      final matches = <VisionFrameMatch>[];
      for (final rawMatch in rawMatches) {
        if (rawMatch is! Map) {
          throw const FormatException('Native Vision match was malformed');
        }
        final mediaId = rawMatch['mediaId'];
        final distance = rawMatch['visionDistance'];
        final timestampMilliseconds = rawMatch['timestampMilliseconds'];
        final positionPercent = rawMatch['positionPercent'];
        if (mediaId is! String ||
            distance is! num ||
            timestampMilliseconds is! int ||
            (positionPercent != null && positionPercent is! int)) {
          throw const FormatException('Native Vision match was incomplete');
        }
        final presentationTime = _parsePresentationTime(rawMatch);
        matches.add(
          VisionFrameMatch(
            mediaId: mediaId,
            distance: distance.toDouble(),
            timestamp: Duration(milliseconds: timestampMilliseconds),
            positionPercent: (positionPercent as int?) ?? 0,
            presentationTime: presentationTime,
          ),
        );
      }
      completed = true;
      return List<VisionFrameMatch>.unmodifiable(matches);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELLED') {
        throw const VisionFrameMatchingCancelledException();
      }
      rethrow;
    } finally {
      removeCancellationListener?.call();
      if (!completed) {
        try {
          await cancel(requestId);
        } catch (_) {
          // Native cleanup is best effort when the platform channel is gone.
        }
      }
    }
  }

  VideoFramePresentationTime? _parsePresentationTime(Map rawMatch) {
    final value = rawMatch['presentationTimeValue'];
    final scale = rawMatch['presentationTimeScale'];
    if (value is! int || scale is! int || scale == 0) {
      return null;
    }
    return VideoFramePresentationTime(value: value, timescale: scale);
  }

  @override
  Future<void> cancel(String requestId) async {
    if (!_cancelledRequestIds.add(requestId)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelThumbnail', <String, dynamic>{
        'requestId': requestId,
      });
    } on MissingPluginException {
      // Tests and unsupported platforms have no native work to cancel.
    } catch (_) {
      // Cancellation is best effort when the platform channel is unavailable.
    } finally {
      _cancelledRequestIds.remove(requestId);
    }
  }

  @override
  Future<void> startSession({
    required String sessionId,
    required List<VisionSessionQuery> queries,
    DuplicateScanCancellation? cancellation,
  }) async {
    if (cancellation?.isCancelled ?? false) {
      throw const VisionFrameMatchingCancelledException();
    }
    final removeCancellationListener = cancellation?.addListener(
      () => unawaited(cancelSession(sessionId)),
    );
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'startVisionSession',
        <String, dynamic>{
          'sessionId': sessionId,
          'queries': queries
              .map(
                (query) => <String, dynamic>{
                  'queryId': query.queryId,
                  'path': query.path,
                  if (query.bookmarkData != null)
                    'bookmarkData': query.bookmarkData,
                  if (query.sourceFingerprint != null)
                    'sourceFingerprint': query.sourceFingerprint,
                },
              )
              .toList(growable: false),
        },
      );
      if (response?['started'] != true) {
        throw const FormatException('Native Vision session did not start');
      }
    } on PlatformException catch (error) {
      if (error.code == 'CANCELLED') {
        throw const VisionFrameMatchingCancelledException();
      }
      rethrow;
    } finally {
      removeCancellationListener?.call();
    }
  }

  @override
  Future<VisionSessionBatchResult> verifyBatch({
    required String sessionId,
    required String requestId,
    required List<VisionFrameCandidateRequest> candidates,
    DuplicateScanCancellation? cancellation,
    void Function(VisionSessionBatchUpdate update)? onUpdate,
  }) async {
    if (candidates.isEmpty) {
      return const VisionSessionBatchResult(
        matches: <VisionFrameMatch>[],
        failures: <VisionSessionVideoFailure>[],
        verifiedVideoCount: 0,
        completedVideoCount: 0,
      );
    }
    if (cancellation?.isCancelled ?? false) {
      throw const VisionFrameMatchingCancelledException();
    }
    final removeCancellationListener = cancellation?.addListener(
      () => unawaited(cancel(requestId)),
    );
    if (onUpdate != null) {
      _sessionUpdateCallbacks[sessionId] = _VisionSessionUpdateRegistration(
        requestId: requestId,
        callback: onUpdate,
      );
    }
    var completed = false;
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'verifyVisionSessionBatch',
        <String, dynamic>{
          'sessionId': sessionId,
          'requestId': requestId,
          'candidates': candidates
              .map(_candidateArguments)
              .toList(growable: false),
        },
      );
      final rawMatches = response?['matches'];
      if (rawMatches is! List) {
        throw const FormatException(
          'Native Vision batch response was incomplete',
        );
      }
      final matches = <VisionFrameMatch>[];
      for (final rawMatch in rawMatches) {
        if (rawMatch is! Map) {
          throw const FormatException(
            'Native Vision batch match was malformed',
          );
        }
        matches.add(_parseMatch(rawMatch));
      }
      final failures = <VisionSessionVideoFailure>[];
      final rawFailures = response?['failures'];
      if (rawFailures is List) {
        for (final rawFailure in rawFailures) {
          if (rawFailure is! Map ||
              rawFailure['mediaId'] is! String ||
              rawFailure['message'] is! String) {
            throw const FormatException(
              'Native Vision batch failure was malformed',
            );
          }
          failures.add(
            VisionSessionVideoFailure(
              mediaId: rawFailure['mediaId'] as String,
              message: rawFailure['message'] as String,
            ),
          );
        }
      }
      final rawVerifiedCount = response?['verifiedVideoCount'];
      if (rawVerifiedCount is! int) {
        throw const FormatException(
          'Native Vision batch progress was incomplete',
        );
      }
      final rawCompletedCount = response?['completedVideoCount'];
      completed = true;
      return VisionSessionBatchResult(
        matches: List<VisionFrameMatch>.unmodifiable(matches),
        failures: List<VisionSessionVideoFailure>.unmodifiable(failures),
        completedVideoCount: rawCompletedCount is int
            ? rawCompletedCount
            : rawVerifiedCount + failures.length,
        verifiedVideoCount: rawVerifiedCount,
      );
    } on PlatformException catch (error) {
      if (error.code == 'CANCELLED') {
        throw const VisionFrameMatchingCancelledException();
      }
      rethrow;
    } finally {
      removeCancellationListener?.call();
      if (onUpdate != null) {
        final registration = _sessionUpdateCallbacks[sessionId];
        if (registration?.requestId == requestId) {
          _sessionUpdateCallbacks.remove(sessionId);
        }
      }
      if (!completed) {
        try {
          await cancel(requestId);
        } catch (_) {
          // Native cleanup is best effort when the platform channel is gone.
        }
      }
    }
  }

  @override
  Future<void> endSession(String sessionId) async {
    await _channel.invokeMethod<void>('endVisionSession', <String, dynamic>{
      'sessionId': sessionId,
    });
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    _sessionUpdateCallbacks.remove(sessionId);
    try {
      await _channel.invokeMethod<void>(
        'cancelVisionSession',
        <String, dynamic>{'sessionId': sessionId},
      );
    } on MissingPluginException {
      // Tests and unsupported platforms have no native session to cancel.
    }
  }

  Future<Object?> _handleNativeMethodCall(MethodCall call) async {
    if (call.method != 'visionSessionUpdate' || call.arguments is! Map) {
      return null;
    }
    final raw = call.arguments as Map;
    final sessionId = raw['sessionId'];
    final requestId = raw['requestId'];
    final mediaId = raw['mediaId'];
    final verifiedVideoCount = raw['verifiedVideoCount'];
    final completedVideoCount = raw['completedVideoCount'];
    if (sessionId is! String ||
        requestId is! String ||
        mediaId is! String ||
        verifiedVideoCount is! int ||
        (completedVideoCount != null && completedVideoCount is! int)) {
      return null;
    }
    final matches = <VisionFrameMatch>[];
    final rawMatches = raw['matches'];
    if (rawMatches is List) {
      for (final rawMatch in rawMatches) {
        if (rawMatch is! Map) {
          continue;
        }
        try {
          matches.add(_parseMatch(rawMatch));
        } on FormatException {
          // Ignore malformed deltas; the final response remains authoritative.
        }
      }
    }
    final failureMessage = raw['failureMessage'];
    final registration = _sessionUpdateCallbacks[sessionId];
    if (registration?.requestId != requestId) {
      return null;
    }
    registration!.callback(
      VisionSessionBatchUpdate(
        sessionId: sessionId,
        requestId: requestId,
        mediaId: mediaId,
        matches: List<VisionFrameMatch>.unmodifiable(matches),
        completedVideoCount: completedVideoCount is int
            ? completedVideoCount
            : verifiedVideoCount,
        verifiedVideoCount: verifiedVideoCount,
        failureMessage: failureMessage is String ? failureMessage : null,
      ),
    );
    return null;
  }

  Map<String, dynamic> _candidateArguments(
    VisionFrameCandidateRequest candidate,
  ) {
    final exactVerificationTimes =
        candidate.verificationPresentationTimes.length ==
            candidate.verificationTimestamps.length
        ? candidate.verificationPresentationTimes
        : const <VideoFramePresentationTime>[];
    return <String, dynamic>{
      'mediaId': candidate.mediaId,
      'path': candidate.path,
      'timestampMilliseconds': candidate.timestamp.inMilliseconds,
      if (candidate.queryId != null) 'queryId': candidate.queryId,
      if (candidate.sourceFingerprint != null)
        'sourceFingerprint': candidate.sourceFingerprint,
      if (candidate.presentationTime != null)
        'presentationTimeValue': candidate.presentationTime!.value,
      if (candidate.presentationTime != null)
        'presentationTimeScale': candidate.presentationTime!.timescale,
      'verificationTimestampMilliseconds': candidate.verificationTimestamps
          .map((timestamp) => timestamp.inMilliseconds)
          .toList(growable: false),
      'verificationPresentationTimes': exactVerificationTimes
          .map(
            (time) => <String, int>{
              'value': time.value,
              'timescale': time.timescale,
            },
          )
          .toList(growable: false),
      if (candidate.bookmarkData != null)
        'bookmarkData': candidate.bookmarkData,
    };
  }

  VisionFrameMatch _parseMatch(Map rawMatch) {
    final mediaId = rawMatch['mediaId'];
    final distance = rawMatch['visionDistance'];
    final timestampMilliseconds = rawMatch['timestampMilliseconds'];
    final positionPercent = rawMatch['positionPercent'];
    final queryId = rawMatch['queryId'];
    if (mediaId is! String ||
        distance is! num ||
        timestampMilliseconds is! int ||
        (positionPercent != null && positionPercent is! int) ||
        (queryId != null && queryId is! String)) {
      throw const FormatException('Native Vision match was incomplete');
    }
    return VisionFrameMatch(
      mediaId: mediaId,
      distance: distance.toDouble(),
      timestamp: Duration(milliseconds: timestampMilliseconds),
      queryId: queryId as String?,
      positionPercent: (positionPercent as int?) ?? 0,
      presentationTime: _parsePresentationTime(rawMatch),
    );
  }
}

class VisionFrameMatchingCancelledException implements Exception {
  const VisionFrameMatchingCancelledException();
}

class _VisionSessionUpdateRegistration {
  const _VisionSessionUpdateRegistration({
    required this.requestId,
    required this.callback,
  });

  final String requestId;
  final void Function(VisionSessionBatchUpdate update) callback;
}

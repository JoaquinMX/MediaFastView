import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/duplicate_scan_progress.dart';
import '../../domain/entities/video_frame_presentation_time.dart';

/// Compact descriptor for a decoded presentation frame.
class NativeMaximumVideoFrame {
  const NativeMaximumVideoFrame({
    required this.frameIndex,
    required this.timestamp,
    required this.fullFrameHash,
    required this.centerCropHash,
    required this.width,
    required this.height,
    this.presentationTime,
  });

  final int frameIndex;
  final Duration timestamp;
  final int fullFrameHash;
  final int centerCropHash;
  final int width;
  final int height;
  final VideoFramePresentationTime? presentationTime;
}

/// A bounded native response. The Dart side requests the next chunk only after
/// it has persisted the previous one, keeping memory independent of video
/// length.
class NativeMaximumVideoFrameChunk {
  const NativeMaximumVideoFrameChunk({
    required this.frames,
    required this.isComplete,
  });

  final List<NativeMaximumVideoFrame> frames;
  final bool isComplete;
}

abstract interface class MaximumVideoFrameIndexer {
  Stream<NativeMaximumVideoFrameChunk> index({
    required String requestId,
    required String path,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  });

  Future<void> cancel(String requestId);
}

/// Method-channel adapter for the cancellable AVAssetReader implementation.
class NativeMaximumVideoFrameIndexer implements MaximumVideoFrameIndexer {
  NativeMaximumVideoFrameIndexer({MethodChannel? channel, Uuid? uuid})
    : _channel = channel ?? const MethodChannel(_channelName),
      _uuid = uuid ?? const Uuid();

  static const String _channelName = 'com.joaquinmx.media_fast_view/thumbnails';
  static const int chunkSize = 128;

  final MethodChannel _channel;
  final Uuid _uuid;
  final Set<String> _cancelledRequestIds = <String>{};

  @override
  Stream<NativeMaximumVideoFrameChunk> index({
    required String requestId,
    required String path,
    String? bookmarkData,
    DuplicateScanCancellation? cancellation,
  }) async* {
    final effectiveRequestId = requestId.isEmpty ? _uuid.v4() : requestId;
    if (cancellation?.isCancelled ?? false) {
      throw const MaximumVideoFrameIndexCancelledException();
    }
    final removeCancellationListener = cancellation?.addListener(
      () => unawaited(cancel(effectiveRequestId)),
    );
    var isComplete = false;
    try {
      if (cancellation?.isCancelled ?? false) {
        throw const MaximumVideoFrameIndexCancelledException();
      }
      await _channel.invokeMethod<void>('startMaximumVideoFrameIndex', {
        'requestId': effectiveRequestId,
        'path': path,
        'chunkSize': chunkSize,
        if (bookmarkData != null) 'bookmarkData': bookmarkData,
      });
      var complete = false;
      while (!complete) {
        if (cancellation?.isCancelled ?? false) {
          throw const MaximumVideoFrameIndexCancelledException();
        }
        final response = await _channel.invokeMapMethod<String, dynamic>(
          'readMaximumVideoFrameIndexChunk',
          <String, dynamic>{
            'requestId': effectiveRequestId,
            'chunkSize': chunkSize,
          },
        );
        final rawFrames = response?['frames'];
        if (rawFrames is! List) {
          throw const FormatException(
            'Native maximum-precision frame response was incomplete',
          );
        }
        final frames = <NativeMaximumVideoFrame>[];
        for (final rawFrame in rawFrames) {
          if (rawFrame is! Map) {
            throw const FormatException(
              'Native maximum-precision frame was malformed',
            );
          }
          final frameIndex = rawFrame['frameIndex'];
          final timestampMilliseconds = rawFrame['timestampMilliseconds'];
          final fullFrameHash = rawFrame['fullFrameHash'];
          final centerCropHash = rawFrame['centerCropHash'];
          final width = rawFrame['width'];
          final height = rawFrame['height'];
          final presentationTimeValue = rawFrame['presentationTimeValue'];
          final presentationTimeScale = rawFrame['presentationTimeScale'];
          if (frameIndex is! int ||
              timestampMilliseconds is! int ||
              fullFrameHash is! int ||
              centerCropHash is! int ||
              width is! int ||
              height is! int ||
              presentationTimeValue is! int ||
              presentationTimeScale is! int ||
              presentationTimeScale == 0) {
            throw const FormatException(
              'Native maximum-precision frame was incomplete',
            );
          }
          final presentationTime = VideoFramePresentationTime(
            value: presentationTimeValue,
            timescale: presentationTimeScale,
          );
          frames.add(
            NativeMaximumVideoFrame(
              frameIndex: frameIndex,
              timestamp: Duration(milliseconds: timestampMilliseconds),
              fullFrameHash: fullFrameHash,
              centerCropHash: centerCropHash,
              width: width,
              height: height,
              presentationTime: presentationTime,
            ),
          );
        }
        complete = response?['isComplete'] == true;
        yield NativeMaximumVideoFrameChunk(
          frames: List<NativeMaximumVideoFrame>.unmodifiable(frames),
          isComplete: complete,
        );
        isComplete = complete;
        if (frames.isEmpty && !complete) {
          // Avoid a tight loop if a buggy native implementation returns an
          // empty non-terminal chunk.
          await Future<void>.delayed(Duration.zero);
        }
      }
    } on PlatformException catch (error) {
      if (error.code == 'CANCELLED') {
        throw const MaximumVideoFrameIndexCancelledException();
      }
      rethrow;
    } finally {
      removeCancellationListener?.call();
      if (!isComplete) {
        try {
          await cancel(effectiveRequestId);
        } catch (_) {
          // Native cleanup is best effort when the platform channel is gone.
        }
      }
    }
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
    }
  }
}

class MaximumVideoFrameIndexCancelledException implements Exception {
  const MaximumVideoFrameIndexCancelledException();
}

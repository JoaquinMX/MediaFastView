import 'package:flutter/services.dart';

import '../../../thumbnails/domain/thumbnail_result.dart';

/// One decoded representative video frame returned by the native platform.
class NativeVideoFrame {
  const NativeVideoFrame({
    required this.positionPercent,
    required this.timestamp,
    required this.bytes,
  });

  final int positionPercent;
  final Duration timestamp;
  final Uint8List bytes;
}

/// Generates several representative frames while opening a video only once.
abstract interface class VideoFrameGenerator {
  Future<List<NativeVideoFrame>> generate({
    required String requestId,
    required String path,
    required List<int> positionPercents,
    required int maximumPixelSize,
    String? bookmarkData,
  });

  Future<void> cancel(String requestId);
}

/// Method-channel adapter for the macOS AVFoundation implementation.
class NativeVideoFrameGenerator implements VideoFrameGenerator {
  const NativeVideoFrameGenerator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.joaquinmx.media_fast_view/thumbnails';

  final MethodChannel _channel;

  @override
  Future<List<NativeVideoFrame>> generate({
    required String requestId,
    required String path,
    required List<int> positionPercents,
    required int maximumPixelSize,
    String? bookmarkData,
  }) async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'generateVideoFrames',
        <String, dynamic>{
          'requestId': requestId,
          'path': path,
          'positionPercents': positionPercents,
          'maxPixelSize': maximumPixelSize,
          if (bookmarkData != null) 'bookmarkData': bookmarkData,
        },
      );
      final rawFrames = response?['frames'];
      if (rawFrames is! List) {
        throw const FormatException(
          'Native video-frame response was incomplete',
        );
      }
      final frames = <NativeVideoFrame>[];
      for (final rawFrame in rawFrames) {
        if (rawFrame is! Map) {
          throw const FormatException('Native video frame was malformed');
        }
        final positionPercent = rawFrame['positionPercent'];
        final timestampMilliseconds = rawFrame['timestampMilliseconds'];
        final bytes = rawFrame['bytes'];
        if (positionPercent is! int ||
            timestampMilliseconds is! int ||
            bytes is! Uint8List ||
            bytes.isEmpty) {
          throw const FormatException('Native video frame was incomplete');
        }
        frames.add(
          NativeVideoFrame(
            positionPercent: positionPercent,
            timestamp: Duration(milliseconds: timestampMilliseconds),
            bytes: bytes,
          ),
        );
      }
      frames.sort(
        (first, second) =>
            first.positionPercent.compareTo(second.positionPercent),
      );
      return List<NativeVideoFrame>.unmodifiable(frames);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELLED') {
        throw const ThumbnailCancelledException();
      }
      rethrow;
    }
  }

  @override
  Future<void> cancel(String requestId) async {
    try {
      await _channel.invokeMethod<void>('cancelThumbnail', <String, dynamic>{
        'requestId': requestId,
      });
    } on MissingPluginException {
      // Tests and unsupported platforms have no native work to cancel.
    }
  }
}

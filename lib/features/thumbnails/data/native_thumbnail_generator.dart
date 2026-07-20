import 'package:flutter/services.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_request.dart';
import 'package:media_fast_view/features/thumbnails/domain/thumbnail_result.dart';

class NativeThumbnail {
  const NativeThumbnail({required this.bytes, required this.fileExtension});

  final Uint8List bytes;
  final String fileExtension;
}

abstract interface class ThumbnailGenerator {
  Future<NativeThumbnail> generate(
    ThumbnailRequest request, {
    required String requestId,
  });

  Future<void> cancel(String requestId);
}

/// Method-channel adapter for the ImageIO/AVFoundation Apple implementation.
class NativeThumbnailGenerator implements ThumbnailGenerator {
  const NativeThumbnailGenerator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.joaquinmx.media_fast_view/thumbnails';

  final MethodChannel _channel;

  @override
  Future<NativeThumbnail> generate(
    ThumbnailRequest request, {
    required String requestId,
  }) async {
    if (!request.isSupported) {
      throw UnsupportedError(
        'Thumbnails are not supported for ${request.mediaType.name}',
      );
    }

    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'generateThumbnail',
        <String, dynamic>{
          'requestId': requestId,
          'path': request.path,
          'mediaType': request.mediaType.name,
          'maxPixelSize': request.thumbnailSize.maxPixelSize,
          if (request.bookmarkData != null)
            'bookmarkData': request.bookmarkData,
        },
      );
      final bytes = response?['bytes'];
      final fileExtension = response?['extension'];
      if (bytes is! Uint8List || fileExtension is! String || bytes.isEmpty) {
        throw const FormatException('Native thumbnail response was incomplete');
      }
      return NativeThumbnail(bytes: bytes, fileExtension: fileExtension);
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
      // Tests and unsupported platforms may dispose a request without a native
      // channel. There is no native work to cancel in that case.
    }
  }
}

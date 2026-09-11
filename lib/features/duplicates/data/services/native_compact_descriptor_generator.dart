import 'package:flutter/services.dart';

/// Compact visual descriptor generated natively without crossing JPEG bytes.
class NativeCompactImageDescriptor {
  const NativeCompactImageDescriptor({
    required this.fullFrameHash,
    required this.centerCropHash,
    required this.width,
    required this.height,
  });

  final int fullFrameHash;
  final int centerCropHash;
  final int width;
  final int height;
}

abstract interface class CompactImageDescriptorGenerator {
  Future<NativeCompactImageDescriptor?> generate({
    required String path,
    String? bookmarkData,
  });
}

/// Method-channel adapter for native query-image descriptors.
class NativeCompactImageDescriptorGenerator
    implements CompactImageDescriptorGenerator {
  const NativeCompactImageDescriptorGenerator({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.joaquinmx.media_fast_view/thumbnails';

  final MethodChannel _channel;

  @override
  Future<NativeCompactImageDescriptor?> generate({
    required String path,
    String? bookmarkData,
  }) async {
    final response = await _channel.invokeMapMethod<String, dynamic>(
      'generateCompactImageDescriptor',
      <String, dynamic>{
        'path': path,
        if (bookmarkData != null) 'bookmarkData': bookmarkData,
      },
    );
    final fullFrameHash = response?['fullFrameHash'];
    final centerCropHash = response?['centerCropHash'];
    final width = response?['width'];
    final height = response?['height'];
    if (fullFrameHash is! int ||
        centerCropHash is! int ||
        width is! int ||
        height is! int) {
      return null;
    }
    return NativeCompactImageDescriptor(
      fullFrameHash: fullFrameHash,
      centerCropHash: centerCropHash,
      width: width,
      height: height,
    );
  }
}

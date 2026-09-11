import 'dart:typed_data';

import '../../domain/entities/maximum_video_frame_descriptor.dart';
import '../../domain/entities/video_frame_presentation_time.dart';

/// Encodes maximum-precision frame descriptors as fixed-width binary records.
///
/// The video's media identifier belongs to the containing chunk and is not
/// repeated for every frame. This keeps multi-million-frame indexes compact
/// and avoids JSON parsing on every lookup.
final class MaximumVideoFrameDescriptorCodec {
  const MaximumVideoFrameDescriptorCodec();

  static const int _magic = 0x3249464D; // `MFI2` in little-endian order.
  static const int _headerSize = 12;
  static const int _recordSize = 48;
  static const int _storageVersion = 1;

  /// Validates a chunk once and exposes its records without per-frame objects.
  MaximumVideoFramePackedRecords readPacked({
    required String mediaId,
    required List<int> bytes,
  }) {
    if (bytes.length < _headerSize) {
      throw const FormatException('Maximum-frame chunk header is incomplete');
    }
    final typedBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final data = ByteData.sublistView(typedBytes);
    if (data.getUint32(0, Endian.little) != _magic ||
        data.getUint16(4, Endian.little) != _storageVersion ||
        data.getUint16(6, Endian.little) != _recordSize) {
      throw const FormatException('Maximum-frame chunk format is unsupported');
    }
    final count = data.getUint32(8, Endian.little);
    if (typedBytes.length != _headerSize + count * _recordSize) {
      throw const FormatException('Maximum-frame chunk length is invalid');
    }
    return MaximumVideoFramePackedRecords._(mediaId, data, count);
  }

  Uint8List encode(List<MaximumVideoFrameDescriptor> descriptors) {
    final bytes = Uint8List(_headerSize + (descriptors.length * _recordSize));
    final data = ByteData.sublistView(bytes);
    data.setUint32(0, _magic, Endian.little);
    data.setUint16(4, _storageVersion, Endian.little);
    data.setUint16(6, _recordSize, Endian.little);
    data.setUint32(8, descriptors.length, Endian.little);

    var offset = _headerSize;
    for (final descriptor in descriptors) {
      if (descriptor.frameIndex < 0 || descriptor.frameIndex > 0x7FFFFFFF) {
        throw RangeError.range(
          descriptor.frameIndex,
          0,
          0x7FFFFFFF,
          'frameIndex',
        );
      }
      data.setInt32(offset, descriptor.frameIndex, Endian.little);
      data.setInt64(
        offset + 4,
        descriptor.timestamp.inMilliseconds,
        Endian.little,
      );
      data.setInt64(offset + 12, descriptor.fullFrameHash, Endian.little);
      data.setInt64(offset + 20, descriptor.centerCropHash, Endian.little);
      data.setUint32(offset + 28, descriptor.width, Endian.little);
      data.setUint32(offset + 32, descriptor.height, Endian.little);
      data.setInt64(
        offset + 36,
        descriptor.presentationTime?.value ?? 0,
        Endian.little,
      );
      data.setInt32(
        offset + 44,
        descriptor.presentationTime?.timescale ?? 0,
        Endian.little,
      );
      offset += _recordSize;
    }
    return bytes;
  }

  List<MaximumVideoFrameDescriptor> decode({
    required String mediaId,
    required List<int> bytes,
  }) {
    if (bytes.length < _headerSize) {
      throw const FormatException('Maximum-frame chunk header is incomplete');
    }
    final typedBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final data = ByteData.sublistView(typedBytes);
    final magic = data.getUint32(0, Endian.little);
    final version = data.getUint16(4, Endian.little);
    final recordSize = data.getUint16(6, Endian.little);
    final count = data.getUint32(8, Endian.little);
    if (magic != _magic ||
        version != _storageVersion ||
        recordSize != _recordSize) {
      throw const FormatException('Maximum-frame chunk format is unsupported');
    }
    final expectedLength = _headerSize + (count * _recordSize);
    if (typedBytes.length != expectedLength) {
      throw const FormatException('Maximum-frame chunk length is invalid');
    }

    final descriptors = <MaximumVideoFrameDescriptor>[];
    var offset = _headerSize;
    for (var index = 0; index < count; index++) {
      final presentationTimeValue = data.getInt64(offset + 36, Endian.little);
      final presentationTimeScale = data.getInt32(offset + 44, Endian.little);
      descriptors.add(
        MaximumVideoFrameDescriptor(
          mediaId: mediaId,
          frameIndex: data.getInt32(offset, Endian.little),
          timestamp: Duration(
            milliseconds: data.getInt64(offset + 4, Endian.little),
          ),
          fullFrameHash: data.getInt64(offset + 12, Endian.little),
          centerCropHash: data.getInt64(offset + 20, Endian.little),
          width: data.getUint32(offset + 28, Endian.little),
          height: data.getUint32(offset + 32, Endian.little),
          presentationTime: presentationTimeScale > 0
              ? VideoFramePresentationTime(
                  value: presentationTimeValue,
                  timescale: presentationTimeScale,
                )
              : null,
        ),
      );
      offset += _recordSize;
    }
    return List<MaximumVideoFrameDescriptor>.unmodifiable(descriptors);
  }

  /// Visits records in a packed chunk without materializing the whole list.
  ///
  /// The callback is synchronous by design: callers can keep only a bounded
  /// predecessor/candidate/successor window while the bytes are being read.
  void scan({
    required String mediaId,
    required List<int> bytes,
    required void Function(MaximumVideoFrameDescriptor descriptor) onRecord,
  }) {
    if (bytes.length < _headerSize) {
      throw const FormatException('Maximum-frame chunk header is incomplete');
    }
    final typedBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final data = ByteData.sublistView(typedBytes);
    final magic = data.getUint32(0, Endian.little);
    final version = data.getUint16(4, Endian.little);
    final recordSize = data.getUint16(6, Endian.little);
    final count = data.getUint32(8, Endian.little);
    if (magic != _magic ||
        version != _storageVersion ||
        recordSize != _recordSize) {
      throw const FormatException('Maximum-frame chunk format is unsupported');
    }
    final expectedLength = _headerSize + (count * _recordSize);
    if (typedBytes.length != expectedLength) {
      throw const FormatException('Maximum-frame chunk length is invalid');
    }
    var offset = _headerSize;
    for (var index = 0; index < count; index++) {
      final presentationTimeValue = data.getInt64(offset + 36, Endian.little);
      final presentationTimeScale = data.getInt32(offset + 44, Endian.little);
      onRecord(
        MaximumVideoFrameDescriptor(
          mediaId: mediaId,
          frameIndex: data.getInt32(offset, Endian.little),
          timestamp: Duration(
            milliseconds: data.getInt64(offset + 4, Endian.little),
          ),
          fullFrameHash: data.getInt64(offset + 12, Endian.little),
          centerCropHash: data.getInt64(offset + 20, Endian.little),
          width: data.getUint32(offset + 28, Endian.little),
          height: data.getUint32(offset + 32, Endian.little),
          presentationTime: presentationTimeScale > 0
              ? VideoFramePresentationTime(
                  value: presentationTimeValue,
                  timescale: presentationTimeScale,
                )
              : null,
        ),
      );
      offset += _recordSize;
    }
  }
}

/// Read-only indexed access to one bounded, validated descriptor chunk.
///
/// Hash and frame-index accessors allocate no objects. Call [descriptorAt] only
/// for retained frames and their neighbors. The containing chunk owns the byte
/// storage and must not mutate it while this view is used.
final class MaximumVideoFramePackedRecords {
  const MaximumVideoFramePackedRecords._(this.mediaId, this._data, this.count);

  final String mediaId;
  final ByteData _data;
  final int count;

  int _offset(int index) {
    RangeError.checkValidIndex(index, this, 'index', count);
    return MaximumVideoFrameDescriptorCodec._headerSize +
        index * MaximumVideoFrameDescriptorCodec._recordSize;
  }

  int frameIndexAt(int index) => _data.getInt32(_offset(index), Endian.little);

  int timestampMillisecondsAt(int index) =>
      _data.getInt64(_offset(index) + 4, Endian.little);

  int fullFrameHashAt(int index) =>
      _data.getInt64(_offset(index) + 12, Endian.little);

  int centerCropHashAt(int index) =>
      _data.getInt64(_offset(index) + 20, Endian.little);

  MaximumVideoFrameDescriptor descriptorAt(int index) {
    final offset = _offset(index);
    final timescale = _data.getInt32(offset + 44, Endian.little);
    return MaximumVideoFrameDescriptor(
      mediaId: mediaId,
      frameIndex: _data.getInt32(offset, Endian.little),
      timestamp: Duration(
        milliseconds: _data.getInt64(offset + 4, Endian.little),
      ),
      fullFrameHash: _data.getInt64(offset + 12, Endian.little),
      centerCropHash: _data.getInt64(offset + 20, Endian.little),
      width: _data.getUint32(offset + 28, Endian.little),
      height: _data.getUint32(offset + 32, Endian.little),
      presentationTime: timescale > 0
          ? VideoFramePresentationTime(
              value: _data.getInt64(offset + 36, Endian.little),
              timescale: timescale,
            )
          : null,
    );
  }
}

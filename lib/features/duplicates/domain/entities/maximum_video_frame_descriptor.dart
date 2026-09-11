import 'video_frame_presentation_time.dart';

/// A compact, native descriptor for one decoded presentation frame.
///
/// The two dHashes are intentionally small enough to stream and keep in memory
/// while a lookup scans a chunk. They are only a shortlist signal; maximum
/// precision always verifies shortlisted frames with Apple Vision.
class MaximumVideoFrameDescriptor {
  const MaximumVideoFrameDescriptor({
    required this.mediaId,
    required this.frameIndex,
    required this.timestamp,
    required this.fullFrameHash,
    required this.centerCropHash,
    required this.width,
    required this.height,
    this.presentationTime,
  });

  final String mediaId;
  final int frameIndex;
  final Duration timestamp;
  final int fullFrameHash;
  final int centerCropHash;
  final int width;
  final int height;
  final VideoFramePresentationTime? presentationTime;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mediaId': mediaId,
    'frameIndex': frameIndex,
    'timestampMilliseconds': timestamp.inMilliseconds,
    'fullFrameHash': fullFrameHash,
    'centerCropHash': centerCropHash,
    'width': width,
    'height': height,
    if (presentationTime != null) ...<String, dynamic>{
      'presentationTimeValue': presentationTime!.value,
      'presentationTimeScale': presentationTime!.timescale,
    },
  };

  factory MaximumVideoFrameDescriptor.fromJson(Map<String, dynamic> json) {
    final presentationTimeValue = json['presentationTimeValue'];
    final presentationTimeScale = json['presentationTimeScale'];
    return MaximumVideoFrameDescriptor(
      mediaId: json['mediaId'] as String,
      frameIndex: json['frameIndex'] as int,
      timestamp: Duration(milliseconds: json['timestampMilliseconds'] as int),
      fullFrameHash: json['fullFrameHash'] as int,
      centerCropHash: json['centerCropHash'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      presentationTime:
          presentationTimeValue is int &&
              presentationTimeScale is int &&
              presentationTimeScale != 0
          ? VideoFramePresentationTime(
              value: presentationTimeValue,
              timescale: presentationTimeScale,
            )
          : null,
    );
  }
}

/// A compact descriptor that can be compared with a query image.
typedef VideoFrameDescriptor = MaximumVideoFrameDescriptor;

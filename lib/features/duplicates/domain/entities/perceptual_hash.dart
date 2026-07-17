/// A perceptual (difference-hash) fingerprint of an image, plus the metadata the
/// duplicate feature needs to reason about it.
///
/// The [hash] is a 64-bit dHash: the image is squashed to a fixed grid and each
/// bit records whether one cell is brighter than its right-hand neighbour.
/// Visually similar images — a resize, a re-encode, a lightly edited copy — land
/// a small [hammingDistance] apart, which is what the clusterer groups on.
class PerceptualHash {
  const PerceptualHash({
    required this.mediaId,
    required this.hash,
    required this.width,
    required this.height,
    required this.fingerprint,
  });

  /// The stable media id this hash was computed for.
  final String mediaId;

  /// 64-bit difference hash. May be negative — it is 64 raw bits, not a count.
  final int hash;

  /// Intrinsic pixel dimensions of the source image, kept for the keeper
  /// heuristic ("keep the highest resolution copy").
  final int width;
  final int height;

  /// Cheap change-detector: size and mtime of the file when it was hashed. A
  /// cached hash whose fingerprint still matches the file on disk is reused
  /// instead of decoding the image again.
  final String fingerprint;

  int get pixelCount => width * height;

  PerceptualHash copyWith({
    String? mediaId,
    int? hash,
    int? width,
    int? height,
    String? fingerprint,
  }) {
    return PerceptualHash(
      mediaId: mediaId ?? this.mediaId,
      hash: hash ?? this.hash,
      width: width ?? this.width,
      height: height ?? this.height,
      fingerprint: fingerprint ?? this.fingerprint,
    );
  }

  @override
  String toString() =>
      'PerceptualHash(mediaId: $mediaId, hash: $hash, ${width}x$height)';
}

/// The size+mtime fingerprint used to decide whether a cached hash is still
/// valid for the file on disk.
String perceptualFingerprint({
  required int size,
  required DateTime lastModified,
}) {
  return '${size}_${lastModified.millisecondsSinceEpoch}';
}

/// The number of differing bits between two 64-bit hashes — the similarity
/// metric for dHash. Smaller means more alike (0 == identical grids).
///
/// Uses an unsigned right shift so the sign bit of a negative hash is counted
/// like any other bit.
int hammingDistance(int a, int b) {
  var x = a ^ b;
  var count = 0;
  for (var i = 0; i < 64; i++) {
    count += x & 1;
    x >>>= 1;
  }
  return count;
}

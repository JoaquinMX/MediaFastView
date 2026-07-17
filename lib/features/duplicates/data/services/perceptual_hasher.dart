import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// The perceptual hash of one image plus its intrinsic pixel size.
class ImageHashResult {
  const ImageHashResult({
    required this.hash,
    required this.width,
    required this.height,
  });

  final int hash;
  final int width;
  final int height;
}

/// Computes a 64-bit difference hash (dHash) for an image.
///
/// Decoding goes through the Flutter engine ([ui.ImageDescriptor]) rather than a
/// pure-Dart decoder, because the engine handles HEIC and camera RAW — the
/// formats that dominate a real Apple photo library — whereas a Dart decoder
/// would cover almost none of it. The engine codec is only available on the root
/// isolate, so this runs there; the arithmetic is trivially cheap (a few hundred
/// pixels), and the caller throttles the decode-heavy loop.
class PerceptualHasher {
  const PerceptualHasher();

  /// Side of the normalising decode. The image is squashed to this square first
  /// so the hash is independent of aspect ratio and original resolution.
  static const int _decodeSide = 32;

  /// dHash grid: an [_hashSide] x [_hashSide] block of horizontal comparisons,
  /// sampled from an ([_hashSide] + 1)-wide grid, giving 64 bits.
  static const int _hashSide = 8;

  /// Hashes the image at [path], or returns null if it cannot be read/decoded
  /// (unsupported format, corrupt file, permission loss).
  Future<ImageHashResult?> hashFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      return hashBytes(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Hashes already-loaded image [bytes]. Exposed for tests and reuse.
  Future<ImageHashResult?> hashBytes(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final intrinsicWidth = descriptor.width;
      final intrinsicHeight = descriptor.height;

      codec = await descriptor.instantiateCodec(
        targetWidth: _decodeSide,
        targetHeight: _decodeSide,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (rgba == null) {
          return null;
        }
        final hash = _computeDHash(
          rgba.buffer.asUint8List(),
          image.width,
          image.height,
        );
        return ImageHashResult(
          hash: hash,
          width: intrinsicWidth > 0 ? intrinsicWidth : image.width,
          height: intrinsicHeight > 0 ? intrinsicHeight : image.height,
        );
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Builds the dHash: convert to grayscale, nearest-neighbour resample to a
  /// (9 x 8) grid, then set a bit per cell that is darker than its right
  /// neighbour. Nearest-neighbour keeps this robust even if the engine did not
  /// return exactly [_decodeSide] square.
  int _computeDHash(Uint8List rgba, int width, int height) {
    const sampleWidth = _hashSide + 1;
    const sampleHeight = _hashSide;

    // Precompute grayscale to avoid recomputing shared cells during sampling.
    final gray = Float32List(width * height);
    for (var i = 0; i < width * height; i++) {
      final o = i * 4;
      gray[i] = 0.299 * rgba[o] + 0.587 * rgba[o + 1] + 0.114 * rgba[o + 2];
    }

    final samples = Float32List(sampleWidth * sampleHeight);
    for (var y = 0; y < sampleHeight; y++) {
      final srcY = height <= 1
          ? 0
          : ((y * (height - 1)) ~/ (sampleHeight - 1)).clamp(0, height - 1);
      for (var x = 0; x < sampleWidth; x++) {
        final srcX = width <= 1
            ? 0
            : ((x * (width - 1)) ~/ (sampleWidth - 1)).clamp(0, width - 1);
        samples[y * sampleWidth + x] = gray[srcY * width + srcX];
      }
    }

    var hash = 0;
    for (var y = 0; y < sampleHeight; y++) {
      for (var x = 0; x < _hashSide; x++) {
        final left = samples[y * sampleWidth + x];
        final right = samples[y * sampleWidth + x + 1];
        final bit = left < right ? 1 : 0;
        hash = (hash << 1) | bit;
      }
    }
    return hash;
  }
}

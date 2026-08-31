import 'image_lookup_source.dart';

/// A selected lookup image after its perceptual hash has been computed.
class ImageLookupQuery {
  const ImageLookupQuery({
    required this.source,
    required this.hash,
    required this.width,
    required this.height,
  });

  final ImageLookupSource source;
  final int hash;
  final int width;
  final int height;

  int get pixelCount => width * height;

  ImageLookupQuery copyWith({ImageLookupSource? source}) {
    return ImageLookupQuery(
      source: source ?? this.source,
      hash: hash,
      width: width,
      height: height,
    );
  }
}

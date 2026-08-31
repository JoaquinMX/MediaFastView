import 'image_lookup_match.dart';
import 'image_lookup_query.dart';
import 'image_lookup_source.dart';

/// Matches for one visual-media query within a multi-query lookup session.
class ImageLookupResult {
  const ImageLookupResult({
    required this.source,
    required this.matches,
    this.query,
    this.errorMessage,
  });

  final ImageLookupSource source;
  final ImageLookupQuery? query;
  final List<ImageLookupMatch> matches;
  final String? errorMessage;

  bool get hasError => errorMessage != null;

  ImageLookupResult copyWith({
    ImageLookupSource? source,
    ImageLookupQuery? query,
    List<ImageLookupMatch>? matches,
    String? errorMessage,
  }) {
    return ImageLookupResult(
      source: source ?? this.source,
      query: query ?? this.query,
      matches: matches ?? this.matches,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

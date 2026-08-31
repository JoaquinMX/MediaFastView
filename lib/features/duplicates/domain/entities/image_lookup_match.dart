import 'duplicate_candidate.dart';

/// One active-library image that matched a user-selected query image.
class ImageLookupMatch {
  const ImageLookupMatch({required this.candidate, required this.distance});

  final DuplicateCandidate candidate;

  /// Hamming distance from the query dHash. Lower values are closer matches.
  final int distance;
}

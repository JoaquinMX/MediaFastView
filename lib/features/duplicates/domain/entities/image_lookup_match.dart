import 'duplicate_candidate.dart';
import 'matched_video_frame.dart';

/// One active-library image that matched a user-selected query image.
class ImageLookupMatch {
  const ImageLookupMatch({
    required this.candidate,
    required this.distance,
    this.matchedVideoFrame,
  });

  final DuplicateCandidate candidate;

  /// Hamming distance from the query dHash. Lower values are closer matches.
  final int distance;

  /// Present when an image frame matched a sampled frame from a video.
  final MatchedVideoFrame? matchedVideoFrame;
}

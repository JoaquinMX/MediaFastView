import 'image_lookup_progress.dart';
import 'image_lookup_result.dart';
import 'image_lookup_verification_summary.dart';

/// Immutable progress snapshot emitted while image matches are verified.
final class ImageLookupUpdate {
  ImageLookupUpdate({
    required this.progress,
    required List<ImageLookupResult> results,
    required this.verificationSummary,
  }) : results = List<ImageLookupResult>.unmodifiable(results);

  final ImageLookupProgress progress;
  final List<ImageLookupResult> results;
  final ImageLookupVerificationSummary? verificationSummary;
}

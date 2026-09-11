import 'image_lookup_result.dart';
import 'image_lookup_verification_summary.dart';

/// Completed results for a mixed image/video lookup operation.
class ImageLookupBatch {
  const ImageLookupBatch({
    required this.results,
    required this.searchedLibraryImages,
    this.verificationSummary,
  });

  final List<ImageLookupResult> results;
  final int searchedLibraryImages;
  final ImageLookupVerificationSummary? verificationSummary;
}

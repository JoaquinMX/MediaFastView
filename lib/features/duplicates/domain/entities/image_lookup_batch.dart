import 'image_lookup_result.dart';

/// Completed results for a mixed image/video lookup operation.
class ImageLookupBatch {
  const ImageLookupBatch({
    required this.results,
    required this.searchedLibraryImages,
  });

  final List<ImageLookupResult> results;
  final int searchedLibraryImages;
}

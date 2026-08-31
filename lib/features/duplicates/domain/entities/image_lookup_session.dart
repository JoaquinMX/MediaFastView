import '../../../../core/models/media_lookup_mode.dart';
import 'duplicate_sensitivity.dart';
import 'image_lookup_result.dart';

/// A completed, immutable batch lookup and its original result snapshot.
class ImageLookupSession {
  const ImageLookupSession({
    required this.id,
    required this.profileId,
    required this.createdAt,
    required this.sensitivity,
    this.lookupMode = MediaLookupMode.mediaMatches,
    required this.results,
    required this.hasPartialCoverage,
    required this.searchedLibraryImages,
  });

  final String id;
  final String profileId;
  final DateTime createdAt;
  final DuplicateSensitivity sensitivity;
  final MediaLookupMode lookupMode;
  final List<ImageLookupResult> results;
  final bool hasPartialCoverage;
  final int searchedLibraryImages;

  int get queryCount => results.length;

  int get matchCount =>
      results.fold<int>(0, (sum, result) => sum + result.matches.length);

  ImageLookupSession copyWith({
    DuplicateSensitivity? sensitivity,
    MediaLookupMode? lookupMode,
    List<ImageLookupResult>? results,
    bool? hasPartialCoverage,
    int? searchedLibraryImages,
  }) {
    return ImageLookupSession(
      id: id,
      profileId: profileId,
      createdAt: createdAt,
      sensitivity: sensitivity ?? this.sensitivity,
      lookupMode: lookupMode ?? this.lookupMode,
      results: results ?? this.results,
      hasPartialCoverage: hasPartialCoverage ?? this.hasPartialCoverage,
      searchedLibraryImages:
          searchedLibraryImages ?? this.searchedLibraryImages,
    );
  }
}

import '../../../../core/models/media_lookup_mode.dart';
import '../../../../core/models/video_frame_lookup_precision.dart';
import 'duplicate_sensitivity.dart';
import 'image_lookup_result.dart';
import 'image_lookup_verification_summary.dart';

/// An immutable lookup result snapshot, complete or intentionally stopped.
class ImageLookupSession {
  const ImageLookupSession({
    required this.id,
    required this.profileId,
    required this.createdAt,
    required this.sensitivity,
    this.lookupMode = MediaLookupMode.mediaMatches,
    this.lookupPrecision = VideoFrameLookupPrecision.standard,
    required this.results,
    required this.hasPartialCoverage,
    required this.searchedLibraryImages,
    this.verificationSummary,
  });

  final String id;
  final String profileId;
  final DateTime createdAt;
  final DuplicateSensitivity sensitivity;
  final MediaLookupMode lookupMode;

  /// Precision tier used for video-from-frame matching.
  ///
  /// Older persisted sessions omit this value and decode as [standard].
  final VideoFrameLookupPrecision lookupPrecision;
  final List<ImageLookupResult> results;
  final bool hasPartialCoverage;
  final int searchedLibraryImages;
  final ImageLookupVerificationSummary? verificationSummary;

  /// Whether verification was intentionally stopped before all eligible videos
  /// were checked.
  bool get hasStoppedVerification => verificationSummary?.stopped ?? false;

  int get queryCount => results.length;

  int get matchCount =>
      results.fold<int>(0, (sum, result) => sum + result.matches.length);

  /// Number of indexed videos searched when this is a video-from-frame lookup.
  int get indexedVideoCount =>
      lookupMode == MediaLookupMode.videoFromFrame ? searchedLibraryImages : 0;

  ImageLookupSession copyWith({
    DuplicateSensitivity? sensitivity,
    MediaLookupMode? lookupMode,
    VideoFrameLookupPrecision? lookupPrecision,
    List<ImageLookupResult>? results,
    bool? hasPartialCoverage,
    int? searchedLibraryImages,
    ImageLookupVerificationSummary? verificationSummary,
  }) {
    return ImageLookupSession(
      id: id,
      profileId: profileId,
      createdAt: createdAt,
      sensitivity: sensitivity ?? this.sensitivity,
      lookupMode: lookupMode ?? this.lookupMode,
      lookupPrecision: lookupPrecision ?? this.lookupPrecision,
      results: results ?? this.results,
      hasPartialCoverage: hasPartialCoverage ?? this.hasPartialCoverage,
      searchedLibraryImages:
          searchedLibraryImages ?? this.searchedLibraryImages,
      verificationSummary: verificationSummary ?? this.verificationSummary,
    );
  }
}

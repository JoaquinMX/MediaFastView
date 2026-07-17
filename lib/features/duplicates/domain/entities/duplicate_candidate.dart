import '../../../media_library/domain/entities/media_entity.dart';

/// One image within a [DuplicateGroup] — the media item plus the derived facts
/// the review UI compares copies on.
class DuplicateCandidate {
  const DuplicateCandidate({
    required this.media,
    required this.width,
    required this.height,
    required this.hash,
  });

  final MediaEntity media;

  /// Intrinsic pixel dimensions, shown as a badge and used by the keeper rule.
  final int width;
  final int height;

  /// The candidate's perceptual hash, kept so the group can report how far each
  /// copy sits from the chosen keeper.
  final int hash;

  String get id => media.id;

  int get pixelCount => width * height;

  int get sizeBytes => media.size;
}

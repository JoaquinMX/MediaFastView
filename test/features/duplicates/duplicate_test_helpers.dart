import 'package:media_fast_view/features/duplicates/domain/entities/duplicate_candidate.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';

/// A minimal image [MediaEntity] for duplicate tests.
MediaEntity buildMedia(
  String id, {
  int size = 1000,
  DateTime? modified,
  String? path,
  MediaType type = MediaType.image,
}) {
  final extension = type == MediaType.video ? 'mp4' : 'jpg';
  return MediaEntity(
    id: id,
    path: path ?? '/library/$id.$extension',
    name: '$id.$extension',
    type: type,
    size: size,
    lastModified: modified ?? DateTime(2020, 1, 1),
    tagIds: const [],
    directoryId: 'dir',
  );
}

/// A [DuplicateCandidate] with an explicit perceptual [hash] and dimensions.
DuplicateCandidate buildCandidate(
  String id,
  int hash, {
  int width = 100,
  int height = 100,
  int size = 1000,
  DateTime? modified,
  String? path,
}) {
  return DuplicateCandidate(
    media: buildMedia(id, size: size, modified: modified, path: path),
    width: width,
    height: height,
    hash: hash,
  );
}

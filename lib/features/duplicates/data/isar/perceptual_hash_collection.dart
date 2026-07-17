import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../domain/entities/perceptual_hash.dart';

part 'perceptual_hash_collection.g.dart';

/// The Isar primary key for the hash of the media identified by [mediaId].
Id perceptualHashCollectionId(String mediaId) => isarIdFromKey(mediaId);

/// Cached perceptual hash of one image.
///
/// Keyed by [mediaId] with no profile scope: a file's perceptual hash is a
/// property of its bytes, identical in every profile the file appears in, so the
/// cache is shared. What is profile-scoped is *which* hashes get clustered — the
/// repository only ever looks up the active profile's library media.
@collection
class PerceptualHashCollection {
  PerceptualHashCollection({
    required this.mediaId,
    required this.hash,
    required this.width,
    required this.height,
    required this.fingerprint,
    required this.computedAt,
  });

  Id get id => perceptualHashCollectionId(mediaId);
  set id(Id value) {}

  @Index(unique: true, replace: true)
  String mediaId;

  /// 64-bit dHash. Stored raw; may be negative.
  int hash;

  int width;
  int height;

  /// size+mtime of the file when hashed, used to invalidate stale entries.
  String fingerprint;

  DateTime computedAt;
}

extension PerceptualHashCollectionMapper on PerceptualHashCollection {
  PerceptualHash toDomain() {
    return PerceptualHash(
      mediaId: mediaId,
      hash: hash,
      width: width,
      height: height,
      fingerprint: fingerprint,
    );
  }
}

extension PerceptualHashIsarMapper on PerceptualHash {
  PerceptualHashCollection toCollection({DateTime? computedAt}) {
    return PerceptualHashCollection(
      mediaId: mediaId,
      hash: hash,
      width: width,
      height: height,
      fingerprint: fingerprint,
      computedAt: computedAt ?? DateTime.now(),
    );
  }
}

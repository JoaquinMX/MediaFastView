import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../../media_library/data/isar/directory_collection.dart';
import '../../../media_library/data/isar/media_collection.dart';
import '../../../media_library/data/models/tag_model.dart';

part 'tag_collection.g.dart';

/// Isar collection representing a tag that can be assigned to media or directories.
@collection
class TagCollection {
  TagCollection({
    required this.tagId,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  /// Unique hash-based identifier used by Isar for this record.
  Id get id {
    return computeTagCollectionId(tagId);
  }
  set id(Id value) {}

  /// Stable tag identifier used throughout the app.
  @Index(unique: true, replace: true)
  String tagId;

  /// Display name of the tag.
  String name;

  /// ARGB color value assigned to the tag.
  int color;

  /// Timestamp when the tag was created.
  DateTime createdAt;

  /// Links to media items associated with the tag.
  final IsarLinks<MediaCollection> media = IsarLinks<MediaCollection>();

  /// Links to directories associated with the tag.
  final IsarLinks<DirectoryCollection> directories =
      IsarLinks<DirectoryCollection>();
}

/// Generates a deterministic, collision-resistant identifier for a [TagCollection]
/// based on its [tagId]. The first 64 bits of the SHA-256 digest are used to
/// produce a stable numeric value accepted by Isar.
Id computeTagCollectionId(String tagId) {
  final digest = sha256.convert(utf8.encode(tagId)).bytes;
  final view = ByteData.sublistView(Uint8List.fromList(digest), 0, 8);
  return view.getUint64(0, Endian.big);
}

/// Legacy identifier mapping used before the introduction of
/// [computeTagCollectionId]. Retained to support cleanup of existing records
/// written with the previous sum-based hash.
Id computeLegacyTagCollectionId(String tagId) {
  final hash = sha256.convert(utf8.encode(tagId)).bytes;
  return hash.fold<int>(0, (prev, element) => prev + element);
}

extension TagCollectionMapper on TagCollection {
  /// Converts this [TagCollection] into the existing [TagModel].
  TagModel toModel() {
    return TagModel(
      id: tagId,
      name: name,
      color: color,
      createdAt: createdAt,
    );
  }
}

extension TagModelIsarMapper on TagModel {
  /// Converts the [TagModel] into a persisted [TagCollection].
  TagCollection toCollection() {
    return TagCollection(
      tagId: id,
      name: name,
      color: color,
      createdAt: createdAt,
    );
  }
}

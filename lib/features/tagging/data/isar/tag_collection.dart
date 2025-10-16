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
  Id get id => Isar.fastHash(tagId);
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

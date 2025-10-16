import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';

import '../../../media_library/data/isar/directory_collection.dart';
import '../../../media_library/data/isar/media_collection.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../models/favorite_model.dart';

part 'favorite_collection.g.dart';

/// Isar collection representing a favorite item stored by the user.
@collection
class FavoriteCollection {
  FavoriteCollection({
    required this.itemId,
    required this.itemType,
    required this.addedAt,
    this.metadataJson,
  });

  /// Unique hash-based identifier derived from item type and ID.
  Id get id {
    final hash = sha256.convert(utf8.encode('${itemType.name}::$itemId')).bytes;
    return hash.fold<int>(0, (prev, element) => prev + element);
  }
  set id(Id value) {}

  /// Stable identifier for the favorited item.
  @Index(
    unique: true,
    replace: true,
    composite: [CompositeIndex('itemType')],
  )
  String itemId;

  /// Item type (media or directory).
  @Enumerated(EnumType.name)
  FavoriteItemType itemType;

  /// Timestamp when the item was marked as favorite.
  DateTime addedAt;

  /// JSON encoded metadata associated with the favorite.
  String? metadataJson;

  /// Optional link to the referenced media item.
  final IsarLink<MediaCollection> media = IsarLink<MediaCollection>();

  /// Optional link to the referenced directory item.
  final IsarLink<DirectoryCollection> directory =
      IsarLink<DirectoryCollection>();
}

extension FavoriteCollectionMapper on FavoriteCollection {
  /// Converts this [FavoriteCollection] into the existing [FavoriteModel].
  FavoriteModel toModel() {
    return FavoriteModel(
      itemId: itemId,
      itemType: itemType,
      addedAt: addedAt,
      metadata: metadataJson == null
          ? null
          : Map.unmodifiable(
              Map<String, dynamic>.from(
                jsonDecode(metadataJson!) as Map<dynamic, dynamic>,
              ),
            ),
    );
  }
}

extension FavoriteModelIsarMapper on FavoriteModel {
  /// Converts the [FavoriteModel] into a persisted [FavoriteCollection].
  FavoriteCollection toCollection() {
    return FavoriteCollection(
      itemId: itemId,
      itemType: itemType,
      addedAt: addedAt,
      metadataJson: metadata == null ? null : jsonEncode(metadata),
    );
  }
}

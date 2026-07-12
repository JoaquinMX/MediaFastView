import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../../media_library/data/isar/directory_collection.dart';
import '../../../media_library/data/isar/media_collection.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../models/favorite_model.dart';

part 'favorite_collection.g.dart';

/// The natural key of a favorite: an item is favorited per type.
String favoriteKey(String itemId, FavoriteItemType type) =>
    '${type.name}::$itemId';

/// The Isar primary key for the favorite of [itemId] with [type].
///
/// Shared with the data source's delete and lookup paths, which must address
/// exactly the key the collection was stored under.
Id favoriteCollectionId(String itemId, FavoriteItemType type) =>
    isarIdFromKey(favoriteKey(itemId, type));

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
  Id get id => favoriteCollectionId(itemId, itemType);
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

import 'dart:convert';

import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../../media_library/data/isar/directory_collection.dart';
import '../../../media_library/data/isar/media_collection.dart';
import '../../domain/entities/favorite_item_type.dart';
import '../models/favorite_model.dart';

part 'favorite_collection.g.dart';

/// The natural key of a favorite: an item is favorited per type, per profile.
///
/// The profile has to enter the key because [itemId] is content-derived — the
/// same media can be favorited independently in two profiles, and without the
/// profile those two rows would collide on one id.
String favoriteKey(String profileId, String itemId, FavoriteItemType type) =>
    '$profileId::${type.name}::$itemId';

/// The Isar primary key for the favorite of [itemId] with [type] in [profileId].
///
/// Shared with the data source's delete and lookup paths, which must address
/// exactly the key the collection was stored under.
Id favoriteCollectionId(
  String profileId,
  String itemId,
  FavoriteItemType type,
) =>
    isarIdFromKey(favoriteKey(profileId, itemId, type));

/// Isar collection representing a favorite item stored by the user.
@collection
class FavoriteCollection {
  FavoriteCollection({
    required this.itemId,
    required this.profileId,
    required this.itemType,
    required this.addedAt,
    this.metadataJson,
  });

  /// Unique hash-based identifier derived from profile, item type and ID.
  Id get id => favoriteCollectionId(profileId, itemId, itemType);
  set id(Id value) {}

  /// Stable identifier for the favorited item.
  @Index(
    unique: true,
    replace: true,
    composite: [CompositeIndex('itemType'), CompositeIndex('profileId')],
  )
  String itemId;

  /// The profile that owns this favorite.
  ///
  /// Indexed separately from the composite above, which leads on [itemId] and so
  /// cannot serve a scan-by-profile.
  @Index(type: IndexType.hash)
  String profileId;

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
      profileId: profileId,
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
      profileId: profileId,
      itemType: itemType,
      addedAt: addedAt,
      metadataJson: metadata == null ? null : jsonEncode(metadata),
    );
  }
}

import 'package:collection/collection.dart';

import 'favorite_item_type.dart';

/// Domain entity representing a favorite item.
class FavoriteEntity {
  const FavoriteEntity({
    required this.itemId,
    required this.itemType,
    required this.addedAt,
    this.metadata,
  });

  static const DeepCollectionEquality _metadataEquality =
      DeepCollectionEquality.unordered();

  final String itemId;
  final FavoriteItemType itemType;
  final DateTime addedAt;
  final Map<String, dynamic>? metadata;

  /// Creates a copy with updated fields.
  FavoriteEntity copyWith({
    String? itemId,
    FavoriteItemType? itemType,
    DateTime? addedAt,
    Map<String, dynamic>? metadata,
  }) {
    return FavoriteEntity(
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      addedAt: addedAt ?? this.addedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteEntity &&
          runtimeType == other.runtimeType &&
          itemId == other.itemId &&
          itemType == other.itemType &&
          _metadataEquality.equals(metadata, other.metadata);

  @override
  int get hashCode =>
      Object.hash(itemId, itemType, _metadataEquality.hash(metadata));

  @override
  String toString() =>
      'FavoriteEntity(itemId: $itemId, itemType: $itemType, addedAt: $addedAt, metadata: $metadata)';
}

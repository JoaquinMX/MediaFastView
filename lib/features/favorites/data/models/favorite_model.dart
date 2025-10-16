import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/favorite_item_type.dart';

part 'favorite_model.freezed.dart';
part 'favorite_model.g.dart';

/// Data model for favorite information.
/// Used for JSON serialization/deserialization when persisting favorites.
@freezed
class FavoriteModel with _$FavoriteModel {
  const factory FavoriteModel({
    required String itemId,
    required FavoriteItemType itemType,
    required DateTime addedAt,
    Map<String, dynamic>? metadata,
  }) = _FavoriteModel;

  factory FavoriteModel.fromJson(Map<String, dynamic> json) =>
      _$FavoriteModelFromJson(json);
}

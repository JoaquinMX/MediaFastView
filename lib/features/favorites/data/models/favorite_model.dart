import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_model.freezed.dart';
part 'favorite_model.g.dart';

/// Data model for favorite information.
/// Used for JSON serialization/deserialization with SharedPreferences.
@freezed
class FavoriteModel with _$FavoriteModel {
  const factory FavoriteModel({
    required String mediaId,
    required DateTime addedAt,
  }) = _FavoriteModel;

  factory FavoriteModel.fromJson(Map<String, dynamic> json) =>
      _$FavoriteModelFromJson(json);
}

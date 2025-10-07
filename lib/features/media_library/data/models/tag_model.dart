import 'package:freezed_annotation/freezed_annotation.dart';

part 'tag_model.freezed.dart';
part 'tag_model.g.dart';

/// Data model for tag information.
/// Used for JSON serialization/deserialization with SharedPreferences.
@freezed
class TagModel with _$TagModel {
  const factory TagModel({
    required String id,
    required String name,
    required int color,
    required DateTime createdAt,
  }) = _TagModel;

  factory TagModel.fromJson(Map<String, dynamic> json) =>
      _$TagModelFromJson(json);
}

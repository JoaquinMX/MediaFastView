import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_model.freezed.dart';
part 'profile_model.g.dart';

/// Data model for a profile.
@freezed
class ProfileModel with _$ProfileModel {
  const factory ProfileModel({
    required String id,
    required String name,
    @Default(0) int sortOrder,
    required DateTime createdAt,
  }) = _ProfileModel;

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);
}

import 'package:freezed_annotation/freezed_annotation.dart';

part 'directory_model.freezed.dart';
part 'directory_model.g.dart';

/// Data model for directory information.
/// Used for JSON serialization/deserialization with SharedPreferences.
@freezed
class DirectoryModel with _$DirectoryModel {
  const factory DirectoryModel({
    required String id,
    required String path,
    required String name,
    String? thumbnailPath,
    @Default(<String>[]) List<String> tagIds,
    required DateTime lastModified,
    String? bookmarkData,
  }) = _DirectoryModel;

  factory DirectoryModel.fromJson(Map<String, dynamic> json) =>
      _$DirectoryModelFromJson(json);
}

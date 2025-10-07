import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/media_entity.dart';

part 'media_model.freezed.dart';
part 'media_model.g.dart';

/// Data model for media item information.
/// Used for JSON serialization/deserialization with SharedPreferences.
@freezed
class MediaModel with _$MediaModel {
  const factory MediaModel({
    required String id,
    required String path,
    required String name,
    required MediaType type,
    required int size,
    required DateTime lastModified,
    @Default(<String>[]) List<String> tagIds,
    required String directoryId,
    String? bookmarkData,
  }) = _MediaModel;

  factory MediaModel.fromJson(Map<String, dynamic> json) =>
      _$MediaModelFromJson(json);
}

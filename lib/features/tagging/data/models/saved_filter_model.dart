import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/enums/tag_filter_mode.dart';
import '../../domain/enums/tag_media_type_filter.dart';

part 'saved_filter_model.freezed.dart';
part 'saved_filter_model.g.dart';

/// Data model for a saved Tags-tab filter.
///
/// The tag ids and directory paths are `List`s rather than `Set`s because that
/// is what Isar and JSON store; the domain works in sets.
@freezed
class SavedFilterModel with _$SavedFilterModel {
  const factory SavedFilterModel({
    required String id,
    required String name,
    @Default(<String>[]) List<String> requiredTagIds,
    @Default(<String>[]) List<String> optionalTagIds,
    @Default(<String>[]) List<String> excludedTagIds,
    @Default(TagFilterMode.any) TagFilterMode filterMode,
    @Default(TagMediaTypeFilter.all) TagMediaTypeFilter mediaTypeFilter,
    @Default(<String>[]) List<String> directoryPaths,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _SavedFilterModel;

  factory SavedFilterModel.fromJson(Map<String, dynamic> json) =>
      _$SavedFilterModelFromJson(json);
}

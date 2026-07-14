import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../domain/enums/tag_filter_mode.dart';
import '../../domain/enums/tag_media_type_filter.dart';
import '../models/saved_filter_model.dart';

part 'saved_filter_collection.g.dart';

/// The Isar primary key for the saved filter identified by [filterId].
///
/// Shared with the data source's delete path, which must address exactly the key
/// the collection was stored under.
Id savedFilterCollectionId(String filterId) => isarIdFromKey(filterId);

/// Isar collection representing a named Tags-tab query.
@collection
class SavedFilterCollection {
  SavedFilterCollection({
    required this.filterId,
    required this.profileId,
    required this.name,
    required this.requiredTagIds,
    required this.optionalTagIds,
    required this.excludedTagIds,
    required this.filterMode,
    required this.mediaTypeFilter,
    required this.directoryPaths,
    required this.createdAt,
    required this.updatedAt,
  });

  Id get id => savedFilterCollectionId(filterId);
  set id(Id value) {}

  /// Stable filter identifier used throughout the app.
  ///
  /// A uuid, so it is already globally unique — the profile does not enter the
  /// natural key, and existing rows keep their Isar id.
  @Index(unique: true, replace: true)
  String filterId;

  /// The profile that owns this filter. A filter references that profile's tag
  /// ids and directory paths, so it only makes sense inside it.
  @Index(type: IndexType.hash)
  String profileId;

  String name;

  List<String> requiredTagIds;
  List<String> optionalTagIds;
  List<String> excludedTagIds;

  /// Persisted by name, so new enum values must be **appended** — the same
  /// constraint `MediaType` carries.
  @Enumerated(EnumType.name)
  TagFilterMode filterMode;

  @Enumerated(EnumType.name)
  TagMediaTypeFilter mediaTypeFilter;

  List<String> directoryPaths;

  DateTime createdAt;
  DateTime updatedAt;
}

extension SavedFilterCollectionMapper on SavedFilterCollection {
  SavedFilterModel toModel() {
    return SavedFilterModel(
      id: filterId,
      profileId: profileId,
      name: name,
      requiredTagIds: List<String>.unmodifiable(requiredTagIds),
      optionalTagIds: List<String>.unmodifiable(optionalTagIds),
      excludedTagIds: List<String>.unmodifiable(excludedTagIds),
      filterMode: filterMode,
      mediaTypeFilter: mediaTypeFilter,
      directoryPaths: List<String>.unmodifiable(directoryPaths),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension SavedFilterModelIsarMapper on SavedFilterModel {
  SavedFilterCollection toCollection() {
    return SavedFilterCollection(
      filterId: id,
      profileId: profileId,
      name: name,
      requiredTagIds: List<String>.from(requiredTagIds),
      optionalTagIds: List<String>.from(optionalTagIds),
      excludedTagIds: List<String>.from(excludedTagIds),
      filterMode: filterMode,
      mediaTypeFilter: mediaTypeFilter,
      directoryPaths: List<String>.from(directoryPaths),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

import 'package:flutter/foundation.dart';

import '../enums/tag_filter_mode.dart';
import '../enums/tag_media_type_filter.dart';

/// The query a Tags-tab filter expresses, independent of any name or storage.
///
/// Its own type because it is used three ways: persisted inside a
/// [SavedFilterEntity], snapshotted from the live view model
/// (`TagsViewModel.currentFilter()`), and compared against that snapshot to tell
/// whether an applied filter has been modified — which is what `==` is for.
@immutable
class SavedFilterDefinition {
  const SavedFilterDefinition({
    this.requiredTagIds = const <String>{},
    this.optionalTagIds = const <String>{},
    this.excludedTagIds = const <String>{},
    this.filterMode = TagFilterMode.any,
    this.mediaTypeFilter = TagMediaTypeFilter.all,
    this.directoryPaths = const <String>{},
  });

  static const empty = SavedFilterDefinition();

  final Set<String> requiredTagIds;
  final Set<String> optionalTagIds;
  final Set<String> excludedTagIds;
  final TagFilterMode filterMode;
  final TagMediaTypeFilter mediaTypeFilter;

  /// Normalized absolute paths of the directories whose media is included.
  final Set<String> directoryPaths;

  /// Whether this narrows anything at all.
  ///
  /// The match mode and media-type filter are deliberately ignored: on their own
  /// they select everything, and a filter that selects everything is just the
  /// unfiltered view under a name.
  bool get isEmpty =>
      requiredTagIds.isEmpty &&
      optionalTagIds.isEmpty &&
      excludedTagIds.isEmpty &&
      directoryPaths.isEmpty;

  Iterable<String> get allTagIds =>
      [...requiredTagIds, ...optionalTagIds, ...excludedTagIds];

  SavedFilterDefinition copyWith({
    Set<String>? requiredTagIds,
    Set<String>? optionalTagIds,
    Set<String>? excludedTagIds,
    TagFilterMode? filterMode,
    TagMediaTypeFilter? mediaTypeFilter,
    Set<String>? directoryPaths,
  }) {
    return SavedFilterDefinition(
      requiredTagIds: requiredTagIds ?? this.requiredTagIds,
      optionalTagIds: optionalTagIds ?? this.optionalTagIds,
      excludedTagIds: excludedTagIds ?? this.excludedTagIds,
      filterMode: filterMode ?? this.filterMode,
      mediaTypeFilter: mediaTypeFilter ?? this.mediaTypeFilter,
      directoryPaths: directoryPaths ?? this.directoryPaths,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedFilterDefinition &&
          runtimeType == other.runtimeType &&
          filterMode == other.filterMode &&
          mediaTypeFilter == other.mediaTypeFilter &&
          setEquals(requiredTagIds, other.requiredTagIds) &&
          setEquals(optionalTagIds, other.optionalTagIds) &&
          setEquals(excludedTagIds, other.excludedTagIds) &&
          setEquals(directoryPaths, other.directoryPaths);

  @override
  int get hashCode => Object.hash(
        filterMode,
        mediaTypeFilter,
        Object.hashAllUnordered(requiredTagIds),
        Object.hashAllUnordered(optionalTagIds),
        Object.hashAllUnordered(excludedTagIds),
        Object.hashAllUnordered(directoryPaths),
      );

  @override
  String toString() =>
      'SavedFilterDefinition(required: $requiredTagIds, optional: $optionalTagIds, '
      'excluded: $excludedTagIds, mode: $filterMode, type: $mediaTypeFilter, '
      'directories: $directoryPaths)';
}

/// A named, persisted Tags-tab query.
@immutable
class SavedFilterEntity {
  const SavedFilterEntity({
    required this.id,
    required this.name,
    required this.definition,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final SavedFilterDefinition definition;
  final DateTime createdAt;
  final DateTime updatedAt;

  SavedFilterEntity copyWith({
    String? id,
    String? name,
    SavedFilterDefinition? definition,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedFilterEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      definition: definition ?? this.definition,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedFilterEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SavedFilterEntity(id: $id, name: $name)';
}

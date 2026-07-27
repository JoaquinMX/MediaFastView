import 'package:isar/isar.dart';

import '../../../../core/services/isar_id.dart';
import '../../domain/entities/directory_cover_entity.dart';
import '../../domain/entities/media_entity.dart';

part 'directory_cover_collection.g.dart';

/// Builds the stable natural key for one profile's cover of one directory.
String directoryCoverKey(String profileId, String normalizedDirectoryPath) {
  return '$profileId:${normalizedDirectoryPath.toLowerCase()}';
}

/// Converts a cover natural key into its deterministic Isar identifier.
Id directoryCoverCollectionId(String coverKey) => isarIdFromKey(coverKey);

/// Isar record for a profile-specific custom directory cover.
@collection
class DirectoryCoverCollection {
  DirectoryCoverCollection({
    required this.coverKey,
    required this.profileId,
    required this.directoryPath,
    required this.sourceFileName,
    this.sourceFileNames = const <String>[],
    required this.mediaType,
    required this.mode,
    required this.updatedAt,
  });

  Id get id => directoryCoverCollectionId(coverKey);
  set id(Id value) {}

  @Index(unique: true, replace: true)
  String coverKey;

  @Index(type: IndexType.hash)
  String profileId;

  @Index(caseSensitive: false)
  String directoryPath;

  String sourceFileName;

  /// Ordered custom-cover filenames.
  ///
  /// Records created before multi-image covers leave this empty and continue
  /// to deserialize through [sourceFileName].
  List<String> sourceFileNames;

  @Enumerated(EnumType.name)
  MediaType mediaType;

  @Enumerated(EnumType.name)
  DirectoryCoverMode mode;

  DateTime updatedAt;
}

extension DirectoryCoverCollectionMapper on DirectoryCoverCollection {
  DirectoryCoverEntity toEntity() {
    return switch (mode) {
      DirectoryCoverMode.media => DirectoryCoverEntity.selections(
        directoryPath: directoryPath,
        selections: _persistedSelections(),
        updatedAt: updatedAt,
      ),
      DirectoryCoverMode.none => DirectoryCoverEntity.none(
        directoryPath: directoryPath,
        updatedAt: updatedAt,
      ),
    };
  }

  List<DirectoryCoverSelection> _persistedSelections() {
    final fileNames = sourceFileNames.isEmpty
        ? <String>[sourceFileName]
        : sourceFileNames;
    return <DirectoryCoverSelection>[
      for (var index = 0; index < fileNames.length; index += 1)
        DirectoryCoverSelection(
          sourceFileName: fileNames[index],
          mediaType: index == 0 ? mediaType : MediaType.image,
        ),
    ];
  }
}

import 'media_entity.dart';

/// How a profile overrides a directory's automatic preview.
enum DirectoryCoverMode {
  /// Uses a selected direct-child image or video.
  media,

  /// Suppresses automatic previews and displays the folder placeholder.
  none,
}

/// A profile-specific override for a directory's visual cover.
class DirectoryCoverEntity {
  const DirectoryCoverEntity.media({
    required this.directoryPath,
    required this.sourceFileName,
    required this.mediaType,
    required this.updatedAt,
  }) : mode = DirectoryCoverMode.media;

  const DirectoryCoverEntity.none({
    required this.directoryPath,
    required this.updatedAt,
  }) : mode = DirectoryCoverMode.none,
       sourceFileName = null,
       mediaType = null;

  /// The directory whose card and hover previews use this cover.
  final String directoryPath;

  /// Whether this override selects media or deliberately displays no cover.
  final DirectoryCoverMode mode;

  /// The direct child's file name, stored relative to [directoryPath].
  ///
  /// This is null when [mode] is [DirectoryCoverMode.none].
  final String? sourceFileName;

  /// The selected child's supported media type.
  ///
  /// This is null when [mode] is [DirectoryCoverMode.none].
  final MediaType? mediaType;

  /// When the selection was last changed.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DirectoryCoverEntity &&
            directoryPath == other.directoryPath &&
            mode == other.mode &&
            sourceFileName == other.sourceFileName &&
            mediaType == other.mediaType &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(directoryPath, mode, sourceFileName, mediaType, updatedAt);
}

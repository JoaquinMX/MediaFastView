import 'media_entity.dart';

/// One direct-child media file selected for a directory cover.
class DirectoryCoverSelection {
  const DirectoryCoverSelection({
    required this.sourceFileName,
    required this.mediaType,
  });

  /// The selected direct child's file name, relative to its directory.
  final String sourceFileName;

  /// The selected child's supported media type.
  final MediaType mediaType;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DirectoryCoverSelection &&
            sourceFileName == other.sourceFileName &&
            mediaType == other.mediaType;
  }

  @override
  int get hashCode => Object.hash(sourceFileName, mediaType);
}

/// How a profile overrides a directory's automatic preview.
enum DirectoryCoverMode {
  /// Uses selected direct-child media.
  media,

  /// Suppresses automatic previews and displays the folder placeholder.
  none,
}

/// A profile-specific override for a directory's visual cover.
class DirectoryCoverEntity {
  /// The maximum number of images that can form one custom cover.
  static const int maximumSelectionCount = 4;

  /// Creates a legacy-compatible single-media cover.
  factory DirectoryCoverEntity.media({
    required String directoryPath,
    required String sourceFileName,
    required MediaType mediaType,
    required DateTime updatedAt,
  }) {
    return DirectoryCoverEntity.selections(
      directoryPath: directoryPath,
      selections: <DirectoryCoverSelection>[
        DirectoryCoverSelection(
          sourceFileName: sourceFileName,
          mediaType: mediaType,
        ),
      ],
      updatedAt: updatedAt,
    );
  }

  /// Creates an ordered custom cover from one to four selections.
  factory DirectoryCoverEntity.selections({
    required String directoryPath,
    required List<DirectoryCoverSelection> selections,
    required DateTime updatedAt,
  }) {
    _validateSelections(selections);
    return DirectoryCoverEntity._(
      directoryPath: directoryPath,
      mode: DirectoryCoverMode.media,
      selections: List<DirectoryCoverSelection>.unmodifiable(selections),
      updatedAt: updatedAt,
    );
  }

  /// Creates an ordered custom image cover from one to four file names.
  factory DirectoryCoverEntity.images({
    required String directoryPath,
    required List<String> sourceFileNames,
    required DateTime updatedAt,
  }) {
    return DirectoryCoverEntity.selections(
      directoryPath: directoryPath,
      selections: sourceFileNames
          .map(
            (sourceFileName) => DirectoryCoverSelection(
              sourceFileName: sourceFileName,
              mediaType: MediaType.image,
            ),
          )
          .toList(growable: false),
      updatedAt: updatedAt,
    );
  }

  const DirectoryCoverEntity.none({
    required this.directoryPath,
    required this.updatedAt,
  }) : mode = DirectoryCoverMode.none,
       selections = const <DirectoryCoverSelection>[];

  const DirectoryCoverEntity._({
    required this.directoryPath,
    required this.mode,
    required this.selections,
    required this.updatedAt,
  });

  /// The directory whose card and hover previews use this cover.
  final String directoryPath;

  /// Whether this override selects media or deliberately displays no cover.
  final DirectoryCoverMode mode;

  /// The ordered direct-child media selections.
  final List<DirectoryCoverSelection> selections;

  /// The ordered relative file names used by the custom collage.
  List<String> get sourceFileNames => selections
      .map((selection) => selection.sourceFileName)
      .toList(growable: false);

  /// The first selected filename for compatibility with single-cover callers.
  String? get sourceFileName =>
      selections.isEmpty ? null : selections.first.sourceFileName;

  /// The first selected media type for compatibility with legacy records.
  MediaType? get mediaType =>
      selections.isEmpty ? null : selections.first.mediaType;

  /// When the selection was last changed.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DirectoryCoverEntity &&
            directoryPath == other.directoryPath &&
            mode == other.mode &&
            _selectionsEqual(selections, other.selections) &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode =>
      Object.hash(directoryPath, mode, Object.hashAll(selections), updatedAt);

  static void _validateSelections(List<DirectoryCoverSelection> selections) {
    if (selections.isEmpty ||
        selections.length > DirectoryCoverEntity.maximumSelectionCount) {
      throw ArgumentError.value(
        selections.length,
        'selections',
        'A directory cover requires one to four selections.',
      );
    }

    final normalizedNames = <String>{};
    for (final selection in selections) {
      final fileName = selection.sourceFileName.trim();
      if (fileName.isEmpty || !normalizedNames.add(fileName.toLowerCase())) {
        throw ArgumentError.value(
          selection.sourceFileName,
          'selections',
          'Directory cover selections must have unique, non-empty names.',
        );
      }
    }

    if (selections.length > 1 &&
        selections.any((selection) => selection.mediaType != MediaType.image)) {
      throw ArgumentError.value(
        selections,
        'selections',
        'Multi-image directory covers only support images.',
      );
    }
  }

  static bool _selectionsEqual(
    List<DirectoryCoverSelection> first,
    List<DirectoryCoverSelection> second,
  ) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index += 1) {
      if (first[index] != second[index]) {
        return false;
      }
    }
    return true;
  }
}

/// The on-disk `.mediafastview.json` manifest that carries a folder's tags and
/// favorites so they survive a cache clear and travel with the files.
///
/// One manifest describes exactly one folder: the folder's own directory tags
/// ([folderTags] / [folderFavorite]) plus a per-file entry for every media file
/// directly inside it that has at least one tag or is favorited ([files]).
///
/// Tags are referenced **by name**, never by the app's internal UUIDs — a name
/// is the only identity that is stable across machines and across profiles. The
/// [tags] map is the self-contained vocabulary (name → colour) used by this
/// manifest, so a reader never needs any other file to interpret it.
library;

import 'sidecar_file_entry.dart';

/// The schema tag written into every manifest, used to reject foreign JSON.
const String kSidecarManifestSchema = 'media-fast-view/tags';

/// The current manifest format version. Bumped only on a breaking change.
const int kSidecarManifestVersion = 1;

/// The file name written into each folder.
const String kSidecarManifestFileName = '.mediafastview.json';

/// A tag definition as stored in a manifest: just the portable colour, keyed by
/// name in [SidecarManifest.tags].
class SidecarTagDef {
  const SidecarTagDef({required this.color});

  /// Packed ARGB colour value, matching `TagEntity.color`.
  final int color;

  Map<String, dynamic> toJson() => <String, dynamic>{'color': color};

  static SidecarTagDef fromJson(Map<String, dynamic> json) {
    return SidecarTagDef(color: (json['color'] as num?)?.toInt() ?? 0);
  }
}

/// A parsed manifest for a single folder.
class SidecarManifest {
  const SidecarManifest({
    required this.generatedAt,
    this.folderTags = const <String>[],
    this.folderFavorite = false,
    this.tags = const <String, SidecarTagDef>{},
    this.files = const <String, SidecarFileEntry>{},
  });

  /// When this manifest was written. Purely informational.
  final DateTime generatedAt;

  /// Names of the tags assigned to the folder itself (directory tags).
  final List<String> folderTags;

  /// Whether the folder itself is favorited.
  final bool folderFavorite;

  /// Vocabulary of every tag name referenced anywhere in this manifest.
  final Map<String, SidecarTagDef> tags;

  /// File name → its tags/favorite. Keyed by base name, never a full path, so
  /// the entry re-links wherever the folder ends up.
  final Map<String, SidecarFileEntry> files;

  /// Whether this manifest carries anything worth writing. An empty manifest is
  /// never written to disk (no litter) and is treated as absent on read.
  bool get isEmpty =>
      folderTags.isEmpty && !folderFavorite && files.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema': kSidecarManifestSchema,
        'version': kSidecarManifestVersion,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'folderTags': folderTags,
        'folderFavorite': folderFavorite,
        'tags': <String, dynamic>{
          for (final entry in tags.entries) entry.key: entry.value.toJson(),
        },
        'files': <String, dynamic>{
          for (final entry in files.entries) entry.key: entry.value.toJson(),
        },
      };

  /// Parses [json], tolerating missing or malformed optional fields rather than
  /// throwing — a manifest hand-edited or written by an older version should
  /// still yield whatever it validly contains.
  ///
  /// Returns `null` when [json] is not a Media Fast View manifest at all (wrong
  /// or absent [schema]), so a stray JSON file in a library folder is ignored.
  static SidecarManifest? fromJson(Map<String, dynamic> json) {
    if (json['schema'] != kSidecarManifestSchema) {
      return null;
    }

    final tagsRaw = json['tags'];
    final tags = <String, SidecarTagDef>{};
    if (tagsRaw is Map) {
      tagsRaw.forEach((key, value) {
        if (key is String && value is Map) {
          tags[key] = SidecarTagDef.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    final filesRaw = json['files'];
    final files = <String, SidecarFileEntry>{};
    if (filesRaw is Map) {
      filesRaw.forEach((key, value) {
        if (key is String && value is Map) {
          files[key] =
              SidecarFileEntry.fromJson(Map<String, dynamic>.from(value));
        }
      });
    }

    return SidecarManifest(
      generatedAt:
          DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      folderTags: _stringList(json['folderTags']),
      folderFavorite: json['folderFavorite'] == true,
      tags: tags,
      files: files,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.whereType<String>().toList(growable: false);
  }
}

/// One file's portable metadata inside a [SidecarManifest].
///
/// [size] and [mtimeMs] mirror the two inputs (besides the file name) that
/// `generateMediaIdFromMetadata` hashes into a media id. They are stored for
/// diagnostics and future fuzzy-matching — on import the authoritative id is
/// recomputed from the **live** file so it always matches what the scanner
/// produces — but keeping them makes a manifest self-describing and lets a
/// reader detect that a file has changed.
class SidecarFileEntry {
  const SidecarFileEntry({
    required this.size,
    required this.mtimeMs,
    this.tags = const <String>[],
    this.favorite = false,
  });

  /// File size in bytes, as recorded when the manifest was written.
  final int size;

  /// Modification time in milliseconds since epoch, as recorded when written.
  final int mtimeMs;

  /// Names of the tags assigned to this file (keys into [SidecarManifest.tags]).
  final List<String> tags;

  /// Whether this file is favorited.
  final bool favorite;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'size': size,
    'mtimeMs': mtimeMs,
    if (tags.isNotEmpty) 'tags': tags,
    if (favorite) 'favorite': true,
  };

  static SidecarFileEntry fromJson(Map<String, dynamic> json) {
    final tagsRaw = json['tags'];
    return SidecarFileEntry(
      size: (json['size'] as num?)?.toInt() ?? 0,
      mtimeMs: (json['mtimeMs'] as num?)?.toInt() ?? 0,
      tags: tagsRaw is List
          ? tagsRaw.whereType<String>().toList(growable: false)
          : const <String>[],
      favorite: json['favorite'] == true,
    );
  }
}

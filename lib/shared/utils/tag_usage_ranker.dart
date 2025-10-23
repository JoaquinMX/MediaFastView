import '../../features/media_library/domain/entities/media_entity.dart';

/// Utility for ranking tag usage across a list of media items.
class TagUsageRanker {
  const TagUsageRanker({this.limit = defaultLimit});

  /// Default number of tags exposed for keyboard shortcuts.
  static const int defaultLimit = 10;

  /// Maximum number of ranked tags to return.
  final int limit;

  /// Returns tag identifiers ordered by usage frequency (descending) and tag
  /// identifier (ascending) to provide deterministic ordering.
  List<String> rank(List<MediaEntity> mediaList) {
    if (mediaList.isEmpty) {
      return const <String>[];
    }

    final counts = <String, int>{};
    for (final media in mediaList) {
      for (final tagId in media.tagIds) {
        counts.update(tagId, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    if (counts.isEmpty) {
      return const <String>[];
    }

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final usageCompare = b.value.compareTo(a.value);
        if (usageCompare != 0) {
          return usageCompare;
        }
        return a.key.compareTo(b.key);
      });

    return entries
        .take(limit)
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}

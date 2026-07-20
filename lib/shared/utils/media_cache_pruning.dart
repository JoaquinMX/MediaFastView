import '../../features/media_library/domain/entities/media_entity.dart';

/// The ids of cached [media] whose backing path is **not** in [existingPaths].
///
/// [existingPaths] is the set of paths the caller could positively confirm still
/// exist on disk under valid security-scoped access. Anything the caller could
/// not verify (no bookmark, access denied) must be included in [existingPaths]
/// so a row is never pruned on the strength of a check that could not run — a
/// missing entry here always means "confirmed gone", never "could not tell".
List<String> missingMediaIds(
  Iterable<MediaEntity> media,
  Set<String> existingPaths,
) {
  return <String>[
    for (final item in media)
      if (!existingPaths.contains(item.path)) item.id,
  ];
}

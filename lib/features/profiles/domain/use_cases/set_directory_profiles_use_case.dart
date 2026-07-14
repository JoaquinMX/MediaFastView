import '../profile_scoped_sources.dart';
import '../profile_validation.dart';

/// Sets which profiles track a directory.
///
/// The membership list on the row is the whole mechanism: one directory record,
/// one bookmark, one scan cache, and a set of profiles that can see it. Adding a
/// profile here is what makes a folder appear in it — with no folder picker and
/// no rescan.
///
/// Files on disk are never touched.
class SetDirectoryProfilesUseCase {
  const SetDirectoryProfilesUseCase(this._sourcesFor);

  final ProfileScopedSourcesBuilder _sourcesFor;

  Future<void> call(String directoryPath, Set<String> profileIds) async {
    if (profileIds.isEmpty) {
      throw const ProfileValidationException(
        'A directory must belong to at least one profile. Remove it from the '
        'library instead.',
      );
    }

    // Any profile will do to read the row: the lookup is unscoped, and the
    // membership list it carries is the same whoever asks.
    final reader = _sourcesFor(profileIds.first);
    final existing =
        await reader.directories.getDirectoryByPathUnscoped(directoryPath);
    if (existing == null) {
      throw ProfileValidationException(
        'No directory in the library at $directoryPath',
      );
    }

    final removed = existing.profileIds.toSet().difference(profileIds);

    await reader.directories.updateDirectory(
      existing.copyWith(profileIds: profileIds.toList(growable: false)),
    );

    // A profile that loses the directory loses its tag assignments on it too.
    // Otherwise re-adding the folder later would resurrect tags the user last
    // saw when they took it out.
    for (final profileId in removed) {
      final scoped = _sourcesFor(profileId);

      await scoped.directories.updateDirectoryTagsBatch(
        <String, List<String>>{existing.id: const <String>[]},
      );

      final cached = await scoped.media.getMediaForDirectory(existing.id);
      if (cached.isEmpty) {
        continue;
      }
      await scoped.media.updateMediaTagsBatch(<String, List<String>>{
        for (final item in cached) item.id: const <String>[],
      });
    }
  }
}

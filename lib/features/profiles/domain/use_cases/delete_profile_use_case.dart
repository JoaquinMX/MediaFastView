import '../../../../core/services/logging_service.dart';
import '../profile_scoped_sources.dart';
import '../profile_validation.dart';
import '../repositories/profile_repository.dart';

/// What deleting a profile did, so the UI can tell the user.
class DeleteProfileReport {
  const DeleteProfileReport({
    required this.directoriesDropped,
    required this.directoriesKept,
  });

  /// Directories removed from the library because no other profile had them.
  final int directoriesDropped;

  /// Directories left in place because another profile still tracks them.
  final int directoriesKept;

  @override
  String toString() =>
      'DeleteProfileReport(dropped: $directoriesDropped, '
      'kept: $directoriesKept)';
}

/// Deletes a profile and everything it — and only it — owned.
///
/// Tags, favorites and saved filters belong to exactly one profile, so they go
/// with it. Directories are shared: one still tracked by another profile keeps
/// its row, its macOS bookmark, its scan cache and that profile's tags, and only
/// loses this profile's membership and tag assignments. One that nobody else had
/// is dropped from the library, along with its cached media rows.
///
/// **Nothing is deleted from disk.** There is no file-operations dependency here
/// on purpose: removing a profile is a bookkeeping change, and the user's media
/// is not the app's to throw away.
class DeleteProfileUseCase {
  const DeleteProfileUseCase(this._profiles, this._sourcesFor);

  final ProfileRepository _profiles;

  /// Binds data sources to the profile being deleted, which is usually not the
  /// active one the providers are wired to.
  final ProfileScopedSourcesBuilder _sourcesFor;

  Future<DeleteProfileReport> call(String profileId) async {
    final profiles = await _profiles.getProfiles();

    // The app has no concept of "no profile" — every scoped provider reads one —
    // so the last one cannot go.
    if (profiles.length <= 1) {
      throw const ProfileValidationException(
        'The last profile cannot be deleted',
      );
    }
    if (!profiles.any((profile) => profile.id == profileId)) {
      throw ProfileValidationException('No profile with id $profileId');
    }

    final sources = _sourcesFor(profileId);

    final owned = await sources.directories.getDirectories();
    final orphaned = owned
        .where(
          (directory) =>
              directory.profileIds.length == 1 &&
              directory.profileIds.single == profileId,
        )
        .toList(growable: false);

    // Media rows first: they hang off the directory, so dropping the directory
    // before them would leave rows nothing can reach or clean up.
    for (final directory in orphaned) {
      await sources.media.removeMediaForDirectory(directory.id);
    }

    // Unshares the survivors and deletes the orphans, stripping this profile's
    // tag ids from the rows that stay.
    await sources.directories.clearDirectories();

    // Filters and favorites before tags: both reference tag ids, and dropping the
    // tags first would leave those references dangling mid-way through.
    await sources.filters.clearFilters();
    await sources.favorites.clearFavorites();
    await sources.tags.clearTags();
    await sources.covers?.clearCovers();

    await _profiles.removeProfile(profileId);

    final report = DeleteProfileReport(
      directoriesDropped: orphaned.length,
      directoriesKept: owned.length - orphaned.length,
    );
    LoggingService.instance.info('Deleted profile $profileId: $report');
    return report;
  }
}

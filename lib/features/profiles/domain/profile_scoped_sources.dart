import '../../../core/services/isar_database.dart';
import '../../favorites/data/isar/isar_favorites_data_source.dart';
import '../../media_library/data/isar/isar_directory_data_source.dart';
import '../../media_library/data/isar/isar_directory_cover_data_source.dart';
import '../../media_library/data/isar/isar_media_data_source.dart';
import '../../tagging/data/isar/isar_saved_filter_data_source.dart';
import '../../tagging/data/isar/isar_tag_data_source.dart';

/// The data sources bound to one profile.
///
/// Profile-scoped work usually happens through the provider-wired data sources,
/// which are bound to the *active* profile. Deleting a profile, or moving a
/// directory between profiles, is the exception: the profile being operated on
/// is usually not the active one, so those use cases need to bind sources to an
/// arbitrary profile — and to be able to swap them for fakes in tests.
class ProfileScopedSources {
  const ProfileScopedSources({
    required this.directories,
    required this.media,
    required this.tags,
    required this.favorites,
    required this.filters,
    this.covers,
  });

  /// The production binding: real Isar-backed sources for [profileId].
  factory ProfileScopedSources.forProfile(
    IsarDatabase database,
    String profileId,
  ) {
    return ProfileScopedSources(
      directories: IsarDirectoryDataSource(database, profileId: profileId),
      media: IsarMediaDataSource(database, profileId: profileId),
      tags: IsarTagDataSource(database, profileId: profileId),
      favorites: IsarFavoritesDataSource(database, profileId: profileId),
      filters: IsarSavedFilterDataSource(database, profileId: profileId),
      covers: IsarDirectoryCoverDataSource(database, profileId: profileId),
    );
  }

  final IsarDirectoryDataSource directories;
  final IsarMediaDataSource media;
  final IsarTagDataSource tags;
  final IsarFavoritesDataSource favorites;
  final IsarSavedFilterDataSource filters;
  final IsarDirectoryCoverDataSource? covers;
}

/// Binds a fresh set of data sources to [profileId].
typedef ProfileScopedSourcesBuilder =
    ProfileScopedSources Function(String profileId);

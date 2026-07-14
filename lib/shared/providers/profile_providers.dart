import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profiles/data/isar/isar_profile_data_source.dart';
import '../../features/profiles/data/repositories/profile_repository_impl.dart';
import '../../features/profiles/domain/entities/profile_entity.dart';
import '../../features/profiles/domain/profile_scoped_sources.dart';
import '../../features/profiles/domain/repositories/profile_repository.dart';
import '../../features/profiles/domain/use_cases/create_profile_use_case.dart';
import '../../features/profiles/domain/use_cases/delete_profile_use_case.dart';
import '../../features/profiles/domain/use_cases/get_profiles_use_case.dart';
import '../../features/profiles/domain/use_cases/rename_profile_use_case.dart';
import '../../features/profiles/domain/use_cases/set_directory_profiles_use_case.dart';
import 'repository_providers.dart';

/// Kept out of `repository_providers.dart`, which is already the biggest file in
/// the app. Nothing here is profile-scoped: this is the layer that hands profiles
/// out, so it must not depend on the active one.
final isarProfileDataSourceProvider = Provider<IsarProfileDataSource>(
  (ref) => IsarProfileDataSource(ref.watch(isarDatabaseProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(ref.watch(isarProfileDataSourceProvider)),
);

final getProfilesUseCaseProvider = Provider<GetProfilesUseCase>(
  (ref) => GetProfilesUseCase(ref.watch(profileRepositoryProvider)),
);

final createProfileUseCaseProvider = Provider<CreateProfileUseCase>(
  (ref) => CreateProfileUseCase(ref.watch(profileRepositoryProvider)),
);

final renameProfileUseCaseProvider = Provider<RenameProfileUseCase>(
  (ref) => RenameProfileUseCase(ref.watch(profileRepositoryProvider)),
);

/// Binds data sources to an arbitrary profile, not the active one.
///
/// Deleting a profile and reassigning a directory both operate on a profile the
/// user is usually not standing in, so they cannot use the provider-wired data
/// sources.
final profileScopedSourcesBuilderProvider =
    Provider<ProfileScopedSourcesBuilder>((ref) {
  final database = ref.watch(isarDatabaseProvider);
  return (profileId) => ProfileScopedSources.forProfile(database, profileId);
});

final deleteProfileUseCaseProvider = Provider<DeleteProfileUseCase>(
  (ref) => DeleteProfileUseCase(
    ref.watch(profileRepositoryProvider),
    ref.watch(profileScopedSourcesBuilderProvider),
  ),
);

final setDirectoryProfilesUseCaseProvider =
    Provider<SetDirectoryProfilesUseCase>(
  (ref) => SetDirectoryProfilesUseCase(
    ref.watch(profileScopedSourcesBuilderProvider),
  ),
);

/// Every profile, in switcher order.
final profilesProvider = FutureProvider<List<ProfileEntity>>(
  (ref) => ref.watch(getProfilesUseCaseProvider)(),
);

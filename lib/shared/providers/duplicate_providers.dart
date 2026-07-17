import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import '../../features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import '../../features/duplicates/data/repositories/duplicate_repository_impl.dart';
import '../../features/duplicates/domain/repositories/duplicate_repository.dart';
import '../../features/duplicates/domain/use_cases/dismiss_duplicate_group_use_case.dart';
import '../../features/duplicates/domain/use_cases/load_duplicate_groups_use_case.dart';
import '../../features/duplicates/domain/use_cases/scan_for_duplicates_use_case.dart';
import 'repository_providers.dart';

/// Cached perceptual hashes. Global (content-keyed), so it survives profile
/// switches and is shared across profiles that hold the same file.
final perceptualHashDataSourceProvider = Provider<PerceptualHashDataSource>((
  ref,
) {
  return IsarPerceptualHashDataSource(ref.watch(isarDatabaseProvider));
});

/// Dismissed "not duplicates" signatures. Global, keyed by group membership.
final dismissedGroupDataSourceProvider = Provider<DismissedGroupDataSource>((
  ref,
) {
  return IsarDismissedGroupDataSource(ref.watch(isarDatabaseProvider));
});

/// The duplicate repository, scoped to the active profile through
/// [mediaRepositoryProvider]. autoDispose so a profile switch — which rebuilds
/// the media repository — rebuilds this too, re-scoping results to the new
/// library.
final duplicateRepositoryProvider = Provider.autoDispose<DuplicateRepository>((
  ref,
) {
  return DuplicateRepositoryImpl(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    hashDataSource: ref.watch(perceptualHashDataSourceProvider),
    dismissedDataSource: ref.watch(dismissedGroupDataSourceProvider),
  );
});

final scanForDuplicatesUseCaseProvider =
    Provider.autoDispose<ScanForDuplicatesUseCase>((ref) {
      return ScanForDuplicatesUseCase(ref.watch(duplicateRepositoryProvider));
    });

final loadDuplicateGroupsUseCaseProvider =
    Provider.autoDispose<LoadDuplicateGroupsUseCase>((ref) {
      return LoadDuplicateGroupsUseCase(ref.watch(duplicateRepositoryProvider));
    });

final dismissDuplicateGroupUseCaseProvider =
    Provider.autoDispose<DismissDuplicateGroupUseCase>((ref) {
      return DismissDuplicateGroupUseCase(
        ref.watch(duplicateRepositoryProvider),
      );
    });

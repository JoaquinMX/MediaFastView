import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/duplicates/data/data_sources/dismissed_group_data_source.dart';
import '../../features/duplicates/data/data_sources/image_lookup_history_data_source.dart';
import '../../features/duplicates/data/data_sources/perceptual_hash_data_source.dart';
import '../../features/duplicates/data/data_sources/video_frame_hash_data_source.dart';
import '../../features/duplicates/data/repositories/image_lookup_history_repository_impl.dart';
import '../../features/duplicates/data/repositories/duplicate_repository_impl.dart';
import '../../features/duplicates/data/services/image_lookup_file_picker.dart';
import '../../features/duplicates/data/services/native_video_frame_generator.dart';
import '../../features/duplicates/data/services/video_frame_hasher.dart';
import '../../features/duplicates/data/services/video_thumbnail_hasher.dart';
import '../../features/duplicates/domain/repositories/duplicate_repository.dart';
import '../../features/duplicates/domain/repositories/image_lookup_history_repository.dart';
import '../../features/duplicates/domain/use_cases/dismiss_duplicate_group_use_case.dart';
import '../../features/duplicates/domain/use_cases/find_image_matches_use_case.dart';
import '../../features/duplicates/domain/use_cases/get_duplicate_library_coverage_use_case.dart';
import '../../features/duplicates/domain/use_cases/get_video_frame_index_coverage_use_case.dart';
import '../../features/duplicates/domain/use_cases/load_duplicate_groups_use_case.dart';
import '../../features/duplicates/domain/use_cases/scan_for_duplicates_use_case.dart';
import '../../features/duplicates/domain/use_cases/prepare_video_frame_index_use_case.dart';
import 'repository_providers.dart';
import '../../features/thumbnails/presentation/thumbnail_providers.dart';
import 'settings_providers.dart';

/// Cached perceptual hashes. Global (content-keyed), so it survives profile
/// switches and is shared across profiles that hold the same file.
final perceptualHashDataSourceProvider = Provider<PerceptualHashDataSource>((
  ref,
) {
  return IsarPerceptualHashDataSource(ref.watch(isarDatabaseProvider));
});

final videoFrameHashDataSourceProvider = Provider<VideoFrameHashDataSource>((
  ref,
) {
  return IsarVideoFrameHashDataSource(ref.watch(isarDatabaseProvider));
});

final videoFrameHasherProvider = Provider<VideoFrameHasher>((ref) {
  return const NativeVideoFrameHasher(generator: NativeVideoFrameGenerator());
});

/// Dismissed "not duplicates" signatures. Global, keyed by group membership.
final dismissedGroupDataSourceProvider = Provider<DismissedGroupDataSource>((
  ref,
) {
  return IsarDismissedGroupDataSource(ref.watch(isarDatabaseProvider));
});

final imageLookupHistoryDataSourceProvider =
    Provider<ImageLookupHistoryDataSource>((ref) {
      return IsarImageLookupHistoryDataSource(ref.watch(isarDatabaseProvider));
    });

final imageLookupHistoryRepositoryProvider =
    Provider<ImageLookupHistoryRepository>((ref) {
      return ImageLookupHistoryRepositoryImpl(
        ref.watch(imageLookupHistoryDataSourceProvider),
      );
    });

final mediaLookupFilePickerProvider = Provider<MediaLookupFilePicker>((ref) {
  return MacOsMediaLookupFilePicker(ref.watch(bookmarkServiceProvider));
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
    directoryRepository: ref.watch(directoryRepositoryProvider),
    hashDataSource: ref.watch(perceptualHashDataSourceProvider),
    dismissedDataSource: ref.watch(dismissedGroupDataSourceProvider),
    videoThumbnailHasher: CachedVideoThumbnailHasher(
      coordinator: ref.watch(thumbnailCoordinatorProvider),
      diskCacheEnabled: ref.watch(thumbnailDiskCacheEnabledProvider),
    ),
    videoFrameHashDataSource: ref.watch(videoFrameHashDataSourceProvider),
    videoFrameHasher: ref.watch(videoFrameHasherProvider),
  );
});

final scanForDuplicatesUseCaseProvider =
    Provider.autoDispose<ScanForDuplicatesUseCase>((ref) {
      return ScanForDuplicatesUseCase(ref.watch(duplicateRepositoryProvider));
    });

final getDuplicateLibraryCoverageUseCaseProvider =
    Provider.autoDispose<GetDuplicateLibraryCoverageUseCase>((ref) {
      return GetDuplicateLibraryCoverageUseCase(
        ref.watch(duplicateRepositoryProvider),
      );
    });

final getVideoFrameIndexCoverageUseCaseProvider =
    Provider.autoDispose<GetVideoFrameIndexCoverageUseCase>((ref) {
      return GetVideoFrameIndexCoverageUseCase(
        ref.watch(duplicateRepositoryProvider),
      );
    });

final prepareVideoFrameIndexUseCaseProvider =
    Provider.autoDispose<PrepareVideoFrameIndexUseCase>((ref) {
      return PrepareVideoFrameIndexUseCase(
        ref.watch(duplicateRepositoryProvider),
      );
    });

final findImageMatchesUseCaseProvider =
    Provider.autoDispose<FindImageMatchesUseCase>((ref) {
      return FindImageMatchesUseCase(ref.watch(duplicateRepositoryProvider));
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

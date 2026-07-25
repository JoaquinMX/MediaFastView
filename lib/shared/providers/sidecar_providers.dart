import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sidecar/data/sidecar_backup_file_service.dart';
import '../../features/sidecar/data/sidecar_file_service.dart';
import '../../features/sidecar/data/sidecar_repository_impl.dart';
import '../../features/sidecar/data/sidecar_serializer.dart';
import '../../features/sidecar/domain/repositories/sidecar_repository.dart';
import '../../features/sidecar/domain/use_cases/export_sidecars_use_case.dart';
import '../../features/sidecar/domain/use_cases/import_sidecars_use_case.dart';
import 'repository_providers.dart';

/// Reads live media metadata through scoped bookmark access.
final sidecarFileServiceProvider = Provider<SidecarFileService>((ref) {
  return const BookmarkSidecarFileService();
});

final sidecarBackupFileServiceProvider = Provider<SidecarBackupFileService>((
  ref,
) {
  return const FilePickerSidecarBackupFileService();
});

final sidecarSerializerProvider = Provider<SidecarSerializer>((ref) {
  return const SidecarSerializer();
});

final sidecarRepositoryProvider = Provider<SidecarRepository>((ref) {
  return SidecarRepositoryImpl(
    fileService: ref.watch(sidecarFileServiceProvider),
  );
});

/// Builds the active profile's portable tags-and-favorites backup.
final exportSidecarsUseCaseProvider = Provider<ExportSidecarsUseCase>((ref) {
  return ExportSidecarsUseCase(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    directoryRepository: ref.watch(directoryRepositoryProvider),
    favoritesRepository: ref.watch(favoritesRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
  );
});

/// Maps and restores a portable backup into the active profile.
final importSidecarsUseCaseProvider = Provider<ImportSidecarsUseCase>((ref) {
  return ImportSidecarsUseCase(
    directoryRepository: ref.watch(directoryRepositoryProvider),
    mediaRepository: ref.watch(mediaRepositoryProvider),
    favoritesRepository: ref.watch(favoritesRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    createTagUseCase: ref.watch(createTagUseCaseProvider),
    assignTagUseCase: ref.watch(assignTagUseCaseProvider),
    sidecarRepository: ref.watch(sidecarRepositoryProvider),
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/sidecar/data/sidecar_file_service.dart';
import '../../features/sidecar/data/sidecar_repository_impl.dart';
import '../../features/sidecar/domain/repositories/sidecar_repository.dart';
import '../../features/sidecar/domain/use_cases/export_sidecars_use_case.dart';
import '../../features/sidecar/domain/use_cases/import_sidecars_use_case.dart';
import 'repository_providers.dart';

/// Reads and writes `.mediafastview.json` manifests through scoped bookmark
/// access. Stateless, so a plain app-lifetime provider.
final sidecarFileServiceProvider = Provider<SidecarFileService>((ref) {
  return const BookmarkSidecarFileService();
});

final sidecarRepositoryProvider = Provider<SidecarRepository>((ref) {
  return SidecarRepositoryImpl(
    fileService: ref.watch(sidecarFileServiceProvider),
  );
});

/// Writes the active profile's tags and favorites to disk. Watches the
/// profile-scoped repositories so it re-binds when the active profile changes.
final exportSidecarsUseCaseProvider = Provider<ExportSidecarsUseCase>((ref) {
  return ExportSidecarsUseCase(
    mediaRepository: ref.watch(mediaRepositoryProvider),
    directoryRepository: ref.watch(directoryRepositoryProvider),
    favoritesRepository: ref.watch(favoritesRepositoryProvider),
    tagRepository: ref.watch(tagRepositoryProvider),
    sidecarRepository: ref.watch(sidecarRepositoryProvider),
  );
});

/// Reads tags and favorites from disk and merges them into the active profile.
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

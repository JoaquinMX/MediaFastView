import '../../../media_library/domain/entities/directory_entity.dart';
import 'sidecar_backup.dart';

/// A parsed backup paired with the current roots available for restore.
class SidecarImportPreparation {
  const SidecarImportPreparation({
    required this.backup,
    required this.currentRoots,
    required this.automaticRootMappings,
    required this.unmatchedRoots,
  });

  final SidecarBackup backup;
  final List<DirectoryEntity> currentRoots;

  /// Saved original path to matching current directory id.
  final Map<String, String> automaticRootMappings;

  final List<SidecarBackupRoot> unmatchedRoots;

  bool get hasTrackedRoots => currentRoots.isNotEmpty;
}

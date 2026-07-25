import '../../../media_library/domain/entities/directory_entity.dart';
import '../entities/sidecar_backup.dart';
import '../entities/sidecar_read_report.dart';

/// Resolves embedded backup manifests against mapped library roots.
abstract interface class SidecarRepository {
  /// Resolves [backupRoot]'s relative folders beneath [currentRoot] and captures
  /// live size/mtime values under [currentRoot]'s security-scoped access.
  Future<SidecarReadReport> resolveBackupRoot(
    SidecarBackupRoot backupRoot,
    DirectoryEntity currentRoot, {
    void Function()? onFolderProcessed,
  });
}

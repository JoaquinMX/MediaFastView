import '../../../media_library/domain/entities/directory_entity.dart';
import '../entities/sidecar_folder_data.dart';
import '../entities/sidecar_manifest.dart';
import '../entities/sidecar_write_report.dart';

/// Reads and writes per-folder manifests under the library's tracked roots.
///
/// Every method is scoped to a single tracked [DirectoryEntity] root so the
/// implementation can hold that root's security-scoped access exactly once for
/// the whole batch.
abstract interface class SidecarRepository {
  /// Writes each `folderPath → manifest` in [manifestsByFolder] into its folder,
  /// under tracked [root]'s access scope.
  ///
  /// [onFolderProcessed] fires once per folder attempted, so a caller can drive a
  /// determinate progress bar spanning several roots. The returned
  /// [SidecarWriteReport] splits the outcome into written, skipped-because-missing
  /// (stale cache), and genuinely failed folders so none are reported wrongly.
  Future<SidecarWriteReport> writeManifestsUnderRoot(
    DirectoryEntity root,
    Map<String, SidecarManifest> manifestsByFolder, {
    void Function()? onFolderProcessed,
  });

  /// Finds every manifest beneath tracked [root], parses it, and captures the
  /// live size/mtime of each file it references — all under [root]'s scope.
  Future<List<SidecarFolderData>> readManifestsUnderRoot(DirectoryEntity root);
}

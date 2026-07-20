import 'sidecar_file_stat.dart';
import 'sidecar_manifest.dart';

/// One folder's manifest paired with the live filesystem state needed to apply
/// it, gathered together while security-scoped access was held.
///
/// The read side captures [liveStats] up front so the apply side — which writes
/// to Isar and no longer holds disk scope — never has to touch the filesystem.
class SidecarFolderData {
  const SidecarFolderData({
    required this.folderPath,
    required this.manifest,
    required this.liveStats,
    required this.missingFileNames,
  });

  /// Absolute path of the folder that holds the manifest.
  final String folderPath;

  final SidecarManifest manifest;

  /// File name → its live size/mtime, for every file entry whose file exists on
  /// disk right now. Used to recompute the scanner's media id.
  final Map<String, SidecarFileStat> liveStats;

  /// File names listed in the manifest whose file was not found on disk.
  final Set<String> missingFileNames;
}

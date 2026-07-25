import 'package:path/path.dart' as p;

import '../../../core/services/logging_service.dart';
import '../../media_library/domain/entities/directory_entity.dart';
import '../domain/entities/sidecar_backup.dart';
import '../domain/entities/sidecar_file_stat.dart';
import '../domain/entities/sidecar_folder_data.dart';
import '../domain/entities/sidecar_read_report.dart';
import '../domain/repositories/sidecar_repository.dart';
import 'sidecar_file_service.dart';

/// [SidecarRepository] backed by scoped filesystem metadata reads.
class SidecarRepositoryImpl implements SidecarRepository {
  const SidecarRepositoryImpl({required this.fileService});

  final SidecarFileService fileService;

  @override
  Future<SidecarReadReport> resolveBackupRoot(
    SidecarBackupRoot backupRoot,
    DirectoryEntity currentRoot, {
    void Function()? onFolderProcessed,
  }) async {
    final folders = <SidecarFolderData>[];
    final failures = <String>[];
    await fileService.withAccess(currentRoot.bookmarkData, () async {
      for (final entry in backupRoot.manifestsByRelativeFolder.entries) {
        final relativeFolder = entry.key;
        final folderPath = relativeFolder == '.'
            ? p.normalize(currentRoot.path)
            : p.normalize(
                p.joinAll(<String>[
                  currentRoot.path,
                  ...relativeFolder.split('/'),
                ]),
              );
        try {
          final staysInsideRoot =
              p.equals(currentRoot.path, folderPath) ||
              p.isWithin(currentRoot.path, folderPath);
          if (!SidecarBackupRoot.isSafeRelativeFolder(relativeFolder) ||
              !staysInsideRoot) {
            failures.add(folderPath);
            continue;
          }

          final liveStats = <String, SidecarFileStat>{};
          final missing = <String>{};
          for (final fileName in entry.value.files.keys) {
            if (!SidecarBackupRoot.isSafeFileName(fileName)) {
              throw const FormatException(
                'A backup file name contains an unsafe path.',
              );
            }
            final stat = await fileService.statFile(
              p.join(folderPath, fileName),
            );
            if (stat == null) {
              missing.add(fileName);
            } else {
              liveStats[fileName] = stat;
            }
          }

          folders.add(
            SidecarFolderData(
              folderPath: folderPath,
              manifest: entry.value,
              liveStats: liveStats,
              missingFileNames: missing,
            ),
          );
        } catch (error) {
          LoggingService.instance.warning(
            '[Sidecar] Failed to resolve backup folder "$folderPath": $error',
          );
          failures.add(folderPath);
        } finally {
          onFolderProcessed?.call();
        }
      }
    });
    return SidecarReadReport(folders: folders, failures: failures);
  }
}

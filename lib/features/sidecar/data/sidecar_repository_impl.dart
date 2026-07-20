import 'package:path/path.dart' as p;

import '../../../core/services/logging_service.dart';
import '../../media_library/domain/entities/directory_entity.dart';
import '../domain/entities/sidecar_file_stat.dart';
import '../domain/entities/sidecar_folder_data.dart';
import '../domain/entities/sidecar_manifest.dart';
import '../domain/entities/sidecar_write_report.dart';
import '../domain/repositories/sidecar_repository.dart';
import 'sidecar_file_service.dart';
import 'sidecar_serializer.dart';

/// [SidecarRepository] backed by [SidecarFileService] scoped IO and a
/// [SidecarSerializer]. Holds each tracked root's access scope once per batch.
class SidecarRepositoryImpl implements SidecarRepository {
  const SidecarRepositoryImpl({
    required this.fileService,
    this.serializer = const SidecarSerializer(),
  });

  final SidecarFileService fileService;
  final SidecarSerializer serializer;

  @override
  Future<SidecarWriteReport> writeManifestsUnderRoot(
    DirectoryEntity root,
    Map<String, SidecarManifest> manifestsByFolder, {
    void Function()? onFolderProcessed,
  }) async {
    if (manifestsByFolder.isEmpty) {
      return const SidecarWriteReport();
    }

    final written = <String>[];
    final missingFolders = <String>[];
    final failures = <String>[];
    await fileService.withAccess(root.bookmarkData, () async {
      for (final entry in manifestsByFolder.entries) {
        try {
          // A folder can linger in the media cache after being deleted or moved
          // outside the app. Writing into it would throw "no such file"; treat
          // it as a stale-cache skip rather than a failure.
          if (!await fileService.folderExists(entry.key)) {
            missingFolders.add(entry.key);
          } else {
            await fileService.writeManifest(
              entry.key,
              serializer.encode(entry.value),
            );
            written.add(entry.key);
          }
        } catch (error) {
          LoggingService.instance.warning(
            '[Sidecar] Failed to write manifest in "${entry.key}": $error',
          );
          failures.add(entry.key);
        } finally {
          onFolderProcessed?.call();
        }
      }
    });
    return SidecarWriteReport(
      written: written,
      missingFolders: missingFolders,
      failures: failures,
    );
  }

  @override
  Future<List<SidecarFolderData>> readManifestsUnderRoot(
    DirectoryEntity root,
  ) async {
    return fileService.withAccess(root.bookmarkData, () async {
      final folderPaths = await fileService.findManifestFolders(root.path);
      final results = <SidecarFolderData>[];

      for (final folderPath in folderPaths) {
        final contents = await fileService.readManifest(folderPath);
        if (contents == null) {
          continue;
        }
        final manifest = serializer.decode(contents);
        if (manifest == null) {
          LoggingService.instance.warning(
            '[Sidecar] Ignoring unreadable manifest in "$folderPath"',
          );
          continue;
        }

        final liveStats = <String, SidecarFileStat>{};
        final missing = <String>{};
        for (final fileName in manifest.files.keys) {
          final stat =
              await fileService.statFile(p.join(folderPath, fileName));
          if (stat == null) {
            missing.add(fileName);
          } else {
            liveStats[fileName] = stat;
          }
        }

        results.add(
          SidecarFolderData(
            folderPath: folderPath,
            manifest: manifest,
            liveStats: liveStats,
            missingFileNames: missing,
          ),
        );
      }

      return results;
    });
  }
}

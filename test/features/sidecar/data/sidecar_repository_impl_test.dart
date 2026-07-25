import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/sidecar/data/sidecar_file_service.dart';
import 'package:media_fast_view/features/sidecar/data/sidecar_repository_impl.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_backup.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_file_entry.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_manifest.dart';
import 'package:path/path.dart' as p;

DirectoryEntity _rootFor(String path) => DirectoryEntity(
  id: 'root',
  path: path,
  name: p.basename(path),
  thumbnailPath: null,
  tagIds: const <String>[],
  lastModified: DateTime(2020),
);

SidecarManifest _manifest() => SidecarManifest(
  generatedAt: DateTime(2026),
  tags: const <String, SidecarTagDef>{'T': SidecarTagDef(color: 1)},
  files: const <String, SidecarFileEntry>{
    'a.jpg': SidecarFileEntry(size: 1, mtimeMs: 2, tags: <String>['T']),
    'missing.jpg': SidecarFileEntry(size: 1, mtimeMs: 2, tags: <String>['T']),
  },
);

void main() {
  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('sidecar_repo_test');
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test(
    'resolves relative backup folders and captures live file stats',
    () async {
      final repository = const SidecarRepositoryImpl(
        fileService: BookmarkSidecarFileService(),
      );
      final album = await Directory(p.join(tempRoot.path, 'album')).create();
      await File(p.join(album.path, 'a.jpg')).writeAsBytes(<int>[0]);
      final backupRoot = SidecarBackupRoot(
        originalPath: '/old/library',
        name: 'library',
        manifestsByRelativeFolder: <String, SidecarManifest>{
          'album': _manifest(),
        },
      );

      final report = await repository.resolveBackupRoot(
        backupRoot,
        _rootFor(tempRoot.path),
      );

      expect(report.failures, isEmpty);
      expect(report.folders, hasLength(1));
      expect(report.folders.single.folderPath, album.path);
      expect(report.folders.single.liveStats, contains('a.jpg'));
      expect(report.folders.single.missingFileNames, <String>{'missing.jpg'});
    },
  );

  test(
    'rejects a constructed backup path that escapes the mapped root',
    () async {
      final repository = const SidecarRepositoryImpl(
        fileService: BookmarkSidecarFileService(),
      );
      final backupRoot = SidecarBackupRoot(
        originalPath: '/old/library',
        name: 'library',
        manifestsByRelativeFolder: <String, SidecarManifest>{
          '../outside': _manifest(),
        },
      );

      final report = await repository.resolveBackupRoot(
        backupRoot,
        _rootFor(tempRoot.path),
      );

      expect(report.folders, isEmpty);
      expect(report.failures, hasLength(1));
    },
  );
}

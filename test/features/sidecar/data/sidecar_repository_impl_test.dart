import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/sidecar/data/sidecar_file_service.dart';
import 'package:media_fast_view/features/sidecar/data/sidecar_repository_impl.dart';
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
      // Null bookmark: withAccess is a no-op, so the real temp dir is reachable
      // without a security-scoped bookmark or platform channel.
      bookmarkData: null,
    );

SidecarManifest _manifest() => SidecarManifest(
      generatedAt: DateTime(2026),
      tags: const <String, SidecarTagDef>{'T': SidecarTagDef(color: 1)},
      files: const <String, SidecarFileEntry>{
        'a.jpg': SidecarFileEntry(size: 1, mtimeMs: 2, tags: <String>['T']),
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

  test('writes existing folders and skips folders missing on disk', () async {
    final repository = const SidecarRepositoryImpl(
      fileService: BookmarkSidecarFileService(),
    );

    final presentFolder = p.join(tempRoot.path, 'present');
    await Directory(presentFolder).create();
    final missingFolder = p.join(tempRoot.path, 'gone');

    final report = await repository.writeManifestsUnderRoot(
      _rootFor(tempRoot.path),
      <String, SidecarManifest>{
        presentFolder: _manifest(),
        missingFolder: _manifest(),
      },
    );

    expect(report.written, <String>[presentFolder]);
    expect(report.missingFolders, <String>[missingFolder]);
    expect(report.failures, isEmpty);

    // The manifest is on disk in the present folder only.
    expect(
      await File(p.join(presentFolder, kSidecarManifestFileName)).exists(),
      isTrue,
    );
    expect(await Directory(missingFolder).exists(), isFalse);
  });

  test('reads the manifest it wrote back, with live file stats', () async {
    final repository = const SidecarRepositoryImpl(
      fileService: BookmarkSidecarFileService(),
    );

    // A real media file so statFile finds it and the entry is not "missing".
    final mediaFile = File(p.join(tempRoot.path, 'a.jpg'));
    await mediaFile.writeAsBytes(<int>[0]);

    await repository.writeManifestsUnderRoot(
      _rootFor(tempRoot.path),
      <String, SidecarManifest>{tempRoot.path: _manifest()},
    );

    final datas = await repository.readManifestsUnderRoot(_rootFor(tempRoot.path));

    expect(datas, hasLength(1));
    expect(datas.single.manifest.files.keys, contains('a.jpg'));
    expect(datas.single.liveStats.containsKey('a.jpg'), isTrue);
    expect(datas.single.missingFileNames, isEmpty);
  });
}

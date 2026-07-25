import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/sidecar/data/sidecar_serializer.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_backup.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_file_entry.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_manifest.dart';

void main() {
  const serializer = SidecarSerializer();

  test('round-trips embedded sidecar manifests', () {
    final backup = SidecarBackup(
      generatedAt: DateTime.utc(2026, 7, 25),
      roots: <SidecarBackupRoot>[
        SidecarBackupRoot(
          originalPath: '/library/photos',
          name: 'photos',
          manifestsByRelativeFolder: <String, SidecarManifest>{
            '2026/trip': SidecarManifest(
              generatedAt: DateTime.utc(2026, 7, 25),
              tags: const <String, SidecarTagDef>{
                'Travel': SidecarTagDef(color: 0xFF0000FF),
              },
              files: const <String, SidecarFileEntry>{
                'IMG.jpg': SidecarFileEntry(
                  size: 42,
                  mtimeMs: 1000,
                  tags: <String>['Travel'],
                  favorite: true,
                ),
              },
            ),
          },
        ),
      ],
    );

    final decoded = serializer.decodeBackup(serializer.encodeBackup(backup));

    expect(decoded, isNotNull);
    expect(decoded!.roots.single.originalPath, '/library/photos');
    final manifest =
        decoded.roots.single.manifestsByRelativeFolder['2026/trip']!;
    expect(manifest.files['IMG.jpg']!.favorite, isTrue);
    expect(manifest.tags['Travel']!.color, 0xFF0000FF);
  });

  test('rejects unsupported versions and legacy standalone manifests', () {
    final unsupported = jsonEncode(<String, dynamic>{
      'schema': kSidecarBackupSchema,
      'version': kSidecarBackupVersion + 1,
      'roots': <dynamic>[],
    });
    final legacy = serializer.encode(
      SidecarManifest(generatedAt: DateTime(2026)),
    );

    expect(serializer.decodeBackup(unsupported), isNull);
    expect(serializer.decodeBackup(legacy), isNull);
  });

  test('rejects relative paths that escape a mapped root', () {
    final unsafe = jsonEncode(<String, dynamic>{
      'schema': kSidecarBackupSchema,
      'version': kSidecarBackupVersion,
      'generatedAt': DateTime.utc(2026).toIso8601String(),
      'roots': <dynamic>[
        <String, dynamic>{
          'originalPath': '/library',
          'name': 'library',
          'manifests': <String, dynamic>{
            '../outside': SidecarManifest(generatedAt: DateTime(2026)).toJson(),
          },
        },
      ],
    });

    expect(serializer.decodeBackup(unsafe), isNull);
  });

  test('rejects embedded file names that escape their folder', () {
    final unsafe = jsonEncode(<String, dynamic>{
      'schema': kSidecarBackupSchema,
      'version': kSidecarBackupVersion,
      'generatedAt': DateTime.utc(2026).toIso8601String(),
      'roots': <dynamic>[
        <String, dynamic>{
          'originalPath': '/library',
          'name': 'library',
          'manifests': <String, dynamic>{
            '.': SidecarManifest(
              generatedAt: DateTime(2026),
              files: const <String, SidecarFileEntry>{
                '../outside.jpg': SidecarFileEntry(size: 1, mtimeMs: 1),
              },
            ).toJson(),
          },
        },
      ],
    });

    expect(serializer.decodeBackup(unsafe), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_backup.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_import_preparation.dart';
import 'package:media_fast_view/features/sidecar/domain/entities/sidecar_manifest.dart';
import 'package:media_fast_view/features/sidecar/presentation/widgets/sidecar_root_mapping_dialog.dart';

DirectoryEntity _currentRoot() => DirectoryEntity(
  id: 'current-root',
  path: '/new/photos',
  name: 'photos',
  thumbnailPath: null,
  tagIds: const <String>[],
  lastModified: DateTime(2026),
);

SidecarImportPreparation _preparation() {
  final savedRoot = const SidecarBackupRoot(
    originalPath: '/old/photos',
    name: 'photos',
    manifestsByRelativeFolder: <String, SidecarManifest>{},
  );
  return SidecarImportPreparation(
    backup: SidecarBackup(
      generatedAt: DateTime(2026),
      roots: <SidecarBackupRoot>[savedRoot],
    ),
    currentRoots: <DirectoryEntity>[_currentRoot()],
    automaticRootMappings: const <String, String>{},
    unmatchedRoots: <SidecarBackupRoot>[savedRoot],
  );
}

void main() {
  testWidgets('maps a moved saved root to a current tracked root', (
    tester,
  ) async {
    Map<String, String?>? result;
    final preparation = _preparation();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showSidecarRootMappingDialog(context, preparation);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip this folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('photos — /new/photos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Load'));
    await tester.pumpAndSettle();

    expect(result, <String, String?>{'/old/photos': 'current-root'});
  });

  testWidgets('allows an unmatched saved root to be skipped', (tester) async {
    Map<String, String?>? result;
    final preparation = _preparation();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showSidecarRootMappingDialog(context, preparation);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Load'));
    await tester.pumpAndSettle();

    expect(result, <String, String?>{'/old/photos': null});
  });
}

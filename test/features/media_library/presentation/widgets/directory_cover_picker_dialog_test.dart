import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/reset_directory_cover_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/set_directory_cover_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_cover_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_cover_picker_dialog.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

class _MemoryCoverRepository implements DirectoryCoverRepository {
  _MemoryCoverRepository([this.cover]);

  DirectoryCoverEntity? cover;

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {
    this.cover = cover;
  }

  @override
  Future<void> removeCover(String directoryPath) async {
    cover = null;
  }

  @override
  Future<void> clearCovers() async => cover = null;

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async {
    return cover?.directoryPath == directoryPath ? cover : null;
  }

  @override
  Future<void> rebaseDirectoryTree({
    required String oldRootPath,
    required String newRootPath,
  }) async {}

  @override
  Future<void> reconcileMediaMove({
    required String oldPath,
    required String newPath,
  }) async {}

  @override
  Future<void> removeCoverForSource(String sourcePath) async => cover = null;

  @override
  Future<void> removeCoversUnder(String directoryPath) async => cover = null;
}

MediaEntity _media(String name, MediaType type) {
  return MediaEntity(
    id: name,
    path: '/library/folder/$name',
    name: name,
    type: type,
    size: 10,
    lastModified: DateTime(2025),
    tagIds: const <String>[],
    directoryId: 'folder',
  );
}

Widget _subject(
  _MemoryCoverRepository repository,
  List<MediaEntity> candidates,
) {
  return ProviderScope(
    overrides: <Override>[
      directoryCoverRepositoryProvider.overrideWithValue(repository),
      setDirectoryCoverUseCaseProvider.overrideWithValue(
        SetDirectoryCoverUseCase(repository),
      ),
      resetDirectoryCoverUseCaseProvider.overrideWithValue(
        ResetDirectoryCoverUseCase(repository),
      ),
      directoryCoverProvider.overrideWith(
        (ref, path) => repository.getCover(path),
      ),
      directoryCoverCandidatesProvider.overrideWith((ref, query) => candidates),
      thumbnailProvider.overrideWith(
        (ref, request) => throw UnsupportedError('thumbnail not needed'),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => DirectoryCoverPickerDialog.show(
              context,
              directoryPath: '/library/folder',
              directoryName: 'Folder',
            ),
            child: const Text('Open picker'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'selects up to four images and supports removal and replacement',
    (tester) async {
      final repository = _MemoryCoverRepository();
      final candidates = <MediaEntity>[
        _media('first.jpg', MediaType.image),
        _media('second.jpg', MediaType.image),
        _media('third.jpg', MediaType.image),
        _media('fourth.jpg', MediaType.image),
        _media('fifth.jpg', MediaType.image),
        _media('ignored.mp4', MediaType.video),
        _media('._metadata.jpg', MediaType.image),
      ];
      await tester.pumpWidget(_subject(repository, candidates));

      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(find.text('ignored.mp4'), findsNothing);
      expect(find.text('._metadata.jpg'), findsNothing);
      expect(find.text('0 of 4 images selected'), findsOneWidget);

      for (final name in <String>[
        'first.jpg',
        'second.jpg',
        'third.jpg',
        'fourth.jpg',
      ]) {
        await tester.ensureVisible(find.text(name));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name));
        await tester.pump();
      }
      expect(find.text('4 of 4 images selected'), findsOneWidget);

      await tester.ensureVisible(find.text('fifth.jpg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('fifth.jpg'));
      await tester.pump();
      expect(
        find.textContaining('You can select up to 4 images'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('second.jpg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second.jpg'));
      await tester.pump();
      await tester.ensureVisible(find.text('fifth.jpg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('fifth.jpg'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.cover?.sourceFileNames, <String>[
        'first.jpg',
        'third.jpg',
        'fourth.jpg',
        'fifth.jpg',
      ]);
      expect(find.byType(DirectoryCoverPickerDialog), findsNothing);
    },
  );

  testWidgets('highlights the current cover and restores automatic previews', (
    tester,
  ) async {
    final repository = _MemoryCoverRepository(
      DirectoryCoverEntity.media(
        directoryPath: '/library/folder',
        sourceFileName: 'current.jpg',
        mediaType: MediaType.image,
        updatedAt: DateTime(2025),
      ),
    );
    await tester.pumpWidget(
      _subject(repository, <MediaEntity>[
        _media('current.jpg', MediaType.image),
      ]),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('directory-cover-selection-position-1')),
      findsOneWidget,
    );
    expect(find.text('1 of 4 images selected'), findsOneWidget);
    await tester.tap(find.text('Use automatic'));
    await tester.pumpAndSettle();

    expect(repository.cover, isNull);
    expect(find.byType(DirectoryCoverPickerDialog), findsNothing);
  });

  testWidgets('persists an explicit no-cover choice', (tester) async {
    final repository = _MemoryCoverRepository();
    await tester.pumpWidget(
      _subject(repository, <MediaEntity>[
        _media('available.jpg', MediaType.image),
      ]),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No cover'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.cover?.mode, DirectoryCoverMode.none);
    expect(find.byType(DirectoryCoverPickerDialog), findsNothing);
  });

  testWidgets('disables Save when no valid image is selected', (tester) async {
    final repository = _MemoryCoverRepository();
    await tester.pumpWidget(
      _subject(repository, <MediaEntity>[
        _media('ignored.mp4', MediaType.video),
        _media('._ignored.jpg', MediaType.image),
      ]),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull);
    expect(find.text('0 of 4 images selected'), findsOneWidget);
  });
}

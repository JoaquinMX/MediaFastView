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
  testWidgets('selects and saves a direct-child cover', (tester) async {
    final repository = _MemoryCoverRepository();
    final candidates = <MediaEntity>[
      _media('first.jpg', MediaType.image),
      _media('chosen.mp4', MediaType.video),
    ];
    await tester.pumpWidget(_subject(repository, candidates));

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('chosen.mp4'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.cover?.sourceFileName, 'chosen.mp4');
    expect(repository.cover?.mediaType, MediaType.video);
    expect(find.byType(DirectoryCoverPickerDialog), findsNothing);
  });

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

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
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
}

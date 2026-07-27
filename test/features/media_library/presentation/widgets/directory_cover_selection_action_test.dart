import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/set_directory_cover_use_case.dart';
import 'package:media_fast_view/features/media_library/presentation/screens/media_grid_screen.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_cover_selection_action.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

class _MemoryCoverRepository implements DirectoryCoverRepository {
  _MemoryCoverRepository({this.saveCompleter, this.saveError});

  final Completer<void>? saveCompleter;
  final Object? saveError;
  DirectoryCoverEntity? savedCover;

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {
    savedCover = cover;
    if (saveError case final error?) {
      throw error;
    }
    await saveCompleter?.future;
  }

  @override
  Future<void> clearCovers() async {}

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async => null;

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
  Future<void> removeCover(String directoryPath) async {}

  @override
  Future<void> removeCoverForSource(String sourcePath) async {}

  @override
  Future<void> removeCoversUnder(String directoryPath) async {}
}

MediaEntity _media(String name, {MediaType type = MediaType.image}) {
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
  _MemoryCoverRepository repository, {
  required List<MediaEntity> selectedImages,
  required VoidCallback onSaved,
}) {
  return ProviderScope(
    overrides: <Override>[
      setDirectoryCoverUseCaseProvider.overrideWithValue(
        SetDirectoryCoverUseCase(repository),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            DirectoryCoverSelectionAction(
              directoryPath: '/library/folder',
              selectedImages: selectedImages,
              onSaved: onSaved,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('directoryCoverImagesForSelection', () {
    final visibleMedia = <MediaEntity>[
      _media('third.jpg'),
      _media('first.jpg'),
      _media('second.jpg'),
      _media('movie.mp4', type: MediaType.video),
      _media('nested', type: MediaType.directory),
      _media('._metadata.jpg'),
    ];

    test('accepts one through four images in visible grid order', () {
      for (var count = 1; count <= 4; count += 1) {
        final images = List<MediaEntity>.generate(
          count,
          (index) => _media('$index.jpg'),
        );
        expect(
          directoryCoverImagesForSelection(
            visibleMedia: images,
            selectedMediaIds: images.reversed.map((item) => item.id).toSet(),
          ),
          images,
        );
      }

      expect(
        directoryCoverImagesForSelection(
          visibleMedia: visibleMedia,
          selectedMediaIds: <String>{'second.jpg', 'third.jpg', 'first.jpg'},
        ).map((item) => item.name),
        <String>['third.jpg', 'first.jpg', 'second.jpg'],
      );
    });

    test('rejects incomplete, excessive, mixed, and excluded selections', () {
      expect(
        directoryCoverImagesForSelection(
          visibleMedia: visibleMedia,
          selectedMediaIds: const <String>{},
        ),
        isEmpty,
      );
      expect(
        directoryCoverImagesForSelection(
          visibleMedia: List<MediaEntity>.generate(
            5,
            (index) => _media('$index.jpg'),
          ),
          selectedMediaIds: <String>{
            for (var index = 0; index < 5; index++) '$index.jpg',
          },
        ),
        isEmpty,
      );
      expect(
        directoryCoverImagesForSelection(
          visibleMedia: visibleMedia,
          selectedMediaIds: <String>{'first.jpg', 'movie.mp4'},
        ),
        isEmpty,
      );
      expect(
        directoryCoverImagesForSelection(
          visibleMedia: visibleMedia,
          selectedMediaIds: <String>{'nested'},
        ),
        isEmpty,
      );
      expect(
        directoryCoverImagesForSelection(
          visibleMedia: visibleMedia,
          selectedMediaIds: <String>{'._metadata.jpg'},
        ),
        isEmpty,
      );
      expect(
        directoryCoverImagesForSelection(
          visibleMedia: visibleMedia,
          selectedMediaIds: <String>{'first.jpg', 'hidden.jpg'},
        ),
        isEmpty,
      );
    });
  });

  testWidgets('saves directly, preserves order, and reports success', (
    tester,
  ) async {
    final repository = _MemoryCoverRepository();
    var savedCount = 0;
    await tester.pumpWidget(
      _subject(
        repository,
        selectedImages: <MediaEntity>[
          _media('second.jpg'),
          _media('first.jpg'),
        ],
        onSaved: () => savedCount += 1,
      ),
    );

    await tester.tap(find.byTooltip(DirectoryCoverSelectionAction.actionLabel));
    await tester.pumpAndSettle();

    expect(repository.savedCover?.sourceFileNames, <String>[
      'second.jpg',
      'first.jpg',
    ]);
    expect(savedCount, 1);
    expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
    expect(find.text('Use as cover'), findsOneWidget);
    expect(find.text('Set 2 images as the directory cover'), findsOneWidget);
  });

  testWidgets('stays disabled while saving', (tester) async {
    final saveCompleter = Completer<void>();
    final repository = _MemoryCoverRepository(saveCompleter: saveCompleter);
    await tester.pumpWidget(
      _subject(
        repository,
        selectedImages: <MediaEntity>[_media('cover.jpg')],
        onSaved: () {},
      ),
    );

    await tester.tap(find.byTooltip(DirectoryCoverSelectionAction.actionLabel));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(DirectoryCoverSelectionAction.actionKey),
          )
          .onPressed,
      isNull,
    );

    saveCompleter.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('retains the caller selection callback on failure', (
    tester,
  ) async {
    final repository = _MemoryCoverRepository(
      saveError: StateError('save failed'),
    );
    var savedCount = 0;
    await tester.pumpWidget(
      _subject(
        repository,
        selectedImages: <MediaEntity>[_media('cover.jpg')],
        onSaved: () => savedCount += 1,
      ),
    );

    await tester.tap(find.byTooltip(DirectoryCoverSelectionAction.actionLabel));
    await tester.pumpAndSettle();

    expect(savedCount, 0);
    expect(find.textContaining('save failed'), findsOneWidget);
    expect(find.byKey(DirectoryCoverSelectionAction.actionKey), findsOneWidget);
  });

  testWidgets('uses a compact filled action on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    try {
      await tester.pumpWidget(
        _subject(
          _MemoryCoverRepository(),
          selectedImages: <MediaEntity>[_media('cover.jpg')],
          onSaved: () {},
        ),
      );

      expect(
        tester
            .getSize(find.byKey(DirectoryCoverSelectionAction.actionKey))
            .height,
        40,
      );
      expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
      expect(find.text('Use as cover'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

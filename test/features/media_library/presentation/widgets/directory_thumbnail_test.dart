import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
import 'package:media_fast_view/features/thumbnails/presentation/file_thumbnail.dart';
import 'package:media_fast_view/features/thumbnails/presentation/media_thumbnail.dart';
import 'package:media_fast_view/features/thumbnails/presentation/thumbnail_providers.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

class _RecordingCoverRepository implements DirectoryCoverRepository {
  _RecordingCoverRepository([this.cover]);

  final removedPaths = <String>[];
  DirectoryCoverEntity? cover;

  @override
  Future<void> removeCover(String directoryPath) async {
    removedPaths.add(directoryPath);
    cover = null;
  }

  @override
  Future<void> clearCovers() async {}

  @override
  Future<DirectoryCoverEntity?> getCover(String directoryPath) async => cover;

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
  Future<void> removeCoverForSource(String sourcePath) async {}

  @override
  Future<void> removeCoversUnder(String directoryPath) async {}

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {
    this.cover = cover;
  }
}

DirectoryImagePreview _image(int index) {
  return DirectoryImagePreview(sourcePath: '/library/folder/$index.jpg');
}

DirectoryCustomPreview _customPreview() {
  return DirectoryCustomPreview(
    media: MediaEntity(
      id: 'cover',
      path: '/library/folder/cover.jpg',
      name: 'cover.jpg',
      type: MediaType.image,
      size: 1,
      lastModified: DateTime(2025),
      tagIds: const <String>[],
      directoryId: 'folder',
    ),
  );
}

Widget _subject(
  DirectoryPreviewCatalog catalog, {
  DirectoryCoverRepository? repository,
  double width = 120,
  double height = 80,
  bool failPreviewMedia = false,
}) {
  return ProviderScope(
    overrides: <Override>[
      directoryPreviewCatalogProvider.overrideWith((ref, query) => catalog),
      directoryCoverRepositoryProvider.overrideWithValue(
        repository ?? _RecordingCoverRepository(),
      ),
      if (failPreviewMedia)
        previewImageMediaProvider.overrideWith(
          (ref, path) => throw StateError('Preview image unavailable'),
        ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          height: height,
          child: DirectoryThumbnail(
            directoryPath: '/library/folder',
            placeholderBuilder: (_) => const ColoredBox(
              key: Key('directory-preview-loading'),
              color: Colors.grey,
            ),
            emptyBuilder: (_) => const ColoredBox(
              key: Key('directory-preview-empty'),
              color: Colors.blue,
            ),
            errorBuilder: (_) => const ColoredBox(
              key: Key('directory-preview-error'),
              color: Colors.red,
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _tile(int index) =>
    find.byKey(Key('directory-preview-collage-tile-$index'));

void main() {
  testWidgets(
    'renders cached video thumbnails directly in an automatic collage',
    (tester) async {
      const thumbnailPath = '/cache/video.jpg';
      await tester.pumpWidget(
        _subject(
          const DirectoryPreviewCatalog(
            previews: <DirectoryPreview>[
              DirectoryVideoPreview(
                sourcePath: '/library/folder/video.mp4',
                thumbnailPath: thumbnailPath,
              ),
            ],
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as FileImage).file.path, thumbnailPath);
      expect(find.byType(FileThumbnail), findsNothing);
      expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);
    },
  );

  testWidgets('delegates automatic image previews to the lazy file thumbnail', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(
        const DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[
            DirectoryImagePreview(sourcePath: '/library/folder/cover.jpg'),
          ],
        ),
      ),
    );

    expect(find.byType(FileThumbnail), findsOneWidget);
    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);
  });

  testWidgets('uses the collage renderer for a custom cover at rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(
        DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[_customPreview(), _image(1)],
        ),
      ),
    );

    expect(find.byType(MediaThumbnail), findsOneWidget);
    expect(find.byKey(DirectoryPreviewCollage.collageKey), findsOneWidget);
    expect(_tile(0), findsOneWidget);
  });

  testWidgets('uses the empty fallback when no preview is available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(const DirectoryPreviewCatalog(previews: <DirectoryPreview>[])),
    );

    expect(find.byKey(const Key('directory-preview-empty')), findsOneWidget);
  });

  testWidgets('keeps an individual collage failure inside its neutral cell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _subject(
        const DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[
            DirectoryImagePreview(sourcePath: '/missing/automatic.jpg'),
          ],
        ),
        failPreviewMedia: true,
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('directory-preview-collage-failure-0')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('directory-preview-empty')), findsNothing);
  });

  testWidgets('clears a missing custom cover after rendering its fallback', (
    tester,
  ) async {
    final repository = _RecordingCoverRepository(
      DirectoryCoverEntity.images(
        directoryPath: '/library/folder',
        sourceFileNames: <String>['missing.jpg'],
        updatedAt: DateTime(2025),
      ),
    );
    await tester.pumpWidget(
      _subject(
        const DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[
            DirectoryImagePreview(sourcePath: '/library/folder/automatic.jpg'),
          ],
          missingCustomCoverFileNames: <String>['missing.jpg'],
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.removedPaths, <String>['/library/folder']);
  });

  testWidgets('keeps valid custom tiles while reconciling a missing one', (
    tester,
  ) async {
    final repository = _RecordingCoverRepository(
      DirectoryCoverEntity.images(
        directoryPath: '/library/folder',
        sourceFileNames: <String>['cover.jpg', 'missing.jpg'],
        updatedAt: DateTime(2025),
      ),
    );
    await tester.pumpWidget(
      _subject(
        DirectoryPreviewCatalog(
          previews: <DirectoryPreview>[_customPreview(), _image(1)],
          missingCustomCoverFileNames: const <String>['missing.jpg'],
        ),
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.cover?.sourceFileNames, <String>['cover.jpg']);
    expect(find.byType(MediaThumbnail), findsOneWidget);
  });

  group('custom collage layouts', () {
    for (var count = 1; count <= 4; count += 1) {
      testWidgets('renders $count selected image tiles', (tester) async {
        await tester.pumpWidget(
          _subject(
            DirectoryPreviewCatalog(
              previews: <DirectoryPreview>[
                for (var index = 0; index < count; index += 1)
                  DirectoryCustomPreview(
                    media: MediaEntity(
                      id: '$index',
                      path: '/library/folder/$index.jpg',
                      name: '$index.jpg',
                      type: MediaType.image,
                      size: 1,
                      lastModified: DateTime(2025),
                      tagIds: const <String>[],
                      directoryId: 'folder',
                    ),
                  ),
                _image(99),
              ],
            ),
          ),
        );

        expect(find.byType(MediaThumbnail), findsNWidgets(count));
        expect(_tile(count - 1), findsOneWidget);
        expect(_tile(count), findsNothing);
      });
    }
  });

  group('automatic collage layouts', () {
    testWidgets('one preview fills the frame', (tester) async {
      await tester.pumpWidget(
        _subject(
          DirectoryPreviewCatalog(previews: <DirectoryPreview>[_image(0)]),
          width: 120,
          height: 100,
        ),
      );

      final collage = tester.getRect(
        find.byKey(DirectoryPreviewCollage.collageKey),
      );
      expect(tester.getRect(_tile(0)), collage);
    });

    testWidgets('two previews split the frame evenly', (tester) async {
      await tester.pumpWidget(
        _subject(
          DirectoryPreviewCatalog(
            previews: <DirectoryPreview>[_image(0), _image(1)],
          ),
          width: 120,
          height: 100,
        ),
      );

      final first = tester.getRect(_tile(0));
      final second = tester.getRect(_tile(1));
      expect(first.width, closeTo(second.width, 0.1));
      expect(first.height, closeTo(second.height, 0.1));
      expect(second.left, greaterThan(first.left));
    });

    testWidgets('three previews reserve a large left tile', (tester) async {
      await tester.pumpWidget(
        _subject(
          DirectoryPreviewCatalog(
            previews: <DirectoryPreview>[_image(0), _image(1), _image(2)],
          ),
          width: 120,
          height: 100,
        ),
      );

      final left = tester.getRect(_tile(0));
      final topRight = tester.getRect(_tile(1));
      final bottomRight = tester.getRect(_tile(2));
      expect(left.width, greaterThan(topRight.width));
      expect(left.height, greaterThan(topRight.height));
      expect(bottomRight.top, greaterThan(topRight.top));
      expect(bottomRight.left, closeTo(topRight.left, 0.1));
    });

    testWidgets('four previews form quadrants', (tester) async {
      await tester.pumpWidget(
        _subject(
          DirectoryPreviewCatalog(
            previews: <DirectoryPreview>[
              _image(0),
              _image(1),
              _image(2),
              _image(3),
            ],
          ),
          width: 120,
          height: 100,
        ),
      );

      final topLeft = tester.getRect(_tile(0));
      final topRight = tester.getRect(_tile(1));
      final bottomLeft = tester.getRect(_tile(2));
      final bottomRight = tester.getRect(_tile(3));
      expect(topLeft.width, closeTo(topRight.width, 0.1));
      expect(topLeft.height, closeTo(bottomLeft.height, 0.1));
      expect(topRight.left, greaterThan(topLeft.left));
      expect(bottomLeft.top, greaterThan(topLeft.top));
      expect(bottomRight.left, closeTo(topRight.left, 0.1));
      expect(bottomRight.top, closeTo(bottomLeft.top, 0.1));
    });
  });
}

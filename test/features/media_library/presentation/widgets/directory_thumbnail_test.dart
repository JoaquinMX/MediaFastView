import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_cover_entity.dart';
import 'package:media_fast_view/features/media_library/domain/repositories/directory_cover_repository.dart';
import 'package:media_fast_view/features/thumbnails/presentation/file_thumbnail.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';

class _RecordingCoverRepository implements DirectoryCoverRepository {
  final removedPaths = <String>[];

  @override
  Future<void> removeCover(String directoryPath) async {
    removedPaths.add(directoryPath);
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
  Future<void> removeCoverForSource(String sourcePath) async {}

  @override
  Future<void> removeCoversUnder(String directoryPath) async {}

  @override
  Future<void> saveCover(DirectoryCoverEntity cover) async {}
}

Widget _subject(
  DirectoryPreview? preview, {
  DirectoryCoverRepository? repository,
}) {
  return ProviderScope(
    overrides: <Override>[
      directoryPreviewProvider.overrideWith((ref, path) => preview),
      directoryCoverRepositoryProvider.overrideWithValue(
        repository ?? _RecordingCoverRepository(),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 80,
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

void main() {
  testWidgets('renders cached video thumbnails directly', (tester) async {
    const thumbnailPath = '/cache/video.jpg';

    await tester.pumpWidget(
      _subject(
        const DirectoryVideoPreview(
          sourcePath: '/library/folder/video.mp4',
          thumbnailPath: thumbnailPath,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as FileImage).file.path, thumbnailPath);
    expect(find.byType(FileThumbnail), findsNothing);
  });

  testWidgets('delegates image previews to FileThumbnail', (tester) async {
    await tester.pumpWidget(
      _subject(
        const DirectoryImagePreview(sourcePath: '/library/folder/cover.jpg'),
      ),
    );

    expect(find.byType(FileThumbnail), findsOneWidget);
  });

  testWidgets('uses the empty fallback when no preview is available', (
    tester,
  ) async {
    await tester.pumpWidget(_subject(null));

    expect(find.byKey(const Key('directory-preview-empty')), findsOneWidget);
  });

  testWidgets('clears a missing custom cover after rendering its fallback', (
    tester,
  ) async {
    final repository = _RecordingCoverRepository();
    await tester.pumpWidget(
      _subject(
        const DirectoryImagePreview(
          sourcePath: '/library/folder/automatic.jpg',
          hasStaleCustomCover: true,
        ),
        repository: repository,
      ),
    );

    await tester.pumpAndSettle();

    expect(repository.removedPaths, <String>['/library/folder']);
  });
}

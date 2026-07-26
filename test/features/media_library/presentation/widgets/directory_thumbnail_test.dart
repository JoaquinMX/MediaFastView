import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
import 'package:media_fast_view/features/thumbnails/presentation/file_thumbnail.dart';

Widget _subject(DirectoryPreview? preview) {
  return ProviderScope(
    overrides: <Override>[
      directoryPreviewProvider.overrideWith((ref, path) => preview),
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
}

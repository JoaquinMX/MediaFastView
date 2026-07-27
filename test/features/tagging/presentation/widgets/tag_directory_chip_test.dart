import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/models/directory_preview.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_thumbnail.dart';
import 'package:media_fast_view/features/tagging/presentation/widgets/tag_directory_chip.dart';

const DirectoryPreviewCatalog _catalog = DirectoryPreviewCatalog(
  previews: <DirectoryPreview>[
    DirectoryVideoPreview(
      sourcePath: '/library/chip/one.mp4',
      thumbnailPath: '/cache/one.jpg',
    ),
    DirectoryVideoPreview(
      sourcePath: '/library/chip/two.mp4',
      thumbnailPath: '/cache/two.jpg',
    ),
  ],
);

DirectoryEntity _directory() {
  return DirectoryEntity(
    id: 'chip-directory',
    path: '/library/chip',
    name: 'Chip folder',
    thumbnailPath: null,
    tagIds: const <String>[],
    lastModified: DateTime(2025),
  );
}

void main() {
  testWidgets(
    'directory chip arrows browse the popup without selecting its chip',
    (tester) async {
      var activationCount = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            directoryPreviewCatalogProvider.overrideWith(
              (ref, query) => _catalog,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: TagDirectoryChip(
                  directory: _directory(),
                  mediaCount: 2,
                  onTap: () => activationCount += 1,
                ),
              ),
            ),
          ),
        ),
      );

      // Keyboard traversal focuses the chip while leaving it unselected.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.addPointer(location: const Offset(0, 0)),
      );
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(find.byType(FilterChip))),
      );
      await tester.pump();

      expect(find.byKey(DirectoryPreviewCarousel.carouselKey), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));

      expect(
        find.byKey(DirectoryPreviewCarousel.previewKey(1)),
        findsOneWidget,
      );
      expect(activationCount, 0);
    },
  );
}

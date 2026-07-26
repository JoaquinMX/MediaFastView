import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/media_library/domain/entities/directory_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_cover_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/providers/directory_preview_providers.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_cover_picker_dialog.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/directory_grid_item.dart';

void main() {
  testWidgets('opens the cover picker directly from a root directory card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          directoryCoverProvider.overrideWith((ref, path) => null),
          directoryCoverCandidatesProvider.overrideWith(
            (ref, query) => const [],
          ),
          directoryPreviewProvider.overrideWith((ref, path) => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 320,
              child: DirectoryGridItem(
                directory: DirectoryEntity(
                  id: 'root',
                  path: '/library/root',
                  name: 'Root',
                  thumbnailPath: null,
                  tagIds: const [],
                  lastModified: DateTime(2025),
                ),
                onTap: () {},
                onDelete: () {},
                onAssignTags: (_) async {},
                onSelectionToggle: () {},
                isSelected: false,
                isSelectionMode: false,
                showTaggedMediaCounts: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(DirectoryGridItem),
        matching: find.byType(PopupMenuButton),
      ),
      findsNothing,
    );

    await tester.tap(find.byTooltip('Choose directory cover'));
    await tester.pumpAndSettle();

    expect(find.byType(DirectoryCoverPickerDialog), findsOneWidget);
    expect(find.text('No cover'), findsOneWidget);
  });
}

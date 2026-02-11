import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/core/services/file_service.dart';
import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/media_grid_item.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';

class _MockFileService extends Mock implements FileService {}

void main() {
  late _MockFileService mockFileService;

  setUp(() {
    mockFileService = _MockFileService();
  });

  group('MediaGridItem', () {
    late MediaEntity testMedia;

    setUp(() {
      testMedia = MediaEntity(
        id: '1',
        path: '/test/image.jpg',
        name: 'image.jpg',
        type: MediaType.image,
        size: 1024,
        lastModified: DateTime(2023, 1, 1),
        tagIds: ['tag1'],
        directoryId: 'dir1',
      );
    });

    testWidgets('renders image media type', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MediaGridItem(
                media: testMedia,
                onTap: () {},
                onSelectionToggle: () {},
                isSelected: false,
                isSelectionMode: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders directory media type', (WidgetTester tester) async {
      final dirMedia = testMedia.copyWith(type: MediaType.directory);

      when(mockFileService.getDirectoryContents(any)).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fileServiceProvider.overrideWithValue(mockFileService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MediaGridItem(
                media: dirMedia,
                onTap: () {},
                onSelectionToggle: () {},
                isSelected: false,
                isSelectionMode: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.folder), findsOneWidget);
    });

    testWidgets('renders video media type', (WidgetTester tester) async {
      final videoMedia = testMedia.copyWith(type: MediaType.video);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaGridItem(
              media: videoMedia,
              onTap: () {},
              onSelectionToggle: () {},
              isSelected: false,
              isSelectionMode: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.video_file), findsOneWidget);
    });

    testWidgets(
      'reuses text preview future across rebuilds and refreshes on path change',
      (WidgetTester tester) async {
        final tempDirectory = await Directory.systemTemp.createTemp(
          'media_grid_item_test_',
        );
        addTearDown(() async {
          if (await tempDirectory.exists()) {
            await tempDirectory.delete(recursive: true);
          }
        });

        final firstFile = File('${tempDirectory.path}/first.txt');
        final secondFile = File('${tempDirectory.path}/second.txt');
        await firstFile.writeAsString('first file preview');
        await secondFile.writeAsString('second file preview');

        final firstMedia = MediaEntity(
          id: 'text-1',
          path: firstFile.path,
          name: 'first.txt',
          type: MediaType.text,
          size: 16,
          lastModified: DateTime(2023, 1, 1),
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MediaGridItem(
                  media: firstMedia,
                  onTap: () {},
                  onSelectionToggle: () {},
                  isSelected: false,
                  isSelectionMode: false,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('first file preview'), findsOneWidget);

        await firstFile.writeAsString('updated first file preview');

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MediaGridItem(
                  media: firstMedia,
                  onTap: () {},
                  onSelectionToggle: () {},
                  isSelected: false,
                  isSelectionMode: false,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('first file preview'), findsOneWidget);
        expect(find.text('updated first file preview'), findsNothing);

        final secondMedia = firstMedia.copyWith(
          id: 'text-2',
          path: secondFile.path,
          name: 'second.txt',
          size: 17,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: MediaGridItem(
                  media: secondMedia,
                  onTap: () {},
                  onSelectionToggle: () {},
                  isSelected: false,
                  isSelectionMode: false,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('second file preview'), findsOneWidget);
      },
    );
  });
}

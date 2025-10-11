import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/media_library/domain/entities/media_entity.dart';
import 'package:media_fast_view/features/media_library/presentation/widgets/media_grid_item.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import '../mocks.mocks.dart';

void main() {
  late MockSharedPreferences mockSharedPreferences;
  late MockFileService mockFileService;

  setUp(() {
    mockSharedPreferences = MockSharedPreferences();
    mockFileService = MockFileService();
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
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
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

      // Wait for the FutureBuilder to complete
      await tester.pumpAndSettle();

      expect(find.byType(Card), findsOneWidget);
      // The widget should render (either with thumbnail or fallback image)
      expect(find.byType(Container), findsWidgets); // Loading or error containers
    });

    testWidgets('renders directory media type', (WidgetTester tester) async {
      final dirMedia = testMedia.copyWith(type: MediaType.directory);

      when(mockFileService.getDirectoryContents(any)).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
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
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
          ],
          child: MaterialApp(
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
        ),
      );

      expect(find.byIcon(Icons.video_file), findsOneWidget);
    });
  });
}

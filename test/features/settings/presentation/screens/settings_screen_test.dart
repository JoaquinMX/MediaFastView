import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import 'package:media_fast_view/features/settings/presentation/screens/settings_screen.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/clear_tag_assignments_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/clear_tags_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/clear_media_cache_use_case.dart';
import 'package:media_fast_view/shared/providers/auto_navigate_sibling_directories_provider.dart';
import 'package:media_fast_view/shared/providers/delete_from_source_provider.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/providers/slideshow_controls_hide_delay_provider.dart';
import 'package:media_fast_view/shared/providers/theme_provider.dart';
import 'package:media_fast_view/shared/providers/thumbnail_caching_provider.dart';
import 'package:media_fast_view/shared/providers/video_playback_settings_provider.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';

class _TestThemeNotifier extends ThemeNotifier {
  _TestThemeNotifier({ThemeMode initial = ThemeMode.system}) {
    state = initial;
  }

  ThemeMode? lastTheme;

  @override
  Future<void> setThemeMode(ThemeMode themeMode) async {
    lastTheme = themeMode;
    state = themeMode;
  }
}

class _TestThumbnailCachingNotifier extends ThumbnailCachingNotifier {
  _TestThumbnailCachingNotifier({bool initial = true}) {
    state = initial;
  }

  bool? lastValue;

  @override
  Future<void> setThumbnailCaching(bool enabled) async {
    lastValue = enabled;
    state = enabled;
  }
}

class _TestDeleteFromSourceNotifier extends DeleteFromSourceNotifier {
  _TestDeleteFromSourceNotifier({bool initial = false}) {
    state = initial;
  }

  bool? lastValue;

  @override
  Future<void> setDeleteFromSource(bool enabled) async {
    lastValue = enabled;
    state = enabled;
  }
}

class _TestVideoPlaybackSettingsNotifier extends VideoPlaybackSettingsNotifier {
  _TestVideoPlaybackSettingsNotifier({
    VideoPlaybackSettings initial = const VideoPlaybackSettings.initial(),
  }) {
    state = initial;
  }

  bool? lastAutoplay;
  bool? lastLoop;

  @override
  Future<void> setAutoplayVideos(bool enabled) async {
    lastAutoplay = enabled;
    state = state.copyWith(autoplayVideos: enabled);
  }

  @override
  Future<void> setLoopVideos(bool enabled) async {
    lastLoop = enabled;
    state = state.copyWith(loopVideos: enabled);
  }
}

class _TestAutoNavigateSiblingDirectoriesNotifier
    extends AutoNavigateSiblingDirectoriesNotifier {
  _TestAutoNavigateSiblingDirectoriesNotifier({bool initial = false}) {
    state = initial;
  }

  bool? lastValue;

  @override
  Future<void> setAutoNavigateSiblingDirectories(bool enabled) async {
    lastValue = enabled;
    state = enabled;
  }
}

class _TestSlideshowControlsHideDelayNotifier
    extends SlideshowControlsHideDelayNotifier {
  _TestSlideshowControlsHideDelayNotifier({
    Duration initialDelay = const Duration(seconds: 5),
  }) {
    state = initialDelay;
  }

  Duration? lastDelay;

  @override
  Future<void> setDelay(Duration delay) async {
    lastDelay = delay;
    state = delay;
  }
}

class _MockClearMediaCacheUseCase extends Mock
    implements ClearMediaCacheUseCase {}

class _MockTagCacheRefresher extends Mock implements TagCacheRefresher {}

class _MockDirectoryViewModel extends Mock implements DirectoryViewModel {}

class _MockFavoritesViewModel extends Mock implements FavoritesViewModel {}

class _MockClearTagAssignmentsUseCase extends Mock
    implements ClearTagAssignmentsUseCase {}

class _MockClearTagsUseCase extends Mock implements ClearTagsUseCase {}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen preference controls', () {
    testWidgets('updates toggles and dropdowns via notifiers', (tester) async {
      final themeNotifier = _TestThemeNotifier(initial: ThemeMode.light);
      final thumbnailCachingNotifier =
          _TestThumbnailCachingNotifier(initial: true);
      final deleteFromSourceNotifier =
          _TestDeleteFromSourceNotifier(initial: false);
      final playbackNotifier = _TestVideoPlaybackSettingsNotifier(
        initial: const VideoPlaybackSettings(
          autoplayVideos: false,
          loopVideos: false,
        ),
      );
      final siblingNavigationNotifier =
          _TestAutoNavigateSiblingDirectoriesNotifier(initial: false);
      final slideshowNotifier = _TestSlideshowControlsHideDelayNotifier(
        initialDelay: const Duration(seconds: 5),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith((ref) => themeNotifier),
            thumbnailCachingProvider
                .overrideWith((ref) => thumbnailCachingNotifier),
            deleteFromSourceProvider
                .overrideWith((ref) => deleteFromSourceNotifier),
            videoPlaybackSettingsProvider
                .overrideWith((ref) => playbackNotifier),
            autoNavigateSiblingDirectoriesProvider
                .overrideWith((ref) => siblingNavigationNotifier),
            slideshowControlsHideDelayProvider
                .overrideWith((ref) => slideshowNotifier),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<ThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(themeNotifier.lastTheme, ThemeMode.dark);

      final autoplaySwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Autoplay Videos'),
        matching: find.byType(Switch),
      );
      await tester.tap(autoplaySwitch);
      await tester.pumpAndSettle();
      expect(playbackNotifier.lastAutoplay, isTrue);

      final loopSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Loop Videos'),
        matching: find.byType(Switch),
      );
      await tester.tap(loopSwitch);
      await tester.pumpAndSettle();
      expect(playbackNotifier.lastLoop, isTrue);

      final siblingNavigationSwitch = find.descendant(
        of: find.widgetWithText(
          ListTile,
          'Auto-Navigate Sibling Directories',
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(siblingNavigationSwitch);
      await tester.pumpAndSettle();
      expect(siblingNavigationNotifier.lastValue, isTrue);

      final thumbnailCachingSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Thumbnail Caching'),
        matching: find.byType(Switch),
      );
      await tester.tap(thumbnailCachingSwitch);
      await tester.pumpAndSettle();
      expect(thumbnailCachingNotifier.lastValue, isFalse);

      final deleteFromSourceSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Delete From Source'),
        matching: find.byType(Switch),
      );
      await tester.tap(deleteFromSourceSwitch);
      await tester.pumpAndSettle();
      expect(deleteFromSourceNotifier.lastValue, isTrue);

      final slider = find.byType(Slider);
      final sliderWidget = tester.widget<Slider>(slider);
      sliderWidget.onChanged?.call(10);
      await tester.pumpAndSettle();
      expect(slideshowNotifier.lastDelay, const Duration(seconds: 10));
    });
  });

  group('SettingsScreen cache actions', () {
    testWidgets('invokes clear and refresh actions', (tester) async {
      final themeNotifier = _TestThemeNotifier(initial: ThemeMode.light);
      final thumbnailCachingNotifier = _TestThumbnailCachingNotifier();
      final deleteFromSourceNotifier = _TestDeleteFromSourceNotifier();
      final playbackNotifier = _TestVideoPlaybackSettingsNotifier();
      final siblingNavigationNotifier =
          _TestAutoNavigateSiblingDirectoriesNotifier();
      final slideshowNotifier = _TestSlideshowControlsHideDelayNotifier();

      final clearMediaCacheUseCase = _MockClearMediaCacheUseCase();
      final tagCacheRefresher = _MockTagCacheRefresher();
      final directoryViewModel = _MockDirectoryViewModel();
      final favoritesViewModel = _MockFavoritesViewModel();
      final clearTagAssignmentsUseCase = _MockClearTagAssignmentsUseCase();
      final clearTagsUseCase = _MockClearTagsUseCase();

      when(clearMediaCacheUseCase()).thenAnswer((_) async {});
      when(tagCacheRefresher.refresh()).thenAnswer((_) async {});
      when(directoryViewModel.state).thenReturn(const DirectoryLoading());
      when(
        directoryViewModel.addListener(
          any,
          fireImmediately: anyNamed('fireImmediately'),
        ),
      ).thenAnswer((invocation) {
        final listener = invocation.positionalArguments[0] as void Function(
          DirectoryState,
        );
        if (invocation.namedArguments[const Symbol('fireImmediately')] !=
            false) {
          listener(const DirectoryLoading());
        }
        return () {};
      });
      when(favoritesViewModel.state).thenReturn(const FavoritesInitial());
      when(
        favoritesViewModel.addListener(
          any,
          fireImmediately: anyNamed('fireImmediately'),
        ),
      ).thenAnswer((_) => () {});
      when(directoryViewModel.clearDirectories()).thenAnswer((_) async {});
      when(favoritesViewModel.clearAllFavorites()).thenAnswer((_) async {});
      when(clearTagAssignmentsUseCase()).thenAnswer((_) async {});
      when(clearTagsUseCase()).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith((ref) => themeNotifier),
            thumbnailCachingProvider
                .overrideWith((ref) => thumbnailCachingNotifier),
            deleteFromSourceProvider
                .overrideWith((ref) => deleteFromSourceNotifier),
            videoPlaybackSettingsProvider
                .overrideWith((ref) => playbackNotifier),
            autoNavigateSiblingDirectoriesProvider
                .overrideWith((ref) => siblingNavigationNotifier),
            slideshowControlsHideDelayProvider
                .overrideWith((ref) => slideshowNotifier),
            clearMediaCacheUseCaseProvider
                .overrideWithValue(clearMediaCacheUseCase),
            tagCacheRefresherProvider.overrideWithValue(tagCacheRefresher),
            directoryViewModelProvider
                .overrideWith((ref) => directoryViewModel),
            favoritesViewModelProvider
                .overrideWith((ref) => favoritesViewModel),
            clearTagAssignmentsUseCaseProvider
                .overrideWithValue(clearTagAssignmentsUseCase),
            clearTagsUseCaseProvider.overrideWithValue(clearTagsUseCase),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Clean Cached Media'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clean'));
      await tester.pumpAndSettle();
      verify(clearMediaCacheUseCase()).called(1);
      verify(tagCacheRefresher.refresh()).called(1);

      await tester.tap(find.text('Clear Directory Cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      verify(directoryViewModel.clearDirectories()).called(1);

      await tester.tap(find.text('Clear All Favorites'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      verify(favoritesViewModel.clearAllFavorites()).called(1);

      await tester.tap(find.text('Clear All Assigned Tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      verify(clearTagAssignmentsUseCase()).called(1);

      await tester.tap(find.text('Clear All Tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      verify(clearTagsUseCase()).called(1);
    });
  });
}

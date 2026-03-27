import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/media_library/presentation/view_models/directory_grid_view_model.dart';
import 'package:media_fast_view/features/settings/domain/entities/app_settings.dart';
import 'package:media_fast_view/features/settings/domain/entities/playback_settings.dart';
import 'package:media_fast_view/features/settings/domain/repositories/settings_repository.dart';
import 'package:media_fast_view/features/settings/presentation/screens/settings_screen.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/clear_tag_assignments_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/clear_tags_use_case.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/clear_media_cache_use_case.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:media_fast_view/shared/utils/tag_cache_refresher.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({AppSettings? initialSettings})
    : _settings = initialSettings ?? const AppSettings.initial();

  AppSettings _settings;

  AppSettings get settings => _settings;

  @override
  Future<AppSettings> loadSettings() async => _settings;

  @override
  Future<void> saveThemeMode(ThemeMode themeMode) async {
    _settings = _settings.copyWith(themeMode: themeMode);
  }

  @override
  Future<void> saveThumbnailCachingEnabled(bool enabled) async {
    _settings = _settings.copyWith(thumbnailCachingEnabled: enabled);
  }

  @override
  Future<void> saveDeleteFromSourceEnabled(bool enabled) async {
    _settings = _settings.copyWith(deleteFromSourceEnabled: enabled);
  }

  @override
  Future<void> savePlaybackSettings(PlaybackSettings settings) async {
    _settings = _settings.copyWith(playbackSettings: settings);
  }

  @override
  Future<void> saveAutoNavigateSiblingDirectories(bool enabled) async {
    _settings = _settings.copyWith(autoNavigateSiblingDirectories: enabled);
  }

  @override
  Future<void> saveShowDirectoryTaggedMediaCounts(bool enabled) async {
    _settings = _settings.copyWith(showDirectoryTaggedMediaCounts: enabled);
  }

  @override
  Future<void> saveSlideshowControlsHideDelay(Duration delay) async {
    _settings = _settings.copyWith(slideshowControlsHideDelay: delay);
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

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen preference controls', () {
    testWidgets('shows the new switch and persists updated preferences', (
      tester,
    ) async {
      final settingsRepository = _FakeSettingsRepository(
        initialSettings: AppSettings.initial().copyWith(
          themeMode: ThemeMode.light,
          thumbnailCachingEnabled: true,
          deleteFromSourceEnabled: false,
          playbackSettings: PlaybackSettings(
            autoplayVideos: false,
            loopVideos: false,
            startMuted: false,
          ),
          autoNavigateSiblingDirectories: false,
          showDirectoryTaggedMediaCounts: false,
          slideshowControlsHideDelay: Duration(seconds: 5),
        ),
      );

      await _pumpSettingsScreen(
        tester,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
        ],
      );

      expect(
        find.widgetWithText(
          ListTile,
          'Show Directory Tagged Media Counts',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(DropdownButton<ThemeMode>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.themeMode, ThemeMode.dark);

      final autoplaySwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Autoplay Videos'),
        matching: find.byType(Switch),
      );
      await tester.tap(autoplaySwitch);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.playbackSettings.autoplayVideos, isTrue);

      final loopSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Loop Videos'),
        matching: find.byType(Switch),
      );
      await tester.tap(loopSwitch);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.playbackSettings.loopVideos, isTrue);

      final startMutedSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Start Videos Muted'),
        matching: find.byType(Switch),
      );
      await tester.tap(startMutedSwitch);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.playbackSettings.startMuted, isTrue);

      final siblingNavigationSwitch = find.descendant(
        of: find.widgetWithText(
          ListTile,
          'Auto-Navigate Sibling Directories',
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(siblingNavigationSwitch);
      await tester.pumpAndSettle();
      expect(
        settingsRepository.settings.autoNavigateSiblingDirectories,
        isTrue,
      );

      final directoryCountsSwitch = find.descendant(
        of: find.widgetWithText(
          ListTile,
          'Show Directory Tagged Media Counts',
        ),
        matching: find.byType(Switch),
      );
      await tester.tap(directoryCountsSwitch);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.showDirectoryTaggedMediaCounts, isTrue);

      final thumbnailCachingSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Thumbnail Caching'),
        matching: find.byType(Switch),
      );
      await tester.tap(thumbnailCachingSwitch);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.thumbnailCachingEnabled, isFalse);

      final deleteFromSourceSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Delete From Source'),
        matching: find.byType(Switch),
      );
      await tester.tap(deleteFromSourceSwitch);
      await tester.pumpAndSettle();
      expect(settingsRepository.settings.deleteFromSourceEnabled, isTrue);

      final slider = find.byType(Slider);
      final sliderWidget = tester.widget<Slider>(slider);
      sliderWidget.onChanged?.call(10);
      await tester.pumpAndSettle();
      expect(
        settingsRepository.settings.slideshowControlsHideDelay,
        const Duration(seconds: 10),
      );
    });
  });

  group('SettingsScreen cache actions', () {
    testWidgets('invokes clear and refresh actions', (tester) async {
      final settingsRepository = _FakeSettingsRepository();
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

      await _pumpSettingsScreen(
        tester,
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          clearMediaCacheUseCaseProvider.overrideWithValue(clearMediaCacheUseCase),
          tagCacheRefresherProvider.overrideWithValue(tagCacheRefresher),
          directoryViewModelProvider.overrideWith((ref) => directoryViewModel),
          favoritesViewModelProvider.overrideWith((ref) => favoritesViewModel),
          clearTagAssignmentsUseCaseProvider.overrideWithValue(
            clearTagAssignmentsUseCase,
          ),
          clearTagsUseCaseProvider.overrideWithValue(clearTagsUseCase),
        ],
      );

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

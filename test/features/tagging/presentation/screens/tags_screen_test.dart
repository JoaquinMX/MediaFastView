import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_fast_view/features/favorites/domain/use_cases/favorite_media_use_case.dart';
import 'package:media_fast_view/features/favorites/presentation/view_models/favorites_view_model.dart';
import 'package:media_fast_view/features/media_library/domain/use_cases/get_media_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_filter_mode.dart';
import 'package:media_fast_view/features/tagging/domain/enums/tag_media_type_filter.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/assign_tag_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/filter_by_tags_use_case.dart';
import 'package:media_fast_view/features/tagging/domain/use_cases/get_tags_use_case.dart';
import 'package:media_fast_view/features/tagging/presentation/screens/tags_screen.dart';
import 'package:media_fast_view/features/tagging/presentation/view_models/tags_view_model.dart';
import 'package:media_fast_view/features/profiles/domain/entities/profile_entity.dart';
import 'package:media_fast_view/shared/providers/active_profile_provider.dart';
import 'package:media_fast_view/shared/providers/navigation_provider.dart';
import 'package:media_fast_view/shared/providers/profile_providers.dart';
import 'package:media_fast_view/shared/providers/repository_providers.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../view_models/tags_view_model_test.mocks.dart';

/// The real view model, with the loaders that would reach for Isar stubbed out
/// and [clearMediaSelection] counted. The selection logic underneath is the
/// production one — what is on trial here is whether a key press reaches it.
class _StubTagsViewModel extends TagsViewModel {
  _StubTagsViewModel(
    super.getTags,
    super.filterByTags,
    super.favorites,
    super.mediaDataSource,
    super.directories,
    super.assignTag,
  );

  int clearCalls = 0;

  @override
  Future<void> loadTags() async {}

  @override
  Future<void> refreshTags() async {}

  @override
  void clearMediaSelection() {
    clearCalls += 1;
    super.clearMediaSelection();
  }

  /// An empty-but-loaded tab: enough for the grid to exist, with no tiles to
  /// decode image files for.
  void emitLoaded() {
    state = const TagsLoaded(
      sections: [],
      selectedTagIds: {},
      optionalTagIds: {},
      excludedTagIds: {},
      filterMode: TagFilterMode.any,
      mediaTypeFilter: TagMediaTypeFilter.all,
      selectionMode: TagSelectionMode.required,
      libraryDirectories: [],
      selectedDirectoryPaths: {},
      mediaById: {},
    );
  }
}

class _StubFavoritesViewModel extends FavoritesViewModel {
  _StubFavoritesViewModel(super.repository, super.favoriteMedia);

  @override
  Future<void> loadFavorites() async {}
}

/// Stands in for `DirectoryGridScreen`, which needs a repository stack of its
/// own. All this test needs from it is its *focus* shape: an autofocusing [Focus]
/// over an Escape [Shortcuts], sitting first in the stack — the tab that wins the
/// focus at startup and holds it while the Tags tab is in the background.
class _FakeLibraryScreen extends StatefulWidget {
  const _FakeLibraryScreen();

  @override
  State<_FakeLibraryScreen> createState() => _FakeLibraryScreenState();
}

class _FakeLibraryScreenState extends State<_FakeLibraryScreen> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'FakeLibrary');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.escape): const DoNothingIntent(),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: const Scaffold(body: Text('library')),
      ),
    );
  }
}

/// `MainNavigation`, reduced to the part that decides who owns the keyboard.
///
/// The `IndexedStack` is the whole reason these tests exist: it hides the tabs it
/// is not showing behind an `ExcludeFocus`, so pumping [TagsScreen] on its own
/// would let a screen that cannot answer the keyboard in the real app pass.
class _TabShell extends ConsumerWidget {
  const _TabShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(selectedTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: tab.index,
        children: const <Widget>[
          _FakeLibraryScreen(),
          TagsScreen(),
          SizedBox.shrink(),
        ],
      ),
    );
  }
}

void main() {
  late _StubTagsViewModel viewModel;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final tagRepository = MockTagRepository();
    final directoryRepository = MockDirectoryRepository();
    final mediaRepository = MockMediaRepository();
    final favoritesRepository = MockFavoritesRepository();
    final mediaDataSource = MockIsarMediaDataSource();

    when(tagRepository.getTags()).thenAnswer((_) async => const []);
    when(
      favoritesRepository.getFavoriteMediaIds(),
    ).thenAnswer((_) async => const <String>[]);

    viewModel = _StubTagsViewModel(
      GetTagsUseCase(tagRepository),
      FilterByTagsUseCase(
        directoryRepository: directoryRepository,
        mediaRepository: mediaRepository,
      ),
      favoritesRepository,
      mediaDataSource,
      directoryRepository,
      AssignTagUseCase(
        directoryRepository: directoryRepository,
        mediaRepository: mediaRepository,
      ),
    );

    container = ProviderContainer(
      overrides: [
        // Seeded the way `main` does. The app bar's profile switcher reads this,
        // and the notifier throws rather than defaulting — an unseeded profile
        // would silently scope the app to a library that owns nothing.
        activeProfileIdProvider.overrideWith(
          () => ActiveProfileIdNotifier('profile-1'),
        ),
        profilesProvider.overrideWith(
          (ref) async => <ProfileEntity>[
            ProfileEntity(
              id: 'profile-1',
              name: 'Default',
              sortOrder: 0,
              createdAt: DateTime(2024, 1, 1),
            ),
          ],
        ),
        tagsViewModelProvider.overrideWith((ref) => viewModel),
        favoritesViewModelProvider.overrideWith(
          (ref) => _StubFavoritesViewModel(
            favoritesRepository,
            FavoriteMediaUseCase(
              mediaRepository,
              GetMediaUseCase(mediaRepository),
            ),
          ),
        ),
        savedFiltersProvider.overrideWith((ref) async => const []),
      ],
    );
  });

  tearDown(() => container.dispose());

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: _TabShell()),
      ),
    );
    await tester.pump();
  }

  /// Two pumps: the first reveals the tab and runs the post-frame focus request,
  /// the second applies it. This is the real sequence — the focus cannot be taken
  /// any earlier than the frame that lifts the `ExcludeFocus`.
  Future<void> showTab(WidgetTester tester, AppTab tab) async {
    container.read(selectedTabProvider.notifier).state = tab;
    await tester.pump();
    await tester.pump();
  }

  void enterSelectionMode() {
    viewModel.emitLoaded();
    viewModel.toggleMediaSelection('media-1');
  }

  TagsLoaded loaded() => container.read(tagsViewModelProvider) as TagsLoaded;

  group('TagsScreen keyboard shortcuts', () {
    testWidgets('Escape leaves selection mode, as it does in the Library tab', (
      tester,
    ) async {
      await pumpShell(tester);
      await showTab(tester, AppTab.tags);

      enterSelectionMode();
      await tester.pump();
      expect(loaded().isSelectionMode, isTrue);
      expect(loaded().selectedMediaIds, {'media-1'});

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(viewModel.clearCalls, 1);
      expect(loaded().isSelectionMode, isFalse);
      expect(loaded().selectedMediaIds, isEmpty);
    });

    testWidgets('Escape with nothing selected is harmless', (tester) async {
      await pumpShell(tester);
      await showTab(tester, AppTab.tags);

      viewModel.emitLoaded();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(loaded().isSelectionMode, isFalse);
    });

    testWidgets('Escape still works after a trip through another tab', (
      tester,
    ) async {
      // Coming back is not the same as arriving: `autofocus` has already fired
      // and will not fire again, so the tab has to ask for the focus every time.
      await pumpShell(tester);
      await showTab(tester, AppTab.tags);
      await showTab(tester, AppTab.library);
      await showTab(tester, AppTab.tags);

      enterSelectionMode();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(viewModel.clearCalls, 1);
      expect(loaded().isSelectionMode, isFalse);
    });

    testWidgets('a backgrounded Tags tab does not answer the keyboard', (
      tester,
    ) async {
      // The other side of the hand-off: while the Library tab is up, Escape is
      // its shortcut to interpret, not this one's.
      await pumpShell(tester);
      await showTab(tester, AppTab.tags);
      await showTab(tester, AppTab.library);

      enterSelectionMode();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(viewModel.clearCalls, 0);
      expect(loaded().isSelectionMode, isTrue);
    });
  });
}

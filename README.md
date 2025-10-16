# Media Fast View

Media Fast View is a Flutter application for macOS and iOS designed to make large local media libraries fast to browse. It scans directories on disk, persists lightweight metadata, and provides tagging, favorites, and full-screen playback so you can jump from discovery to viewing without leaving the app.

## Overview

- **Platform focus**: Desktop-first experience for macOS with support for iOS builds. Security-scoped bookmarks keep directory access stable across launches.
- **Feature-based clean architecture**: Presentation, domain, and data layers are split by feature (media library, tagging, favorites, full screen) and coordinated with Riverpod view models.
- **Rich browsing experience**: Directory and media grids offer search, tag filtering, column density controls, and quick entry into a full-screen viewer with keyboard shortcuts and video controls.
- **Stateful persistence**: SharedPreferences stores user selections (directories, tags, favorites) while filesystem scans keep metadata fresh.

## Key Capabilities

- Add folders, validate access permissions, and generate security-scoped bookmarks for macOS (`lib/features/media_library`).
- Scan directories for images, videos, and text documents with lazy metadata caching (`lib/features/media_library/data/data_sources`).
- Manage a dual tagging system that applies to both directories and individual media (`lib/features/tagging`).
- Toggle favorites, start slideshows, and browse starred items in a dedicated screen (`lib/features/favorites`).
- Open any media item in an immersive full-screen viewer with playback controls and keyboard navigation (`lib/features/full_screen`).

## Architecture

The project follows a clean, feature-first layout:

```
lib/
├── core/            # Platform services, logging, error handling, theming
├── features/
│   ├── media_library/
│   ├── tagging/
│   ├── favorites/
│   └── full_screen/
├── shared/          # Cross-cutting providers, widgets, utils
└── main.dart        # App bootstrap and top-level wiring
```

Each feature contains `data`, `domain`, and `presentation` layers. Riverpod `StateNotifier` view models orchestrate use cases and repositories, keeping UI reactive and testable.

## Getting Started

1. Install Flutter (3.22 or newer recommended) and set up macOS/iOS tooling.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run -d macos   # or -d ios / -d chrome if configured
   ```
4. To update generated code or platform channels, rebuild the project (`flutter clean && flutter pub get`).

## Testing

```
flutter test
```

Widget and integration test scaffolds live under `test/`. Add coverage for new view models or use cases as features evolve.

## Roadmap & Known Gaps

- Align directory IDs across layers; current mix of `path.hashCode` in add_directory_use_case.dart:16 and local_directory_data_source.dart:170 vs SHA-256 ids in filesystem_media_repository_impl.dart:47-269 breaks tag assignment, favorites cleanup, and directory lookups.
- Replace placeholder tag filter data and wire DirectoryGrid into the tag system; directories never persist tagIds and TagManagementDialog toggles fail because directoryRepository.getDirectoryById() can't resolve SHA ids (directory_grid_screen.dart:130, assign_tag_use_case.dart:17, tag_management_dialog.dart:239).
- Persist recovered paths/bookmarks back to DirectoryRepository when permissions are re-granted; MediaViewModel only updates local state, so reopening the directory breaks again (media_grid_view_model.dart:300-333).
- Extend RemoveDirectoryUseCase to purge cached media metadata via IsarMediaDataSource.removeMediaForDirectory(); otherwise stale IDs linger for favorites/tag lookups (remove_directory_use_case.dart:40-63, isar_media_data_source.dart:141-199).
- Preserve grid layout preferences when filtering/sorting; filterByTags replaces state with MediaLoading and resets columns to 3, undoing user changes (media_grid_view_model.dart:205-244).
- Loosen drag-and-drop directory detection; the current suffix check skips valid macOS bundle directories like *.photoslibrary (directory_grid_screen.dart:124-127).


## Additional Documentation

- `architecture_design.md` – high-level architectural plan and testing strategy.
- `flutter_dart_riverpod_mockito.md` – notes on tooling choices and mocking patterns.
- `replicate_app_prompt.md` – original product brief for reference.

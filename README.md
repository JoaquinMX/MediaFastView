# Media Fast View

Media Fast View is a Flutter application for macOS and iOS designed to make large local media libraries fast to browse. It scans directories on disk, persists lightweight metadata, and provides tagging, favorites, and full-screen playback so you can jump from discovery to viewing without leaving the app.

## Overview

- **Platform focus**: Desktop-first experience for macOS with support for iOS builds. Security-scoped bookmarks keep directory access stable across launches.
- **Feature-based clean architecture**: Presentation, domain, and data layers are split by feature (media library, tagging, favorites, full screen) and coordinated with Riverpod view models.
- **Rich browsing experience**: Directory and media grids offer search, tag filtering, column density controls, and quick entry into a full-screen viewer with keyboard shortcuts and video controls.
- **Stateful persistence**: SharedPreferences stores user selections (directories, tags, favorites) while filesystem scans keep metadata fresh.

## Key Capabilities

- Add folders, validate access permissions, and generate security-scoped bookmarks for macOS (`lib/features/media_library`).
- Scan directories for images, videos, text documents, and the newly supported HEIC/RAW/ProRes/PDF/audio formats via a centralized registry (`lib/features/media_library/data/data_sources`).
- Persist directories, media, tags, and favorites in an embedded Isar database with a boot-time migrator that pulls forward existing SharedPreferences data (`lib/core/database`).
- Generate background thumbnails and rich metadata (dimensions, duration, EXIF) through an isolate-driven pipeline so media grids render instantly and fall back gracefully when processing is disabled (`lib/core/services/thumbnail_metadata_service.dart`).
- Run automatic health checks that repair revoked bookmarks, heal directory IDs, and bubble status back to view models so the UI remains responsive without manual refreshes (`lib/features/media_library/presentation/view_models/directory_grid_view_model.dart`).
- Manage a dual tagging system that applies to both directories and individual media (`lib/features/tagging`).
- Toggle favorites, start slideshows, and browse starred items in a dedicated screen (`lib/features/favorites`).
- Open any media item in an immersive full-screen viewer with playback controls and keyboard navigation (`lib/features/full_screen`).

## Recent Enhancements

The following roadmap items are now implemented:

1. **Database-backed library index.** All persisted entities live in Isar collections with Riverpod-integrated data sources. A startup migrator copies legacy SharedPreferences payloads into the new schema the first time the app launches after the upgrade.
2. **Background thumbnails & metadata.** Media scans enqueue work on a background isolate that writes cached thumbnails and stores width/height/duration/EXIF values, keeping the UI responsive while enabling richer sorting and filtering.
3. **Broader media format coverage.** The new `MediaFormatRegistry` recognizes additional photo, video, audio, and document formats and coordinates thumbnail policies per type so unconventional files appear alongside standard images and videos.
4. **Automatic library health checks.** Periodic background sweeps reconcile filesystem changes, refresh macOS security-scoped bookmarks, and notify Riverpod view models when user action is required.

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

### Prerequisites

- Flutter 3.22 or newer with macOS and/or iOS toolchains configured
- Xcode (for macOS/iOS builds) and CocoaPods
- Dart SDK that matches the Flutter distribution

### Install dependencies

```bash
flutter pub get
```

If you modify the Isar collections or freezed/json-serializable models, regenerate code with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Running the app

Launch on macOS (recommended for the desktop-first experience):

```bash
flutter run -d macos
```

Other supported targets include iOS simulators/devices (`flutter run -d ios`) and Chrome (`flutter run -d chrome`) for quick UI smoke tests.

### First-run migration & caches

- On first launch after upgrading from the SharedPreferences build, the app automatically migrates saved directories, media, tags, and favorites into the Isar database. Progress is logged to the console.
- Thumbnails and metadata are generated in the background. You can toggle caching in the app preferences; cached assets live under the application support directory and are refreshed automatically by health checks.

## Testing

```
flutter test
```

Widget and integration test scaffolds live under `test/`. Add coverage for new view models or use cases as features evolve. Database migrations and health-check workflows include unit-test-friendly adapters to simplify mocking in Riverpod containers.

## Roadmap & Known Gaps

- Align directory IDs across layers; current mix of `path.hashCode` in add_directory_use_case.dart:16 and local_directory_data_source.dart:170 vs SHA-256 ids in filesystem_media_repository_impl.dart:47-269 breaks tag assignment, favorites cleanup, and directory lookups.
- Replace placeholder tag filter data and wire DirectoryGrid into the tag system; directories never persist tagIds and TagManagementDialog toggles fail because directoryRepository.getDirectoryById() can't resolve SHA ids (directory_grid_screen.dart:130, assign_tag_use_case.dart:17, tag_management_dialog.dart:239).
- Persist recovered paths/bookmarks back to DirectoryRepository when permissions are re-granted; MediaViewModel only updates local state, so reopening the directory breaks again (media_grid_view_model.dart:300-333).
- Extend RemoveDirectoryUseCase to purge cached media metadata via SharedPreferencesMediaDataSource.removeMediaForDirectory(); otherwise stale IDs linger for favorites/tag lookups (remove_directory_use_case.dart:40-63, local_media_data_source.dart:58).
- Preserve grid layout preferences when filtering/sorting; filterByTags replaces state with MediaLoading and resets columns to 3, undoing user changes (media_grid_view_model.dart:205-244).
- Loosen drag-and-drop directory detection; the current suffix check skips valid macOS bundle directories like *.photoslibrary (directory_grid_screen.dart:124-127).


## Additional Documentation

- `architecture_design.md` – high-level architectural plan and testing strategy.
- `flutter_dart_riverpod_mockito.md` – notes on tooling choices and mocking patterns.
- `replicate_app_prompt.md` – original product brief for reference.

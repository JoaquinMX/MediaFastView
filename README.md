# Media Fast View

Media Fast View is a Flutter application for macOS and iOS designed to make large local media libraries fast to browse. It scans directories on disk, persists lightweight metadata, and provides tagging, favorites, and full-screen playback so you can jump from discovery to viewing without leaving the app.

## Overview

- **Platform focus**: Desktop-first experience for macOS with support for iOS builds. Security-scoped bookmarks keep directory access stable across launches.
- **Feature-based clean architecture**: Presentation, domain, and data layers are split by feature (media library, tagging, favorites, full screen, settings) and coordinated with Riverpod view models.
- **Rich browsing experience**: Directory and media grids offer drag-and-drop intake, search, tag filtering, column density controls, and quick entry into a full-screen viewer with keyboard shortcuts and video controls.
- **Stateful persistence**: Isar persists user selections (directories, tags, favorites) while filesystem scans keep metadata fresh and permission recovery keeps access stable across relaunches.

## Key Capabilities

- Add folders via picker or drag-and-drop, validate access permissions, recover lost bookmarks, and generate security-scoped bookmarks for macOS (`lib/features/media_library`).
- Scan directories for images, videos, and text documents with lazy metadata caching (`lib/features/media_library/data/data_sources`).
- Manage a dual tagging system that applies to both directories and individual media with tag-driven library views (`lib/features/tagging`).
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
│   ├── full_screen/
│   └── settings/
├── shared/
│   ├── providers/   # Dependency injection wiring shared across features
│   └── ...          # Cross-cutting widgets, utils, theme extensions
└── main.dart        # App bootstrap and top-level wiring
```

Each feature contains `data`, `domain`, and `presentation` layers. Riverpod `StateNotifier` view models orchestrate use cases and repositories, while shared provider modules (`lib/shared/providers`) centralize dependency injection for navigation and data access, keeping UI reactive and testable.

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

## iOS CocoaPods Linkage Policy

- `ios/Podfile` now defaults to CocoaPods static library integration for `Runner` (no unconditional `use_frameworks!`).
- Dynamic framework packaging can be re-enabled only when needed:
  - `USE_FRAMEWORKS=static pod install` to keep framework-style integration but static linkage.
  - `USE_FRAMEWORKS=dynamic pod install` only for plugins that fail without dynamic frameworks.
- Current iOS plugin set in `ios/Podfile.lock` (`file_picker`, `isar_flutter_libs`, `path_provider_foundation`, `shared_preferences_foundation`, `video_player_avfoundation`) does not require globally enabling dynamic frameworks.
- If a future plugin fails with static libraries, scope framework usage narrowly:
  1. First try `USE_FRAMEWORKS=static`.
  2. If dynamic frameworks are unavoidable, document the specific plugin and failure mode in this section and keep framework enablement limited to iOS `Runner` only.

### Controlled Build + Install Timing (Real iPhone)

To avoid regressions from future dependency changes, run this before/after benchmark on a connected physical iPhone from `ios/`:

```bash
# Baseline (current default/static)
flutter clean
/usr/bin/time -lp flutter build ios --debug
/usr/bin/time -lp flutter install -d <device_id>

# Comparison (only if investigating framework overhead)
flutter clean
USE_FRAMEWORKS=dynamic pod install
/usr/bin/time -lp flutter build ios --debug
/usr/bin/time -lp flutter install -d <device_id>
```

Record build + install timing deltas in your PR whenever iOS plugins are added/updated.

### CocoaPods / Ruby ffi Troubleshooting

If iOS debug build logs show:

```text
Ignoring ffi-1.15.5 because its extensions are not built. Try: gem pristine ffi --version 1.15.5
```

Repair the native gem extension and reinstall pods:

```bash
gem pristine ffi --version 1.15.5
cd ios
pod install
```

If the issue persists, reinstall CocoaPods gems for your Ruby version and rerun `pod install`.

## Roadmap & Known Gaps

- Inline tag editing within the full-screen viewer, including keyboard shortcuts for quick tagging.
- Smart tag suggestions that leverage EXIF/video metadata and existing usage patterns to speed up labeling.
- Support for hierarchical (parent/child) tags that apply to both directories and individual media.
- Saved smart collections that remember complex tag filters for one-click access from the library.
- A timeline/gallery mode that groups tagged media by capture date and tag for storytelling.
- Tag density heatmaps over directory tiles to spotlight under- or over-tagged locations.
- Side-by-side compare mode that locks views to selected tags for curation reviews.
- Video chapter tagging so viewers can jump between tagged segments inside long clips.
- Tag-driven slideshow presets with custom transitions, durations, and media ordering.
- A bulk tagging review queue for newly imported directories to streamline first-pass annotation.


## Additional Documentation

- `architecture_design.md` – high-level architectural plan and testing strategy.
- `flutter_dart_riverpod_mockito.md` – notes on tooling choices and mocking patterns.
- `replicate_app_prompt.md` – original product brief for reference.

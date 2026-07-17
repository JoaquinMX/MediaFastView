# Media Fast View

Media Fast View is a Flutter application for macOS and iOS designed to make large local media libraries fast to browse. It scans directories on disk, persists lightweight metadata, and provides tagging, favorites, saved filters, profiles, and full-screen playback so you can jump from discovery to viewing without leaving the app.

## Overview

- **Desktop-first**: A macOS-first experience with iOS support. Security-scoped bookmarks keep directory access stable across launches, and file operations (move/copy/trash) are surfaced on macOS.
- **Feature-based clean architecture**: Presentation, domain, and data layers are split by feature (media library, tagging, favorites, full screen, profiles, settings) and coordinated with Riverpod view models.
- **Rich browsing experience**: Directory and media grids offer drag-and-drop intake, search, tag filtering, marquee (rubber-band) multi-select, column density controls, and quick entry into a full-screen viewer with keyboard shortcuts and playback controls.
- **Stateful persistence**: Isar persists user selections (directories, tags, favorites, saved filters) per profile, while filesystem scans keep metadata fresh and permission recovery keeps access stable across relaunches.

## Feature Highlights

### Library & directories
- Add folders via picker or drag-and-drop, validate access permissions, recover lost bookmarks, and generate security-scoped bookmarks for macOS (`lib/features/media_library`).
- Scan directories for images, videos, audio, and text documents with lazy metadata caching (`lib/features/media_library/data/data_sources`).
- Adjustable column density and multiple sort options for both directory and media grids.
- Marquee (rubber-band) and keyboard multi-select, with bulk tag assignment and bulk favorite toggling.
- Background duplicate-media scanning with lightweight progress feedback.

### Media grid & file operations
- Filter media by type (images, videos, audio, directories), favorites, untagged status, and tags.
- Move, copy, and trash items or whole folders on macOS — individually, from the right-click menu, or in bulk from selection mode.
- Navigate between sibling directories with arrow keys, swipe, or on-screen chevrons; optionally open the next folder automatically after deleting the one you're viewing.
- "Go to directory" reveals and briefly highlights an item back in its grid after you leave the viewer.

### Full-screen viewer
- Immersive viewer for images, videos, and audio with keyboard navigation (arrows, Home/End, Page Up/Down).
- Zoom and pan for images; play/pause, mute, loop, seek, and speed controls for time-based media.
- Assign or remove your most-used "shortcut tags" with `Cmd/Ctrl + Alt + 1–0`, toggle favorites, and inspect item details inline.
- Right-click for **Go to directory**, **Reveal in Finder**, and **Copy path**.

### Tagging & filtering
- A dual tagging system that applies to both directories and individual media, with colored tags and tag-driven library views (`lib/features/tagging`).
- Manage tags: create, rename, recolor, merge, and delete.
- The Tags tab filters media with **Any / All / Hybrid** match modes, required/optional/excluded tags, a media-type filter, tag search, and a hierarchical **directory filter tree** with hover previews.
- **Saved filters**: name and persist a query, apply it from a chip strip, update/rename/delete it, and get notified when a saved filter references tags or directories that no longer exist. Start a slideshow directly from any filtered result set.

### Favorites & slideshow
- Toggle favorites for both media and directories, individually or in bulk.
- Run a full-screen slideshow with overlay controls whose auto-hide delay is configurable in Settings.

### Profiles
- Named, switchable scopes over the whole library (`lib/features/profiles`). Each profile owns its own directories, tags, favorites, and saved filters; switching re-scopes the entire app.
- App-wide preferences (theme, playback, grid columns) deliberately live outside profiles.
- A profile switcher lives in the Library and Tags app bars; create, rename, reorder, and delete profiles from the management dialog.

### Settings
- **Appearance**: theme mode (system / light / dark).
- **Playback**: autoplay, loop, start muted, and slideshow controls auto-hide delay.
- **Navigation**: auto-navigate sibling directories, show tagged-vs-total media counts on directory cards.
- **Data management**: thumbnail caching, delete-from-source toggle, open-next-folder-after-delete, and maintenance actions to clean cached media, clear the directory cache, clear favorites, clear tag assignments, or clear all tags.

## Keyboard Shortcuts

The in-app guide (press `?`) is the source of truth; a summary:

| Keys | Action | Context |
| --- | --- | --- |
| `?` / `Shift + /` | Open the keyboard shortcut guide | Viewer, grids |
| `Escape` | Exit the viewer or clear the current selection | Viewer, grids |
| `← / →` | Navigate between media items | Full-screen viewer |
| `← / →` | Move between sibling directories | Media grids |
| `Home / End` | Jump to the first or last item | Full-screen viewer |
| `Page Up / Page Down` | Move ten items at a time | Full-screen viewer |
| `Cmd/Ctrl + Alt + 1–0` | Assign/remove the matching shortcut tag | Full-screen viewer |
| `F` / `I` | Toggle favorite / show item details | Full-screen viewer |
| `Space` / `M` / `L` | Play-pause / mute / loop | Full-screen viewer |
| `Cmd + A` | Select all visible media (macOS) | Media grids |
| `Cmd + R` / `Ctrl + R` | Re-read the folder from disk | Media grids |
| `Cmd + M` / `Cmd + D` | Move / copy the current item (macOS) | Full-screen viewer |
| `Delete` / `Backspace` | Move item(s) to the Trash (macOS; requires "Delete From Source") | Viewer, grids |

## Supported Formats

- **Images**: JPEG, PNG, GIF, BMP, WebP, TIFF, HEIC/HEIF, and common RAW formats (DNG, NEF, CR2/CR3, ARW, RAF, ORF, RW2, SR2, PEF).
- **Video**: MP4, AVI, MOV, MKV, WMV, FLV, WebM, M4V, TS/MTS/M2TS, MPG/MPEG.
- **Audio**: MP3, M4A, AAC, WAV, AIFF/AIF, FLAC, CAF, ALAC, OGG/OGA, Opus.
- **Text**: TXT, MD, LOG (and other plain-text/code files are detected).

## Architecture

The project follows a clean, feature-first layout:

```
lib/
├── core/            # Platform services, logging, error handling, theming, config
├── features/
│   ├── media_library/
│   ├── tagging/
│   ├── favorites/
│   ├── full_screen/
│   ├── profiles/
│   └── settings/
├── shared/
│   ├── providers/   # Dependency injection wiring shared across features
│   └── ...          # Cross-cutting widgets, utils, theme extensions
└── main.dart        # App bootstrap, database/profile resolution, top-level wiring
```

Each feature contains `data`, `domain`, and `presentation` layers. Riverpod `StateNotifier` view models orchestrate use cases and repositories, while shared provider modules (`lib/shared/providers`) centralize dependency injection for navigation and data access, keeping the UI reactive and testable. Isar is the persistence layer; data sources are bound to the active profile, and the database (and its migrations) are resolved before the first frame in `main.dart` so every profile-scoped provider can read it synchronously.

## Getting Started

1. Install Flutter (3.32 or newer, Dart SDK 3.8+) and set up macOS/iOS tooling.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Generate code (Isar collections, Freezed, JSON serialization):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run the app:
   ```bash
   flutter run -d macos   # or -d ios
   ```
5. After changing generated sources, re-run the build runner (or `flutter clean && flutter pub get` for a full reset).

## Testing

```bash
flutter test
```

Widget and integration test scaffolds live under `test/`. Add coverage for new view models or use cases as features evolve.

## Roadmap

- **Duplicate management UI** to review and resolve the duplicates the background scan already surfaces.
- **Portable, sidecar tag metadata** (e.g. XMP export/import) so tags travel with files between machines.
- **Video thumbnail generation** with hover/scrub previews in the grid.
- **Video chapter tagging** so viewers can jump between tagged segments inside long clips.
- **Metadata display & filtering** (EXIF: date taken, dimensions, camera, GPS) with date/timeline-based browsing.
- **Star ratings** alongside binary favorites, and rating-aware filters.
- **Configurable keyboard shortcuts** and a customizable shortcut-tag mapping.
- **Batch rename** and other bulk file utilities.
- **Windows/Linux desktop support**, extending the current macOS/iOS focus.

## Additional Documentation

- `architecture_design.md` – high-level architectural plan and testing strategy.
- `replicate_app_prompt.md` – original product brief for reference.
- `AGENTS.md` – contributor/style conventions for the codebase.

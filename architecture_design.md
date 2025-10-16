# Flutter Media Fast View App - Architectural Design Document

## Overview

This document outlines the architectural design for a Flutter application focused on media management and viewing, targeting iOS and macOS platforms. The app implements a feature-based clean architecture with MVVM pattern using Riverpod for state management, adhering to Effective Dart rules and leveraging Dart 3 features.

## Core Features

Based on the requirements analysis, the application implements the following core features:

1. **Directory Management**: Adding, displaying, searching, tagging, and deleting directories with preview thumbnails
2. **Media Viewing**: Grid-based display of images, videos, and text files with thumbnail previews and navigation
3. **Tagging System**: Dual tagging for directories and media files with dynamic creation and filtering
4. **Favorites System**: Marking favorites with dedicated screen and slideshow functionality
5. **Full-Screen Viewing**: Immersive viewing with zoom, pan, and video controls
6. **UI Interactions**: Responsive grids, animations, drag-and-drop, gestures, and keyboard shortcuts
7. **File Operations**: Safe file deletion and permission handling
8. **Data Persistence**: SharedPreferences-based storage for all app data
9. **Database Migration Prep**: Centralised Isar database service ready to host
   persistent collections as part of the SharedPreferences replacement
   roadmap, with schemas defined for directories, media, tags, and favorites,
   plus concrete Isar data sources for directories and media that mirror the
   legacy SharedPreferences behaviours while operating on the shared database
10. **Performance Optimizations**: Lazy loading, memory management, and efficient resource handling

## Architectural Principles

### Clean Architecture Layers

The application follows clean architecture with three main layers:

- **Presentation Layer**: UI components, screens, widgets, and view models (Riverpod providers)
- **Domain Layer**: Business logic, entities, use cases, and repository interfaces
- **Data Layer**: Data models, data sources, and repository implementations

### Feature-Based Organization

Code is organized by features rather than technical layers to promote cohesion and maintainability:

```
lib/
├── features/
│   ├── media_library/          # Directory and media management
│   ├── tagging/                # Tagging system
│   ├── favorites/              # Favorites functionality
│   └── full_screen/            # Full-screen viewing
├── core/
│   ├── utils/                  # Utility functions
│   ├── services/               # Platform services
│   ├── themes/                 # App theming
│   └── error/                  # Error handling
├── shared/
│   ├── widgets/                # Shared UI components
│   └── providers/              # Shared Riverpod providers
└── main.dart
```

### MVVM Pattern with Riverpod

- **Model**: Domain entities and business logic
- **View**: Flutter widgets that observe ViewModel state
- **ViewModel**: Riverpod StateNotifier providers managing state and business logic

## Directory Structure

```
lib/
├── features/
│   ├── media_library/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── directory_grid_screen.dart
│   │   │   │   ├── media_grid_screen.dart
│   │   │   │   └── directory_picker_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── directory_grid_item.dart
│   │   │   │   ├── media_grid_item.dart
│   │   │   │   ├── tag_chip.dart
│   │   │   │   └── loading_indicator.dart
│   │   │   └── view_models/
│   │   │       ├── directory_grid_view_model.dart
│   │   │       ├── media_grid_view_model.dart
│   │   │       └── directory_picker_view_model.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── directory_entity.dart
│   │   │   │   ├── media_entity.dart
│   │   │   │   └── tag_entity.dart
│   │   │   ├── repositories/
│   │   │   │   ├── directory_repository.dart
│   │   │   │   ├── media_repository.dart
│   │   │   │   └── tag_repository.dart
│   │   │   └── use_cases/
│   │   │       ├── get_directories_use_case.dart
│   │   │       ├── get_media_use_case.dart
│   │   │       ├── add_directory_use_case.dart
│   │   │       └── search_directories_use_case.dart
│   │   └── data/
│   │       ├── models/
│   │       │   ├── directory_model.dart
│   │       │   ├── media_model.dart
│   │       │   └── tag_model.dart
│   │       ├── data_sources/
│   │       │   ├── local_directory_data_source.dart
│   │       │   ├── local_media_data_source.dart
│   │       │   └── shared_preferences_data_source.dart
│   │       └── repositories/
│   │           ├── directory_repository_impl.dart
│   │           ├── media_repository_impl.dart
│   │           └── tag_repository_impl.dart
│   ├── tagging/
│   │   ├── presentation/
│   │   │   ├── widgets/
│   │   │   │   ├── tag_management_dialog.dart
│   │   │   │   └── tag_filter_chips.dart
│   │   │   └── view_models/
│   │   │       └── tag_management_view_model.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── tag_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── tag_repository.dart
│   │   │   └── use_cases/
│   │   │       ├── create_tag_use_case.dart
│   │   │       ├── assign_tag_use_case.dart
│   │   │       └── filter_by_tags_use_case.dart
│   │   └── data/
│   │       ├── models/
│   │       │   └── tag_model.dart
│   │       ├── data_sources/
│   │       │   └── shared_preferences_data_source.dart
│   │       └── repositories/
│   │           └── tag_repository_impl.dart
│   ├── favorites/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── favorites_screen.dart
│   │   │   │   └── slideshow_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── favorite_toggle_button.dart
│   │   │   │   └── slideshow_controls.dart
│   │   │   └── view_models/
│   │   │       ├── favorites_view_model.dart
│   │   │       └── slideshow_view_model.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── favorite_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── favorites_repository.dart
│   │   │   └── use_cases/
│   │   │       ├── toggle_favorite_use_case.dart
│   │   │       ├── get_favorites_use_case.dart
│   │   │       └── start_slideshow_use_case.dart
│   │   └── data/
│   │       ├── models/
│   │       │   └── favorite_model.dart
│   │       ├── data_sources/
│   │       │   └── shared_preferences_data_source.dart
│   │       └── repositories/
│   │           └── favorites_repository_impl.dart
│   └── full_screen/
│       ├── presentation/
│       │   ├── screens/
│       │   │   └── full_screen_viewer_screen.dart
│       │   ├── widgets/
│       │   │   ├── image_viewer.dart
│       │   │   ├── video_player_controls.dart
│       │   │   └── zoom_pan_viewer.dart
│       │   └── view_models/
│       │       └── full_screen_view_model.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── viewer_state_entity.dart
│       │   ├── repositories/
│       │   │   └── media_viewer_repository.dart
│       │   └── use_cases/
│       │       ├── load_media_for_viewing_use_case.dart
│       │       └── navigate_media_use_case.dart
│       └── data/
│           ├── models/
│           │   └── viewer_state_model.dart
│           ├── data_sources/
│           │   └── file_system_data_source.dart
│           └── repositories/
│               └── media_viewer_repository_impl.dart
├── core/
│   ├── utils/
│   │   ├── file_utils.dart
│   │   ├── path_utils.dart
│   │   └── thumbnail_generator.dart
│   ├── services/
│   │   ├── file_service.dart
│   │   ├── permission_service.dart
│   │   └── platform_service.dart
│   ├── themes/
│   │   ├── app_theme.dart
│   │   └── color_scheme.dart
│   └── error/
│       ├── app_error.dart
│       ├── error_handler.dart
│       └── failure.dart
├── shared/
│   ├── widgets/
│   │   ├── app_bar.dart
│   │   ├── grid_layout.dart
│   │   └── confirmation_dialog.dart
│   └── providers/
│       ├── app_settings_provider.dart
│       └── theme_provider.dart
└── main.dart
```

## Key Classes and Entities

### Domain Entities

```dart
// lib/features/media_library/domain/entities/directory_entity.dart
sealed class DirectoryEntity {
  const DirectoryEntity({
    required this.id,
    required this.path,
    required this.name,
    required this.thumbnailPath,
    required this.tagIds,
    required this.lastModified,
  });

  final String id;
  final String path;
  final String name;
  final String? thumbnailPath;
  final List<String> tagIds;
  final DateTime lastModified;
}

// lib/features/media_library/domain/entities/media_entity.dart
sealed class MediaEntity {
  const MediaEntity({
    required this.id,
    required this.path,
    required this.name,
    required this.type,
    required this.size,
    required this.lastModified,
    required this.tagIds,
    required this.directoryId,
  });

  final String id;
  final String path;
  final String name;
  final MediaType type;
  final int size;
  final DateTime lastModified;
  final List<String> tagIds;
  final String directoryId;
}

enum MediaType {
  image,
  video,
  text,
}

// lib/features/tagging/domain/entities/tag_entity.dart
class TagEntity {
  const TagEntity({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int color;
  final DateTime createdAt;
}

// lib/features/favorites/domain/entities/favorite_entity.dart
class FavoriteEntity {
  const FavoriteEntity({
    required this.mediaId,
    required this.addedAt,
  });

  final String mediaId;
  final DateTime addedAt;
}
```

### Repository Interfaces

```dart
// lib/features/media_library/domain/repositories/directory_repository.dart
abstract class DirectoryRepository {
  Future<List<DirectoryEntity>> getDirectories();
  Future<DirectoryEntity?> getDirectoryById(String id);
  Future<void> addDirectory(DirectoryEntity directory);
  Future<void> removeDirectory(String id);
  Future<List<DirectoryEntity>> searchDirectories(String query);
  Future<List<DirectoryEntity>> filterDirectoriesByTags(List<String> tagIds);
}

// lib/features/media_library/domain/repositories/media_repository.dart
abstract class MediaRepository {
  Future<List<MediaEntity>> getMediaForDirectory(String directoryId);
  Future<MediaEntity?> getMediaById(String id);
  Future<List<MediaEntity>> filterMediaByTags(List<String> tagIds);
  Future<void> updateMediaTags(String mediaId, List<String> tagIds);
}

// lib/features/tagging/domain/repositories/tag_repository.dart
abstract class TagRepository {
  Future<List<TagEntity>> getTags();
  Future<TagEntity?> getTagById(String id);
  Future<void> createTag(TagEntity tag);
  Future<void> updateTag(TagEntity tag);
  Future<void> deleteTag(String id);
}

// lib/features/favorites/domain/repositories/favorites_repository.dart
abstract class FavoritesRepository {
  Future<List<String>> getFavoriteMediaIds();
  Future<void> addFavorite(String mediaId);
  Future<void> removeFavorite(String mediaId);
  Future<bool> isFavorite(String mediaId);
}
```

### Use Cases

```dart
// lib/features/media_library/domain/use_cases/get_directories_use_case.dart
class GetDirectoriesUseCase {
  const GetDirectoriesUseCase(this._repository);

  final DirectoryRepository _repository;

  Future<List<DirectoryEntity>> call() => _repository.getDirectories();
}

// lib/features/media_library/domain/use_cases/add_directory_use_case.dart
class AddDirectoryUseCase {
  const AddDirectoryUseCase(this._repository, this._mediaRepository);

  final DirectoryRepository _repository;
  final MediaRepository _mediaRepository;

  Future<void> call(String path) async {
    // Validate path, scan for media, generate thumbnail, etc.
    final directory = DirectoryEntity(/* ... */);
    await _repository.addDirectory(directory);
  }
}

// lib/features/tagging/domain/use_cases/create_tag_use_case.dart
class CreateTagUseCase {
  const CreateTagUseCase(this._repository);

  final TagRepository _repository;

  Future<void> call(String name, int color) async {
    final tag = TagEntity(
      id: generateId(),
      name: name,
      color: color,
      createdAt: DateTime.now(),
    );
    await _repository.createTag(tag);
  }
}
```

## Riverpod Providers Structure

### State Management Approach

The application uses Riverpod StateNotifierProvider for complex state management with MVVM pattern. Each feature has dedicated ViewModel providers that manage state and expose methods for UI interactions.

State classes use sealed classes for exhaustive pattern matching:

```dart
// lib/features/media_library/presentation/view_models/directory_grid_view_model.dart
sealed class DirectoryGridState {
  const DirectoryGridState();
}

class DirectoryGridInitial extends DirectoryGridState {
  const DirectoryGridInitial();
}

class DirectoryGridLoading extends DirectoryGridState {
  const DirectoryGridLoading();
}

class DirectoryGridLoaded extends DirectoryGridState {
  const DirectoryGridLoaded({
    required this.directories,
    required this.searchQuery,
    required this.selectedTagIds,
  });

  final List<DirectoryEntity> directories;
  final String searchQuery;
  final List<String> selectedTagIds;
}

class DirectoryGridError extends DirectoryGridState {
  const DirectoryGridError(this.message);

  final String message;
}

class DirectoryGridViewModel extends StateNotifier<DirectoryGridState> {
  DirectoryGridViewModel(this._getDirectoriesUseCase, this._searchDirectoriesUseCase)
      : super(const DirectoryGridInitial());

  final GetDirectoriesUseCase _getDirectoriesUseCase;
  final SearchDirectoriesUseCase _searchDirectoriesUseCase;

  Future<void> loadDirectories() async {
    state = const DirectoryGridLoading();
    try {
      final directories = await _getDirectoriesUseCase();
      state = DirectoryGridLoaded(
        directories: directories,
        searchQuery: '',
        selectedTagIds: [],
      );
    } catch (e) {
      state = DirectoryGridError(e.toString());
    }
  }

  void searchDirectories(String query) {
    state = switch (state) {
      DirectoryGridLoaded(:final directories, :final selectedTagIds) => DirectoryGridLoaded(
          directories: _searchDirectoriesUseCase(directories, query),
          searchQuery: query,
          selectedTagIds: selectedTagIds,
        ),
      _ => state,
    };
  }

  void filterByTags(List<String> tagIds) {
    state = switch (state) {
      DirectoryGridLoaded(:final directories, :final searchQuery) => DirectoryGridLoaded(
          directories: _filterDirectoriesUseCase(directories, tagIds),
          searchQuery: searchQuery,
          selectedTagIds: tagIds,
        ),
      _ => state,
    };
  }
}

final directoryGridViewModelProvider = StateNotifierProvider<DirectoryGridViewModel, DirectoryGridState>(
  (ref) => DirectoryGridViewModel(
    ref.watch(getDirectoriesUseCaseProvider),
    ref.watch(searchDirectoriesUseCaseProvider),
  ),
);
```

### Provider Dependencies

```dart
// Repository providers
final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  return DirectoryRepositoryImpl(
    ref.watch(sharedPreferencesDataSourceProvider),
    ref.watch(localDirectoryDataSourceProvider),
    ref.watch(bookmarkServiceProvider),
    ref.watch(permissionServiceProvider),
    ref.watch(mediaDataSourceProvider),
  );
});

// Use case providers
final getDirectoriesUseCaseProvider = Provider<GetDirectoriesUseCase>((ref) {
  return GetDirectoriesUseCase(ref.watch(directoryRepositoryProvider));
});

// ViewModel providers
final directoryGridViewModelProvider = StateNotifierProvider<DirectoryGridViewModel, DirectoryGridState>((ref) {
  return DirectoryGridViewModel(
    ref.watch(getDirectoriesUseCaseProvider),
    ref.watch(searchDirectoriesUseCaseProvider),
  );
});

// Shared providers
final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier(ref.watch(sharedPreferencesDataSourceProvider));
});

final themeProvider = Provider<ThemeData>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return settings.darkMode ? ThemeData.dark() : ThemeData.light();
});
```

### Auto Dispose and State Disposal

All parameterized providers use `autoDispose` to prevent memory leaks:

```dart
final mediaForDirectoryProvider = FutureProvider.autoDispose.family<List<MediaEntity>, String>((ref, directoryId) async {
  final repository = ref.watch(mediaRepositoryProvider);
  return repository.getMediaForDirectory(directoryId);
});
```

## Integration Points

### Layer Integration

- **Presentation → Domain**: ViewModels inject use cases and call them to perform business logic
- **Domain → Data**: Use cases inject repository interfaces and call them for data operations
- **Data → External**: Repository implementations inject data sources for file system and persistence operations

### Feature Integration

- **Media Library ↔ Tagging**: Media and directory entities reference tag IDs; tagging use cases update tag assignments
- **Media Library ↔ Favorites**: Favorites system references media IDs; media viewing checks favorite status
- **Full Screen ↔ Media Library**: Full-screen viewer loads media from media repository
- **All Features ↔ Core**: Shared utilities, error handling, and services used across features

### Platform Integration

- **File System**: Platform-specific file operations abstracted through services
- **Permissions**: Permission handling for file access on iOS/macOS
- **Drag-and-Drop**: macOS-specific drag-and-drop functionality in directory picker

## Testing Strategy

### Unit Tests

- **Domain Layer**: Test use cases with mocked repositories
- **Data Layer**: Test repository implementations with mocked data sources
- **Presentation Layer**: Test ViewModels with mocked use cases

```dart
// Example unit test for a use case
void main() {
  late MockDirectoryRepository mockRepository;
  late GetDirectoriesUseCase useCase;

  setUp(() {
    mockRepository = MockDirectoryRepository();
    useCase = GetDirectoriesUseCase(mockRepository);
  });

  test('returns directories from repository', () async {
    final directories = [DirectoryEntity(/* ... */)];
    when(mockRepository.getDirectories()).thenAnswer((_) async => directories);

    final result = await useCase();

    expect(result, directories);
    verify(mockRepository.getDirectories()).called(1);
  });
}
```

### Widget Tests

- Test screens and widgets with mocked providers
- Verify UI state changes in response to provider updates
- Test user interactions and gesture handling

```dart
// Example widget test
void main() {
  testWidgets('displays directories in grid', (tester) async {
    final container = createContainer(overrides: [
      directoryGridViewModelProvider.overrideWith((ref) {
        return DirectoryGridViewModel(/* mocked dependencies */);
      }),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DirectoryGridScreen(),
      ),
    );

    // Initial state shows loading
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Simulate loading completion
    container.read(directoryGridViewModelProvider.notifier).loadDirectories();
    await tester.pump();

    // Verify directories are displayed
    expect(find.byType(DirectoryGridItem), findsNWidgets(5));
  });
}
```

### Integration Tests

- Test complete user flows across screens
- Verify data persistence and state restoration
- Test platform-specific features

```dart
// Example integration test
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete directory addition flow', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Navigate to directory picker
    await tester.tap(find.byKey(const Key('add_directory_button')));
    await tester.pumpAndSettle();

    // Select directory (mocked)
    await tester.tap(find.byKey(const Key('directory_item')));
    await tester.pumpAndSettle();

    // Verify directory appears in grid
    expect(find.text('Selected Directory'), findsOneWidget);

    // Verify persistence
    await tester.restartAndRestore();
    expect(find.text('Selected Directory'), findsOneWidget);
  });
}
```

### Testing Infrastructure

- **Mockito**: Generate mocks for repositories and external dependencies
- **Test Coverage**: Aim for >80% coverage with focus on business logic
- **CI/CD**: Automated testing on iOS and macOS platforms
- **Test Utilities**: Shared test helpers and fixtures

## Performance Optimizations

### Lazy Loading

- Implement pagination for large media collections
- Load thumbnails on-demand with caching
- Use `FutureProvider` for async data loading

### Memory Management

- Dispose video controllers properly
- Use `autoDispose` on providers to prevent memory leaks
- Implement resource cleanup in `ref.onDispose`

### UI Performance

- Use `const` constructors for static widgets
- Implement efficient list virtualization
- Cache expensive computations in providers

## Error Handling

### Error Types

```dart
sealed class AppError {
  const AppError(this.message);
  final String message;
}

class FileSystemError extends AppError {
  const FileSystemError(super.message);
}

class PermissionError extends AppError {
  const PermissionError(super.message);
}

class ValidationError extends AppError {
  const ValidationError(super.message);
}
```

### Error Propagation

- Domain layer throws custom errors
- Presentation layer catches and displays user-friendly messages
- Use `AsyncValue` for loading/error states in UI

## Platform-Specific Considerations

### iOS/macOS Optimizations

- Use platform-specific UI adaptations
- Implement drag-and-drop for macOS
- Handle file permissions appropriately
- Optimize for different screen sizes

### Build Configuration

- Exclude Android configurations
- Configure iOS/macOS entitlements
- Set up platform-specific dependencies

This architectural design provides a solid foundation for building a maintainable, scalable Flutter application that meets all specified requirements while following best practices for Dart 3, Riverpod, and clean architecture.
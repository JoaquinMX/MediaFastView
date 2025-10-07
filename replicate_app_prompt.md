# Flutter App Replication

## Overview

Replicate a Flutter app using Riverpod for state management, focusing exclusively on iOS and macOS platforms. Implement comprehensive testing to ensure reliability and maintainability.

## Code Standards and Best Practices

Adhere strictly to Effective Dart rules and Flutter best practices to ensure high-quality, maintainable code.

### Effective Dart Rules

- **Naming Conventions**: Use `UpperCamelCase` for classes, `lowerCamelCase` for variables and functions, `snake_case` for files. Capitalize acronyms longer than two letters.
- **Types and Functions**: Always type annotate variables, parameters, and return types. Use `Future<void>` for async functions without return values.
- **Style**: Format code with `dart format`. Prefer `final` over `var`, `const` for compile-time constants.
- **Imports & Files**: Use relative imports within packages. Avoid importing from `src` directories.
- **Structure**: Keep files focused on single responsibilities. Make fields and variables `final` where possible.
- **Usage**: Use collection literals, getters/setters appropriately. Override `hashCode` if overriding `==`.
- **Documentation**: Use `///` for public API documentation. Write doc comments for public members.
- **Testing**: Write unit tests for business logic, widget tests for UI components.
- **Widgets**: Extract reusable widgets. Prefer `StatelessWidget` when possible.
- **State Management**: Choose appropriate state management based on complexity. Keep state local.
- **Performance**: Use `const` constructors, avoid expensive operations in build methods.

### Dart 3 Features

Leverage Dart 3 enhancements for modern, expressive code:

- **Patterns**: Use pattern matching in `switch` statements, `if-case`, destructuring assignments, and loops.
- **Records**: Use records for multiple return values or simple data aggregation. Access fields with `$1`, `$2` or named fields.
- **Sealed Classes**: Use `sealed` modifier for exhaustive switching.
- **Enhanced Switch**: Use `switch` expressions with patterns and guards.

## Flutter Error Handling

Implement robust error handling to prevent common Flutter issues:

- **RenderFlex Overflow**: Wrap `Row`/`Column` children in `Flexible` or `Expanded` for unconstrained widgets.
- **Unbounded Height**: Provide bounded height for `ListView` in `Column` using `Expanded` or `SizedBox`.
- **InputDecorator Width**: Constrain `TextField` width with `Expanded` or `SizedBox`.
- **setState During Build**: Avoid calling `setState` or `showDialog` in build methods; use `addPostFrameCallback`.
- **ScrollController Attached Multiple Times**: Ensure each `ScrollController` is used by only one scrollable widget.
- **RenderBox Not Laid Out**: Provide proper constraints for widgets like `ListView` or `Column`.
- Use Flutter Inspector to debug layout issues and review constraints.

## Core Requirements

### Platform Support

- **Target Platforms**: iOS and macOS only
- Remove all Android-specific configurations and dependencies
- Ensure desktop features (drag-and-drop) work on macOS
- Optimize UI for iOS and macOS design guidelines

### State Management Migration

- Replace Provider with Riverpod for state management
- Convert existing providers to Riverpod providers (StateNotifierProvider or StateProvider as appropriate)
- Maintain all existing state and persistence functionality
- Preserve SharedPreferences persistence functionality

### Testing Implementation

- Unit tests for all providers and utility functions
- Widget tests for all screens and components
- Integration tests for key user flows
- Mock dependencies where necessary (file system, SharedPreferences)
- Achieve high test coverage (>80%)

## Recommended Project Structure

Adopt a feature-based architecture combined with clean architecture principles to ensure scalability, maintainability, and separation of concerns.

### Feature-Based Organization

Organize code by features rather than technical layers:

```
lib/
├── features/
│   ├── feature1/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── view_models/  # Riverpod providers
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/
│   │   │   └── use_cases/
│   │   └── data/
│   │       ├── models/
│   │       ├── data_sources/
│   │       └── repositories/
│   └── feature2/
│       └── ...
├── core/
│   ├── utils/
│   ├── services/
│   └── themes/
├── shared/
│   ├── widgets/
│   └── providers/
└── main.dart
```

### Clean Architecture Layers

- **Presentation Layer**: UI components, screens, widgets, and view models (Riverpod providers)
- **Domain Layer**: Business logic, entities, use cases, and repository interfaces
- **Data Layer**: Data models, data sources (local/remote), and repository implementations

This structure promotes:

- High cohesion within features
- Low coupling between features
- Easy testing and maintenance
- Scalability for large applications

## Beneficial Design Patterns

### Repository Pattern

Abstract data access logic to decouple business logic from data sources:

```dart
abstract class Repository<T> {
  Future<List<T>> getAll();
  Future<T?> getById(String id);
  Future<void> save(T item);
  Future<void> delete(String id);
}

class ConcreteRepository implements Repository<Model> {
  final DataSource _dataSource;

  ConcreteRepository(this._dataSource);

  @override
  Future<List<Model>> getAll() => _dataSource.fetchAll();

  // Implement other methods
}
```

### Service Layer

Encapsulate complex business logic and orchestrate operations across repositories:

```dart
class BusinessService {
  final Repository<Model1> _repo1;
  final Repository<Model2> _repo2;

  BusinessService(this._repo1, this._repo2);

  Future<void> performComplexOperation() async {
    final data1 = await _repo1.getAll();
    final data2 = await _repo2.getAll();
    // Business logic combining data1 and data2
  }
}
```

### MVVM with Riverpod

Model-View-ViewModel pattern using Riverpod for reactive state management:

- **Model**: Data entities and business logic
- **View**: UI widgets that observe ViewModel state
- **ViewModel**: Riverpod providers managing state and business logic

```dart
final viewModelProvider = StateNotifierProvider<ViewModel, ViewState>((ref) {
  return ViewModel(ref.read(repositoryProvider));
});

class ViewModel extends StateNotifier<ViewState> {
  final Repository<Model> _repository;

  ViewModel(this._repository) : super(ViewState.initial());

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await _repository.getAll();
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  void performAction() {
    // Update state reactively
    state = state.copyWith(someProperty: newValue);
  }
}
```

### Additional Patterns

- **Dependency Injection**: Use Riverpod's provider system for DI
- **Observer Pattern**: Implemented via Riverpod's reactive nature
- **Factory Pattern**: For creating complex objects or choosing implementations
- **Singleton Pattern**: For shared services (use Riverpod providers)

## App Architecture

### Project Structure

```
lib/
├── main.dart                    # App entry point with ProviderScope
├── models/                      # Data models
├── providers/                   # Riverpod providers for state management
├── screens/                     # Main app screens
├── utils/                       # Utility functions
├── widgets/                     # Reusable widgets
└── test/                        # Test files
    ├── providers/
    ├── screens/
    ├── utils/
    └── widgets/
```

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9
  shared_preferences: ^2.2.2
  # Add app-specific dependencies here

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  riverpod_lint: ^2.3.10
  mockito: ^5.4.4
  build_runner: ^2.4.7
```

## Feature Specifications

### 1. Directory Management

- **Adding Directories**: Support for adding directories through file picker dialog or drag-and-drop functionality (macOS desktop)
- **Directory Grid Display**: Customizable grid layout with 2-5 columns adjustable via popup menu
- **Directory Search**: Real-time search functionality to filter directories by name
- **Directory Tagging**: Assign multiple tags to directories for organization and categorization
- **Tag-Based Filtering**: Filter directories using selected tag chips with multi-select capability
- **Directory Deletion**: Remove directories from the app's managed list (does not delete from filesystem)
- **Directory Previews**: Display first media file as thumbnail preview for each directory
- **Hover Effects**: Animated scaling and elevation changes on directory grid items during hover

### 2. Media Viewing

- **Supported File Formats**:
  - Images: JPG, JPEG, PNG, GIF, JFIF
  - Videos: MP4, MOV, AVI
  - Text Files: TXT (displayed as content cards with trimming for long content)
- **Grid Layout**: Customizable grid with 2-5 columns, consistent across all screens
- **Thumbnail Previews**: High-quality image thumbnails and video previews with hover-to-play functionality
- **Video Playback in Grid**: Muted video playback on hover for preview purposes
- **Text File Display**: TXT files shown as cards with content preview, truncated for readability
- **Nested Directory Navigation**: Tap on subdirectory folders to navigate deeper into directory structure
- **Media Filtering**: Filter media items by assigned tags using chip-based selection
- **File System Filtering**: Automatic exclusion of system files (e.g., macOS .\_ files)
- **Error Handling**: Graceful handling of corrupted or inaccessible files with error icons

### 3. Tagging System

- **Dual Tagging Support**: Tag both directories and individual media files
- **Dynamic Tag Creation**: On-the-fly tag creation through dialog inputs
- **Tag Management**: Add/remove tags via long-press dialogs on items
- **Tag Persistence**: All tags stored persistently using SharedPreferences
- **Tag Filtering UI**: Interactive filter chips for selecting multiple tags
- **Tag Display**: Visual chips showing assigned tags on items and in management dialogs
- **Global Tag List**: Unified tag system shared between directories and media

### 4. Favorites System

- **Favorite Toggle**: Mark/unmark individual media files as favorites with heart icon
- **Favorites Screen**: Dedicated screen displaying all favorited media in grid layout
- **Slideshow Mode**: Full-screen slideshow with auto-advance for images (5-second intervals)
- **Sequential Video Playback**: Videos play sequentially in slideshow mode
- **Slideshow Controls**: Keyboard navigation (arrow keys) and manual controls
- **Full-Screen Viewing**: Immersive full-screen mode for favorites slideshow
- **Video Controls in Slideshow**: Play/pause, loop toggle, mute, progress bar with scrubbing
- **Slideshow Navigation**: Previous/next controls and automatic progression

### 5. Full-Screen Media Viewing

- **Immersive Mode**: Black background full-screen viewing for individual media
- **Image Zoom and Pan**: Interactive zooming (0.5x to 4x) and panning for images using InteractiveViewer
- **Video Playback Controls**:
  - Play/pause toggle
  - Loop/repeat toggle
  - Mute/unmute toggle
  - Progress bar with scrubbing capability
- **Keyboard Navigation**: Arrow keys for navigation, Escape to exit full-screen
- **Favorite Toggle**: Heart icon in full-screen mode for adding/removing favorites
- **Video Progress Indicator**: Visual progress bar with customizable colors
- **Hover-Based Controls**: Video controls appear on mouse hover in full-screen

### 6. User Interface and Interactions

- **Material Design**: Platform-adapted Material Design for iOS and macOS
- **Responsive Grids**: Adaptive grid layouts that work across different screen sizes
- **Hover Effects and Animations**:
  - Scale transformations on hover
  - Elevation changes
  - Hero animations for smooth transitions
- **Drag-and-Drop**: Visual feedback during drag operations with color changes
- **Loading States**: Circular progress indicators during media loading
- **Error Handling**: Broken image icons and error builders for failed media loads
- **Gesture Support**:
  - Tap to open/view
  - Double-tap to enter full-screen
  - Long-press for tagging dialogs
  - Secondary tap (right-click) for delete options
- **Keyboard Shortcuts**: Full keyboard navigation support in full-screen modes

### 7. File Operations and Management

- **File Deletion**: Delete individual media files or entire directories from filesystem
- **Directory Deletion**: Recursive deletion of directories and contents
- **File System Permissions**: Proper handling of file access permissions
- **Path Management**: Robust path handling and validation
- **File Type Detection**: Extension-based file type identification

### 8. Data Persistence

- **SharedPreferences Integration**: Persistent storage for directories, tags, favorites, and settings
- **State Restoration**: App state maintained across restarts
- **Data Migration**: Support for data persistence during app updates

### 9. Performance Optimizations

- **Lazy Loading**: Efficient loading of media thumbnails and previews
- **Video Controller Management**: Proper disposal and reuse of video controllers
- **Memory Management**: Cleanup of resources to prevent memory leaks
- **Asynchronous Operations**: Non-blocking file operations and UI updates
  Ensure features align with clean architecture principles and use the recommended design patterns.

## State Management with Riverpod

### Provider Structure

```dart
// Example provider definitions
final dataProvider = StateNotifierProvider<DataNotifier, List<Model>>((ref) {
  return DataNotifier();
});

final filteredDataProvider = Provider.family<List<Model>, FilterCriteria>((ref, criteria) {
  final data = ref.watch(dataProvider);
  return data.where((item) => criteria.matches(item)).toList();
});
```

### Combining Requests

- Use `ref.watch` to combine providers reactively; avoid `ref.watch` in imperative code.
- Use `ref.read` only when necessary, such as in Notifier methods.
- Prefer `ref.watch` over `ref.listen` for declarative logic.

### Auto Dispose & State Disposal

- Enable `autoDispose` for parameterized providers to prevent memory leaks.
- Use `ref.onDispose` to register cleanup logic.
- Use `ref.invalidate` or `ref.invalidateSelf` to manually destroy provider state.

### Eager Initialization

- Initialize providers eagerly by reading them at the app root if needed.
- Handle loading and error states appropriately in UI.

### Passing Arguments to Providers

- Use provider families (`.family`) to pass arguments.
- Enable `autoDispose` for families.
- Ensure parameters have proper equality semantics; prefer records for multiple parameters.

### Provider Observers

- Implement `ProviderObserver` for logging, analytics, or error reporting.
- Register observers in `ProviderScope`.

### Performing Side Effects

- Use Notifiers to expose methods for side effects.
- Update UI state after side effects by setting state, invalidating, or manual cache updates.
- Handle loading and error states in UI.

### Migration Notes

- Convert ChangeNotifier to StateNotifier
- Use ref.watch for reactive updates
- Implement proper provider dependencies
- Maintain async operations for SharedPreferences
- Install and use `riverpod_lint` for best practices

## Testing Strategy

### Unit Tests

- Provider logic and state changes
- Utility functions
- Model serialization/deserialization
- Use Mockito for mocking dependencies

### Widget Tests

- Screen rendering and interactions
- Widget state management
- User gesture handling
- Wrap widgets with `ProviderScope` for Riverpod

### Integration Tests

- Complete user flows
- Navigation between screens
- Persistence across app restarts

### Testing Providers

- Create new `ProviderContainer` for each unit test
- Use `overrides` to inject mocks
- Prefer mocking dependencies over Notifiers
- Use `container.listen` for auto-dispose providers

### Mockito Usage

- Use `@GenerateMocks` or `@GenerateNiceMocks` for mock generation
- Stub methods with `when().thenReturn()` or `thenThrow()`
- Verify interactions with `verify()`
- Use `Fake` for lightweight implementations, `Mock` for verification
- Prefer real objects or fakes over mocks when possible

### Test Example

```dart
void main() {
  test('Provider updates state correctly', () {
    final container = ProviderContainer();
    final provider = container.read(dataProvider.notifier);

    provider.addItem(testItem);

    final data = container.read(dataProvider);
    expect(data.length, 1);
    expect(data.first, testItem);
  });

  test('Mocked repository test', () {
    final mockRepo = MockRepository();
    when(mockRepo.getAll()).thenReturn([testItem]);

    final container = ProviderContainer(overrides: [
      repositoryProvider.overrideWithValue(mockRepo),
    ]);

    final data = container.read(dataProvider);
    expect(data, [testItem]);
    verify(mockRepo.getAll()).called(1);
  });
}
```

## Platform-Specific Configurations

### iOS Configuration

- Update ios/Runner/Info.plist for necessary permissions
- Configure app icons and launch screens

### macOS Configuration

- Update macos/Runner/Info.plist for file access
- Enable drag-and-drop functionality
- Configure app entitlements

### Build Configuration

- Remove android/ directory entirely
- Update build scripts for iOS/macOS only
- Configure CI/CD for Apple platforms

## Implementation Steps

1. **Project Setup**

   - Create new Flutter project
   - Add dependencies
   - Configure for iOS/macOS only

2. **Architecture Implementation**

   - Set up feature-based structure with clean architecture layers
   - Implement repository and service patterns
   - Create Riverpod providers following MVVM pattern

3. **State Management Migration**

   - Convert existing providers to Riverpod
   - Update main.dart with ProviderScope
   - Migrate all screens to use ref.watch/ref.read

4. **UI Implementation**

   - Implement screens and widgets
   - Adapt for Riverpod usage
   - Ensure platform-specific optimizations

5. **Testing Implementation**

   - Write comprehensive test suite
   - Set up test mocks and fixtures
   - Configure test coverage reporting

6. **Platform Configuration**

   - Configure iOS/macOS permissions
   - Test platform-specific features
   - Verify performance on both platforms

7. **Quality Assurance**
   - Run full test suite
   - Manual testing on iOS and macOS
   - Performance optimization
   - Code review and refactoring

## Success Criteria

- All specified features implemented and working
- Riverpod state management fully integrated
- Clean architecture and design patterns properly implemented
- Comprehensive test coverage achieved (>80%)
- App runs smoothly on iOS and macOS
- No Android dependencies or configurations
- Code follows Flutter best practices and Effective Dart rules
- Proper error handling and edge cases covered
- Utilizes Dart 3 features (patterns, records) where appropriate
- Adheres to Riverpod guidelines and uses riverpod_lint
- Testing includes Mockito for mocking and follows best practices

## Additional Considerations

- Maintain backward compatibility for data migration if needed
- Implement proper error handling for operations
- Consider accessibility features for iOS/macOS
- Optimize for different screen sizes and orientations
- Implement proper logging and debugging capabilities
- Strictly follow Effective Dart rules for code quality
- Leverage Dart 3 features like patterns and records for modern code
- Use Riverpod best practices, including auto-dispose, observers, and proper side effect handling
- Ensure all tests use Mockito appropriately and achieve high coverage

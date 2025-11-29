import '../../../media_library/presentation/models/directory_navigation_target.dart';

/// Result returned when leaving the full-screen viewer so the caller can
/// synchronize the currently active directory.
class FullScreenExitResult {
  const FullScreenExitResult({
    required this.currentDirectory,
    required this.currentDirectoryIndex,
    required this.siblingDirectories,
  });

  final DirectoryNavigationTarget currentDirectory;
  final int currentDirectoryIndex;
  final List<DirectoryNavigationTarget> siblingDirectories;
}

import 'dart:io';

/// Service for platform-specific operations
class PlatformService {
  /// Checks if running on macOS
  bool get isMacOS => Platform.isMacOS;

  /// Checks if running on iOS
  bool get isIOS => Platform.isIOS;

  /// Gets the platform name
  String get platformName {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// Gets the home directory path
  String? get homeDirectory => Platform.environment['HOME'];

  /// Gets the documents directory path
  Future<String?> getDocumentsDirectory() async {
    try {
      if (Platform.isMacOS) {
        final home = homeDirectory;
        return home != null ? '$home/Documents' : null;
      }
      if (Platform.isIOS) {
        // On iOS, use the app's documents directory
        final directory = await _getApplicationDocumentsDirectory();
        return directory?.path;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gets the application documents directory
  Future<Directory?> _getApplicationDocumentsDirectory() async {
    try {
      // For simplicity, use a standard location
      // In a real app, you'd use path_provider package
      final home = homeDirectory;
      if (home != null) {
        final docsDir = Directory('$home/Documents');
        if (!await docsDir.exists()) {
          await docsDir.create(recursive: true);
        }
        return docsDir;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gets the temporary directory
  Future<String?> getTemporaryDirectory() async {
    try {
      final tempDir = await _getTempDirectory();
      return tempDir?.path;
    } catch (e) {
      return null;
    }
  }

  Future<Directory?> _getTempDirectory() async {
    try {
      final tempPath = Directory.systemTemp.path;
      final tempDir = Directory(tempPath);
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      return tempDir;
    } catch (e) {
      return null;
    }
  }

  /// Checks if the platform supports right-click context menus
  bool get supportsContextMenus => Platform.isMacOS;

  /// Checks if the platform supports drag and drop
  bool get supportsDragAndDrop => Platform.isMacOS;

  /// Gets platform-specific path separator
  String get pathSeparator => Platform.pathSeparator;

  /// Joins paths in a platform-specific way
  String joinPaths(String part1, String part2, [String? part3, String? part4]) {
    final parts = [part1, part2];
    if (part3 != null) parts.add(part3);
    if (part4 != null) parts.add(part4);
    return parts.join(pathSeparator);
  }

  /// Normalizes a path for the current platform
  String normalizePath(String path) {
    return path.replaceAll('/', pathSeparator).replaceAll('\\', pathSeparator);
  }

  /// Gets the file system case sensitivity
  bool get isCaseSensitiveFileSystem => !Platform.isWindows;
}

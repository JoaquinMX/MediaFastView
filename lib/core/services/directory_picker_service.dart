import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import 'bookmarks_channel.dart';
import 'logging_service.dart';

/// Service that picks directories across platforms.
final class DirectoryPickerService {
  const DirectoryPickerService();

  /// Picks directories (or files on iOS) and returns directory paths.
  Future<List<String>> pickDirectories({
    String? initialDirectoryPath,
    String? dialogTitle,
  }) async {
    if (Platform.isIOS) {
      return _pickDirectoriesFromIos();
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle ?? 'Select Directory',
      initialDirectory: initialDirectoryPath,
    );

    if (selectedDirectory == null || selectedDirectory.isEmpty) {
      return const <String>[];
    }

    return <String>[selectedDirectory];
  }

  /// Picks a single directory path, if available.
  Future<String?> pickSingleDirectory({
    String? initialDirectoryPath,
    String? dialogTitle,
  }) async {
    final selections = await pickDirectories(
      initialDirectoryPath: initialDirectoryPath,
      dialogTitle: dialogTitle,
    );
    if (selections.isEmpty) {
      return null;
    }
    return selections.first;
  }

  Future<List<String>> _pickDirectoriesFromIos() async {
    final uris = await BookmarksChannel.pickDirectoryOrFiles();
    if (uris.isEmpty) {
      return const <String>[];
    }

    final directoryPaths = <String>[];
    final filesToCopy = <File>[];

    for (final uri in uris) {
      if (uri.scheme != 'file') {
        continue;
      }
      final path = uri.toFilePath();
      try {
        final type = await FileSystemEntity.type(path, followLinks: false);
        switch (type) {
          case FileSystemEntityType.directory:
            directoryPaths.add(path);
          case FileSystemEntityType.file:
            filesToCopy.add(File(path));
          case FileSystemEntityType.link:
          case FileSystemEntityType.notFound:
            break;
        }
      } catch (error) {
        LoggingService.instance.warning(
          'Failed to inspect picked path: $path ($error)',
        );
      }
    }

    if (filesToCopy.isNotEmpty) {
      final sessionDirectory = await _createSessionDirectory();
      final copiedFiles = await _copyFiles(filesToCopy, sessionDirectory);
      if (copiedFiles.isNotEmpty) {
        directoryPaths.add(sessionDirectory.path);
      }
    }

    return directoryPaths;
  }

  Future<Directory> _createSessionDirectory() async {
    return Directory.systemTemp.createTemp('media_fast_view_session_');
  }

  Future<List<String>> _copyFiles(
    List<File> files,
    Directory targetDirectory,
  ) async {
    final copiedPaths = <String>[];

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      if (!await file.exists()) {
        continue;
      }

      final originalName = p.basename(file.path);
      final nameWithoutExtension = p.basenameWithoutExtension(originalName);
      final extension = p.extension(originalName);
      var targetPath = p.join(targetDirectory.path, originalName);

      if (await File(targetPath).exists()) {
        targetPath = p.join(
          targetDirectory.path,
          '${nameWithoutExtension}_$index$extension',
        );
      }

      try {
        final copiedFile = await file.copy(targetPath);
        copiedPaths.add(copiedFile.path);
      } catch (error) {
        LoggingService.instance.warning(
          'Failed to copy picked file ${file.path}: $error',
        );
      }
    }

    return copiedPaths;
  }
}

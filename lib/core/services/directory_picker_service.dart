import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'bookmarks_channel.dart';
import 'directory_access_grant.dart';

/// Selects directories together with any persistent access grants.
abstract interface class DirectoryPicker {
  Future<List<DirectoryAccessGrant>> pickDirectories({
    String? initialDirectoryPath,
    String? dialogTitle,
  });

  Future<DirectoryAccessGrant?> pickSingleDirectory({
    String? initialDirectoryPath,
    String? dialogTitle,
  });
}

/// System-backed directory picker for supported platforms.
final class DirectoryPickerService implements DirectoryPicker {
  const DirectoryPickerService();

  /// Picks directories together with any persistent access grants.
  @override
  Future<List<DirectoryAccessGrant>> pickDirectories({
    String? initialDirectoryPath,
    String? dialogTitle,
  }) async {
    if (Platform.isIOS) {
      return BookmarksChannel.pickDirectories(allowsMultipleSelection: true);
    }

    final selectedDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle ?? 'Select Directory',
      initialDirectory: initialDirectoryPath,
    );

    if (selectedDirectory == null || selectedDirectory.isEmpty) {
      return const <DirectoryAccessGrant>[];
    }

    return <DirectoryAccessGrant>[
      DirectoryAccessGrant(path: selectedDirectory),
    ];
  }

  /// Picks a single directory together with any persistent access grant.
  @override
  Future<DirectoryAccessGrant?> pickSingleDirectory({
    String? initialDirectoryPath,
    String? dialogTitle,
  }) async {
    final selections = Platform.isIOS
        ? await BookmarksChannel.pickDirectories(allowsMultipleSelection: false)
        : await pickDirectories(
            initialDirectoryPath: initialDirectoryPath,
            dialogTitle: dialogTitle,
          );
    if (selections.isEmpty) {
      return null;
    }
    return selections.first;
  }
}

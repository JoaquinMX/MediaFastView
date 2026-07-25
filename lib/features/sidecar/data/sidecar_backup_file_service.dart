import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Opens native macOS/iOS pickers for portable sidecar backup files.
abstract interface class SidecarBackupFileService {
  /// Lets the user choose a destination and writes [contents] there.
  ///
  /// Returns false when the picker is cancelled.
  Future<bool> saveBackup(String contents, {required String suggestedName});

  /// Lets the user choose a JSON backup and returns its UTF-8 contents.
  ///
  /// Returns null when the picker is cancelled.
  Future<String?> pickBackup();
}

/// [SidecarBackupFileService] backed by `file_picker`.
class FilePickerSidecarBackupFileService implements SidecarBackupFileService {
  const FilePickerSidecarBackupFileService();

  @override
  Future<bool> saveBackup(
    String contents, {
    required String suggestedName,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(contents));

    if (Platform.isIOS) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Tags & Favorites Backup',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        bytes: bytes,
      );
      return path != null;
    }

    if (Platform.isMacOS) {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Tags & Favorites Backup',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      if (path == null) {
        return false;
      }
      await File(path).writeAsBytes(bytes, flush: true);
      return true;
    }

    throw UnsupportedError(
      'Sidecar backups are only supported on macOS and iOS.',
    );
  }

  @override
  Future<String?> pickBackup() async {
    if (!Platform.isMacOS && !Platform.isIOS) {
      throw UnsupportedError(
        'Sidecar backups are only supported on macOS and iOS.',
      );
    }

    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Load Tags & Favorites Backup',
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selected = result.files.single;
    final bytes = selected.bytes;
    if (bytes != null) {
      return utf8.decode(bytes);
    }
    final path = selected.path;
    if (path == null) {
      throw const FormatException('The selected backup could not be read.');
    }
    return File(path).readAsString();
  }
}

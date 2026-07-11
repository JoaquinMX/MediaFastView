import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/services/bookmark_service.dart';
import '../../../../core/services/file_service.dart';
import '../../../../core/services/file_transfer_result.dart';
import '../../../../core/services/permission_service.dart';
import '../../domain/repositories/file_operations_repository.dart';

/// Implementation of FileOperationsRepository
class FileOperationsRepositoryImpl implements FileOperationsRepository {
  const FileOperationsRepositoryImpl(
    this._fileService,
    this._permissionService,
    this._bookmarkService,
  );

  final FileService _fileService;
  final PermissionService _permissionService;
  final BookmarkService _bookmarkService;

  @override
  Future<void> deleteFile(String filePath, {String? bookmarkData}) async {
    if (Platform.isMacOS) {
      // On macOS, move to Trash (recoverable) inside security-scoped access to
      // the enclosing bookmarked directory. The native call owns the scope, so
      // we skip the pre-check that would otherwise fail without active access.
      await _bookmarkService.moveToTrash(filePath, bookmarkData: bookmarkData);
      return;
    }
    throw UnsupportedError('Deleting files is not supported on this platform');
  }

  @override
  Future<void> deleteDirectory(
    String directoryPath, {
    String? bookmarkData,
  }) async {
    if (Platform.isMacOS) {
      await _bookmarkService.moveToTrash(
        directoryPath,
        bookmarkData: bookmarkData,
      );
      return;
    }
    throw UnsupportedError(
      'Deleting directories is not supported on this platform',
    );
  }

  @override
  Future<FileTransferResult> moveItem(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Moving files is not supported on this platform');
    }
    // The native call owns both security scopes, so as with delete we go
    // straight to it rather than through FileService: a raw File.rename would
    // run outside the scope and be denied by the sandbox.
    return _bookmarkService.moveItem(
      sourcePath: sourcePath,
      destinationPath: p.join(destinationDirectoryPath, p.basename(sourcePath)),
      sourceBookmarkData: sourceBookmarkData,
      destinationBookmarkData: destinationBookmarkData,
      conflictStrategy: conflictStrategy,
    );
  }

  @override
  Future<FileTransferResult> copyItem(
    String sourcePath, {
    required String destinationDirectoryPath,
    String? sourceBookmarkData,
    String? destinationBookmarkData,
    ConflictStrategy conflictStrategy = ConflictStrategy.fail,
  }) {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Copying files is not supported on this platform');
    }
    return _bookmarkService.copyItem(
      sourcePath: sourcePath,
      destinationPath: p.join(destinationDirectoryPath, p.basename(sourcePath)),
      sourceBookmarkData: sourceBookmarkData,
      destinationBookmarkData: destinationBookmarkData,
      conflictStrategy: conflictStrategy,
    );
  }

  @override
  Future<bool> validatePath(String path) async {
    await _permissionService.ensureStoragePermission();
    return await _permissionService.canAccessPath(path);
  }

  @override
  String getFileType(String filePath) {
    return _fileService.getMediaTypeFromExtension(filePath);
  }
}

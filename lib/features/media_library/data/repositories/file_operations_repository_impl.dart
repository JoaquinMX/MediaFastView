import '../../../../core/services/file_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../domain/repositories/file_operations_repository.dart';

/// Implementation of FileOperationsRepository
class FileOperationsRepositoryImpl implements FileOperationsRepository {
  const FileOperationsRepositoryImpl(
    this._fileService,
    this._permissionService,
  );

  final FileService _fileService;
  final PermissionService _permissionService;

  @override
  Future<void> deleteFile(String filePath) async {
    await _permissionService.ensureStoragePermission();
    await _permissionService.ensurePathAccessible(filePath);
    await _fileService.deleteFile(filePath);
  }

  @override
  Future<void> deleteDirectory(String directoryPath) async {
    await _permissionService.ensureStoragePermission();
    await _permissionService.ensurePathAccessible(directoryPath);
    await _fileService.deleteDirectory(directoryPath);
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

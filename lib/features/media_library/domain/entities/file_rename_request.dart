class FileRenameRequest {
  const FileRenameRequest({
    required this.originalPath,
    required this.newName,
    this.preserveExtension = true,
  });

  final String originalPath;
  final String newName;
  final bool preserveExtension;
}

/// A directory path together with any persistent access granted by the system.
final class DirectoryAccessGrant {
  const DirectoryAccessGrant({required this.path, this.bookmarkData});

  final String path;
  final String? bookmarkData;
}

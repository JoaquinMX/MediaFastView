/// Filename prefixes excluded from media discovery and directory previews.
const Set<String> excludedMediaFileNamePrefixes = <String>{
  '._',
  '.DS_Store',
  'Thumbs.db',
  'desktop.ini',
  '.mediafastview.json',
};

/// Whether [fileName] identifies system or application metadata.
///
/// The comparison intentionally matches the existing media-scanner behavior:
/// it is prefix-based and case-sensitive. Callers should pass a basename.
bool isExcludedMediaFileName(String fileName) {
  return excludedMediaFileNamePrefixes.any(fileName.startsWith);
}

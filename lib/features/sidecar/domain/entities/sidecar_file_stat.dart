/// The live size + modification time of a file, captured while security-scoped
/// access is held.
///
/// [mtimeMs] is `FileStat.modified.millisecondsSinceEpoch`, the exact value the
/// media scanner hashes, so a media id recomputed from these two fields (plus
/// the file name) matches what the scanner produces.
class SidecarFileStat {
  const SidecarFileStat({required this.size, required this.mtimeMs});

  final int size;
  final int mtimeMs;
}

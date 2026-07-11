/// Whether a transfer relocates the item or duplicates it.
enum TransferMode { move, copy }

/// What to do when an item of the same name already exists at the destination.
///
/// There is deliberately no `overwrite`: a transfer never destroys an existing
/// file. The user either keeps both (the item is renamed) or skips it.
enum ConflictStrategy { fail, keepBoth }

/// The outcome of a native move or copy.
///
/// [size] and [lastModified] are the destination's *post-transfer* metadata.
/// They matter because media ids are derived from size, modification time and
/// file name — so these are what tell the caller whether the item's identity
/// survived the transfer.
class FileTransferResult {
  const FileTransferResult({
    required this.sourcePath,
    required this.destinationPath,
    required this.renamed,
    required this.sameVolume,
    required this.size,
    required this.lastModified,
    required this.isDirectory,
  });

  factory FileTransferResult.fromMap(Map<Object?, Object?> map) {
    return FileTransferResult(
      sourcePath: map['sourcePath'] as String? ?? '',
      destinationPath: map['destinationPath'] as String? ?? '',
      renamed: map['renamed'] as bool? ?? false,
      sameVolume: map['sameVolume'] as bool? ?? false,
      size: map['size'] as int? ?? 0,
      lastModified: DateTime.fromMillisecondsSinceEpoch(
        map['modifiedEpochMs'] as int? ?? 0,
      ),
      isDirectory: map['isDirectory'] as bool? ?? false,
    );
  }

  final String sourcePath;

  /// The item's actual final path, which differs from the requested one when a
  /// name collision was resolved by renaming.
  final String destinationPath;

  /// Whether a name collision forced a rename (the "keep both" outcome).
  final bool renamed;

  /// Advisory only. Never use this to decide whether the media id changed: a
  /// same-volume transfer that got renamed also changes the id, because the file
  /// name is part of the id. Compare the recomputed id instead.
  final bool sameVolume;

  final int size;
  final DateTime lastModified;
  final bool isDirectory;

  @override
  String toString() =>
      'FileTransferResult($sourcePath -> $destinationPath, '
      'renamed: $renamed, sameVolume: $sameVolume)';
}

import 'package:flutter/foundation.dart';

/// How many things carry a given tag.
///
/// Files and folders are counted separately because directories carry tags too
/// (`DirectoryEntity.tagIds`), and a single total would quietly under-report —
/// which matters most in the delete confirmation, where the number is the whole
/// point.
@immutable
class TagUsage {
  const TagUsage({this.mediaCount = 0, this.directoryCount = 0});

  static const none = TagUsage();

  final int mediaCount;
  final int directoryCount;

  int get total => mediaCount + directoryCount;

  bool get isUnused => total == 0;

  TagUsage copyWith({int? mediaCount, int? directoryCount}) {
    return TagUsage(
      mediaCount: mediaCount ?? this.mediaCount,
      directoryCount: directoryCount ?? this.directoryCount,
    );
  }

  /// Reads as "240 files · 3 folders", dropping whichever half is zero.
  ///
  /// Empty when nothing carries the tag — callers decide how to say "unused",
  /// since the wording differs between a list row and a confirmation dialog.
  String describe() {
    final parts = <String>[
      if (mediaCount > 0) '$mediaCount file${mediaCount == 1 ? '' : 's'}',
      if (directoryCount > 0)
        '$directoryCount folder${directoryCount == 1 ? '' : 's'}',
    ];
    return parts.join(' · ');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TagUsage &&
          runtimeType == other.runtimeType &&
          mediaCount == other.mediaCount &&
          directoryCount == other.directoryCount;

  @override
  int get hashCode => Object.hash(mediaCount, directoryCount);

  @override
  String toString() =>
      'TagUsage(mediaCount: $mediaCount, directoryCount: $directoryCount)';
}

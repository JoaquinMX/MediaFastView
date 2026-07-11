import 'package:flutter/foundation.dart';

/// A node in a directory hierarchy derived from media file paths.
///
/// The app never persists a parent/child relationship between directories:
/// `MediaEntity.directoryId` holds the id of the *library root*, not of the
/// folder the file actually sits in. Hierarchy therefore only exists implicitly
/// in [MediaEntity.path], and this node is the materialised form of it. See
/// `buildDirectoryTree` in `shared/utils/directory_tree_builder.dart`.
@immutable
class DirectoryTreeNode {
  const DirectoryTreeNode({
    required this.path,
    required this.name,
    required this.children,
    required this.directMediaCount,
    required this.totalMediaCount,
  });

  /// Normalized absolute path of the directory.
  final String path;

  /// Display name: the basename, or the library root's name for a root node.
  final String name;

  final List<DirectoryTreeNode> children;

  /// Media sitting directly in this directory, excluding sub-directories.
  final int directMediaCount;

  /// [directMediaCount] plus the totals of every descendant.
  final int totalMediaCount;

  bool get hasChildren => children.isNotEmpty;

  /// Yields this node followed by every descendant, depth first.
  Iterable<DirectoryTreeNode> get subtree sync* {
    yield this;
    for (final child in children) {
      yield* child.subtree;
    }
  }

  DirectoryTreeNode copyWith({
    String? path,
    String? name,
    List<DirectoryTreeNode>? children,
    int? directMediaCount,
    int? totalMediaCount,
  }) {
    return DirectoryTreeNode(
      path: path ?? this.path,
      name: name ?? this.name,
      children: children ?? this.children,
      directMediaCount: directMediaCount ?? this.directMediaCount,
      totalMediaCount: totalMediaCount ?? this.totalMediaCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DirectoryTreeNode &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          directMediaCount == other.directMediaCount &&
          totalMediaCount == other.totalMediaCount &&
          listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(
        path,
        name,
        directMediaCount,
        totalMediaCount,
        Object.hashAll(children),
      );

  @override
  String toString() =>
      'DirectoryTreeNode(path: $path, name: $name, '
      'directMediaCount: $directMediaCount, '
      'totalMediaCount: $totalMediaCount, '
      'children: ${children.length})';
}

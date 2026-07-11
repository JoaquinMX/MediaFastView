import 'package:path/path.dart' as p;

import '../../features/media_library/domain/entities/directory_entity.dart';
import '../../features/media_library/domain/entities/directory_tree_node.dart';
import '../../features/media_library/domain/entities/media_entity.dart';

/// Builds directory hierarchies out of media file paths.
///
/// Media rows carry the id of their *library root* in `directoryId`, never the
/// id of the folder they actually live in, so the containing folder can only be
/// recovered from [MediaEntity.path]. Every helper here works purely on path
/// strings and touches no disk.

/// Returns the normalized root path from [normalizedRootPaths] that contains
/// [path], or `null` when [path] lies outside every root.
String? findContainingRootPath(
  String path,
  Iterable<String> normalizedRootPaths,
) {
  final normalized = p.normalize(path);
  for (final rootPath in normalizedRootPaths) {
    if (normalized == rootPath || p.isWithin(rootPath, normalized)) {
      return rootPath;
    }
  }
  return null;
}

/// Every directory path reachable from [media], plus the [roots] themselves.
///
/// A path is reachable when it is the parent of a media item, or an ancestor of
/// such a parent up to (and including) the containing root. Used to cascade a
/// selection over a whole subtree, so it is deliberately built from *all* media
/// rather than a filtered subset: checking a folder must include everything
/// under it, even parts a tag filter is currently hiding.
Set<String> collectDirectoryPaths({
  required List<DirectoryEntity> roots,
  required Iterable<MediaEntity> media,
}) {
  final rootPaths = _normalizedRootPaths(roots);
  final paths = <String>{...rootPaths};
  if (rootPaths.isEmpty) {
    return paths;
  }

  for (final item in media) {
    final parent = p.dirname(p.normalize(item.path));
    final rootPath = findContainingRootPath(parent, rootPaths);
    if (rootPath == null) {
      continue;
    }
    _addAncestorChain(parent, rootPath, paths);
  }

  return paths;
}

/// Builds the directory forest spanned by [media], one tree per library root.
///
/// Roots are always present, even with no matching media, so the filter UI does
/// not shuffle around as the user changes tags. Sub-directories only appear when
/// they (or a descendant) actually hold a media item from [media] — the caller
/// is expected to pass the media that currently matches the other filters, which
/// makes the counts live and guarantees no branch leads to an empty result.
/// Media outside every root is ignored.
List<DirectoryTreeNode> buildDirectoryTree({
  required List<DirectoryEntity> roots,
  required Iterable<MediaEntity> media,
}) {
  if (roots.isEmpty) {
    return const <DirectoryTreeNode>[];
  }

  final rootNameByPath = <String, String>{
    for (final root in roots) p.normalize(root.path): root.name,
  };
  final rootPaths = rootNameByPath.keys.toList(growable: false);

  final directCounts = <String, int>{};
  final nodePaths = <String>{...rootPaths};

  for (final item in media) {
    final parent = p.dirname(p.normalize(item.path));
    final rootPath = findContainingRootPath(parent, rootPaths);
    if (rootPath == null) {
      continue;
    }
    directCounts.update(parent, (count) => count + 1, ifAbsent: () => 1);
    _addAncestorChain(parent, rootPath, nodePaths);
  }

  final childPathsByParent = <String, List<String>>{};
  for (final path in nodePaths) {
    if (rootNameByPath.containsKey(path)) {
      continue;
    }
    childPathsByParent.putIfAbsent(p.dirname(path), () => <String>[]).add(path);
  }

  final tree = rootPaths
      .map(
        (rootPath) => _buildNode(
          rootPath,
          rootNameByPath[rootPath]!,
          childPathsByParent,
          directCounts,
        ),
      )
      .toList()
    ..sort(_byName);
  return tree;
}

DirectoryTreeNode _buildNode(
  String path,
  String name,
  Map<String, List<String>> childPathsByParent,
  Map<String, int> directCounts,
) {
  final children =
      (childPathsByParent[path] ?? const <String>[])
          .map(
            (childPath) => _buildNode(
              childPath,
              p.basename(childPath),
              childPathsByParent,
              directCounts,
            ),
          )
          .toList()
        ..sort(_byName);

  final directMediaCount = directCounts[path] ?? 0;
  final totalMediaCount = children.fold<int>(
    directMediaCount,
    (total, child) => total + child.totalMediaCount,
  );

  return DirectoryTreeNode(
    path: path,
    name: name,
    children: children,
    directMediaCount: directMediaCount,
    totalMediaCount: totalMediaCount,
  );
}

/// Adds [path] and each of its ancestors up to and including [rootPath].
void _addAncestorChain(String path, String rootPath, Set<String> target) {
  var current = path;
  while (target.add(current) && current != rootPath) {
    final parent = p.dirname(current);
    if (parent == current) {
      return;
    }
    current = parent;
  }
}

List<String> _normalizedRootPaths(List<DirectoryEntity> roots) {
  return roots.map((root) => p.normalize(root.path)).toList(growable: false);
}

int _byName(DirectoryTreeNode a, DirectoryTreeNode b) =>
    a.name.toLowerCase().compareTo(b.name.toLowerCase());

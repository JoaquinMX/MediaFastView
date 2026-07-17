import '../../domain/entities/duplicate_candidate.dart';
import '../../domain/entities/perceptual_hash.dart';

/// Groups perceptually-similar candidates into clusters.
///
/// Near-duplicate grouping is not equality-bucketing: "within N bits" is a
/// range query in Hamming space. A [_BkTree] answers those queries in roughly
/// logarithmic time, and a union-find stitches every match into connected
/// components — so A~B and B~C land A, B and C in one group even when A and C
/// are just outside the threshold.
class DuplicateClusterer {
  const DuplicateClusterer();

  /// Returns clusters of two or more candidates whose hashes are within
  /// [threshold] Hamming distance of a neighbour. Singletons are dropped.
  List<List<DuplicateCandidate>> cluster(
    List<DuplicateCandidate> candidates,
    int threshold,
  ) {
    if (candidates.length < 2) {
      return const [];
    }

    final tree = _BkTree();
    for (var i = 0; i < candidates.length; i++) {
      tree.insert(candidates[i].hash, i);
    }

    final union = _UnionFind(candidates.length);
    for (var i = 0; i < candidates.length; i++) {
      for (final j in tree.within(candidates[i].hash, threshold)) {
        if (j != i) {
          union.unite(i, j);
        }
      }
    }

    final byRoot = <int, List<DuplicateCandidate>>{};
    for (var i = 0; i < candidates.length; i++) {
      byRoot.putIfAbsent(union.find(i), () => []).add(candidates[i]);
    }

    return byRoot.values.where((group) => group.length >= 2).toList();
  }
}

/// A BK-tree over 64-bit hashes in Hamming space. Nodes sharing an exact hash
/// collapse onto one node's [_BkNode.indices] list.
class _BkTree {
  _BkNode? _root;

  void insert(int hash, int index) {
    final root = _root;
    if (root == null) {
      _root = _BkNode(hash)..indices.add(index);
      return;
    }
    var node = root;
    while (true) {
      final distance = hammingDistance(node.hash, hash);
      if (distance == 0) {
        node.indices.add(index);
        return;
      }
      final child = node.children[distance];
      if (child == null) {
        node.children[distance] = _BkNode(hash)..indices.add(index);
        return;
      }
      node = child;
    }
  }

  /// Indices of every stored item within [threshold] of [hash].
  List<int> within(int hash, int threshold) {
    final results = <int>[];
    final root = _root;
    if (root == null) {
      return results;
    }
    final stack = <_BkNode>[root];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      final distance = hammingDistance(node.hash, hash);
      if (distance <= threshold) {
        results.addAll(node.indices);
      }
      // The triangle inequality bounds which children can hold a match: a child
      // at edge-distance d from this node can only contain items in
      // [distance - threshold, distance + threshold].
      final low = distance - threshold;
      final high = distance + threshold;
      node.children.forEach((edge, child) {
        if (edge >= low && edge <= high) {
          stack.add(child);
        }
      });
    }
    return results;
  }
}

class _BkNode {
  _BkNode(this.hash);

  final int hash;
  final List<int> indices = [];
  final Map<int, _BkNode> children = {};
}

/// Iterative union-find with path compression and union by rank.
class _UnionFind {
  _UnionFind(int size)
    : _parent = List<int>.generate(size, (i) => i),
      _rank = List<int>.filled(size, 0);

  final List<int> _parent;
  final List<int> _rank;

  int find(int x) {
    var root = x;
    while (_parent[root] != root) {
      root = _parent[root];
    }
    // Path compression.
    var node = x;
    while (_parent[node] != root) {
      final next = _parent[node];
      _parent[node] = root;
      node = next;
    }
    return root;
  }

  void unite(int a, int b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA == rootB) {
      return;
    }
    if (_rank[rootA] < _rank[rootB]) {
      _parent[rootA] = rootB;
    } else if (_rank[rootA] > _rank[rootB]) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootB] = rootA;
      _rank[rootA]++;
    }
  }
}

import 'package:flutter/material.dart';

import '../../../media_library/domain/entities/directory_tree_node.dart';
import 'directory_hover_preview.dart';

/// Expandable tri-state tree for narrowing a media list down to directories.
///
/// A checked directory means "include the media sitting directly in this
/// folder", and checking cascades over the whole subtree. That makes the parent
/// checkbox indeterminate as soon as one descendant is unchecked, which is what
/// lets the user both widen (check a root) and narrow (uncheck one child, or
/// check a single nested folder) with the same control.
///
/// Wide enough, the tree lays itself out over several columns. Only whole
/// subtrees are ever moved into a column, so the hierarchy survives; a lone
/// expanded root is promoted to a full-width header and its children flow
/// instead, which is what makes the extra width pay off for a single library.
///
/// The widget is deliberately dumb: it renders [nodes], reads [selectedPaths],
/// and reports taps through [onToggle]. Selection lives in `TagsViewModel`,
/// which owns the cascade because it knows about folders the current filters are
/// hiding.
class DirectoryFilterTree extends StatefulWidget {
  const DirectoryFilterTree({
    super.key,
    required this.nodes,
    required this.selectedPaths,
    required this.onToggle,
    this.maxHeight = 320,
  });

  final List<DirectoryTreeNode> nodes;
  final Set<String> selectedPaths;

  /// Called with the normalized path of the directory whose checkbox was hit.
  final ValueChanged<String> onToggle;

  /// Beyond this the tree scrolls internally, so a deep library cannot push the
  /// rest of the filters off screen.
  final double maxHeight;

  @override
  State<DirectoryFilterTree> createState() => _DirectoryFilterTreeState();
}

class _DirectoryFilterTreeState extends State<DirectoryFilterTree> {
  /// Narrower than this and folder names ellipsize away to nothing, so the tree
  /// drops back to fewer columns instead.
  static const double _minColumnWidth = 260;
  static const double _columnSpacing = 16;

  /// Width of the expand/collapse slot. Held the same whether or not the row
  /// has a chevron, so every checkbox at a given depth lines up.
  static const double _chevronSlotWidth = 40;

  final Set<String> _expandedPaths = <String>{};

  @override
  void initState() {
    super.initState();
    // Reveal any pre-existing selection, and open a lone root since there is
    // nothing to choose between at the top level.
    for (final root in widget.nodes) {
      if (widget.nodes.length == 1 || _selectionState(root) != false) {
        _expandedPaths.add(root.path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SingleChildScrollView(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // A column can only ever hold whole subtrees. Flowing the flattened
            // rows instead would let a child head one column while its parent
            // ends another, and the indentation would stop meaning anything.
            final headers = <DirectoryTreeNode>[];
            var blocks = widget.nodes;

            // One expanded root would spend every extra column on itself, so
            // promote it to a full-width header and lay its children out
            // instead. This is what puts the horizontal space to work in the
            // common single-library case.
            while (blocks.length == 1 &&
                blocks.single.hasChildren &&
                _expandedPaths.contains(blocks.single.path)) {
              headers.add(blocks.single);
              blocks = blocks.single.children;
            }

            final columns = _distributeIntoColumns(
              blocks,
              _columnCount(constraints.maxWidth, blocks.length),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var depth = 0; depth < headers.length; depth += 1)
                  _buildRow(headers[depth], depth),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < columns.length; index += 1) ...[
                      if (index > 0) const SizedBox(width: _columnSpacing),
                      Expanded(child: _buildColumn(columns[index])),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildColumn(List<DirectoryTreeNode> blocks) {
    final rows = <Widget>[];
    for (final block in blocks) {
      _appendRows(block, 0, rows);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  int _columnCount(double availableWidth, int blockCount) {
    if (blockCount < 2 || !availableWidth.isFinite) {
      return 1;
    }

    final fits = ((availableWidth + _columnSpacing) /
            (_minColumnWidth + _columnSpacing))
        .floor();
    return fits.clamp(1, blockCount);
  }

  /// Splits [blocks] into [columnCount] runs of roughly equal height.
  ///
  /// Runs rather than a round-robin, so a column still reads top to bottom in
  /// the tree's own order. Height is measured in visible rows, which is why a
  /// column holding one deep expanded folder can carry fewer blocks than its
  /// neighbours.
  List<List<DirectoryTreeNode>> _distributeIntoColumns(
    List<DirectoryTreeNode> blocks,
    int columnCount,
  ) {
    if (columnCount < 2) {
      return [blocks];
    }

    final heights = blocks.map(_visibleRowCount).toList(growable: false);
    var remainingHeight = heights.fold<int>(0, (sum, height) => sum + height);
    var remainingColumns = columnCount;

    final columns = <List<DirectoryTreeNode>>[];
    var current = <DirectoryTreeNode>[];
    var currentHeight = 0;

    for (var index = 0; index < blocks.length; index += 1) {
      current.add(blocks[index]);
      currentHeight += heights[index];

      final blocksLeft = blocks.length - index - 1;
      final columnsLeft = remainingColumns - 1;
      final isFullEnough = currentHeight >= remainingHeight / remainingColumns;

      // Closing on "full enough" alone strands a short leading block: a
      // collapsed root in front of an expanded one never reaches its share of
      // the height, so it holds the column open, the tall block joins it, and
      // the whole tree ends up in one column. Once every block that is left is
      // spoken for by a column of its own, close regardless of height.
      final mustClose = blocksLeft == columnsLeft;
      final canClose = blocksLeft > columnsLeft && isFullEnough;

      if (remainingColumns > 1 && (mustClose || canClose)) {
        columns.add(current);
        remainingHeight -= currentHeight;
        remainingColumns -= 1;
        current = <DirectoryTreeNode>[];
        currentHeight = 0;
      }
    }

    columns.add(current);
    return columns;
  }

  /// Rows [node] currently occupies: itself plus whatever is expanded below it.
  int _visibleRowCount(DirectoryTreeNode node) {
    if (!_expandedPaths.contains(node.path)) {
      return 1;
    }
    return node.children.fold<int>(
      1,
      (total, child) => total + _visibleRowCount(child),
    );
  }

  void _appendRows(DirectoryTreeNode node, int depth, List<Widget> rows) {
    rows.add(_buildRow(node, depth));
    if (!_expandedPaths.contains(node.path)) {
      return;
    }
    for (final child in node.children) {
      _appendRows(child, depth + 1, rows);
    }
  }

  Widget _buildRow(DirectoryTreeNode node, int depth) {
    final theme = Theme.of(context);
    final isExpanded = _expandedPaths.contains(node.path);
    final selectionState = _selectionState(node);
    final itemLabel = node.totalMediaCount == 1 ? 'item' : 'items';

    return DirectoryHoverPreview(
      key: ValueKey<String>(node.path),
      directoryPath: node.path,
      child: Semantics(
        label: '${node.name}, ${node.totalMediaCount} matching $itemLabel',
        child: Padding(
          padding: EdgeInsets.only(left: depth * 20.0),
          child: Row(
            children: [
              // One fixed slot either way. Sizing the childless case by eye
              // instead of to the button left those rows 8px adrift of their
              // siblings, which read as ragged indentation.
              SizedBox(
                width: _chevronSlotWidth,
                child: node.hasChildren
                    ? IconButton(
                        icon: Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                        ),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tooltip: isExpanded
                            ? 'Collapse ${node.name}'
                            : 'Expand ${node.name}',
                        onPressed: () => _toggleExpansion(node.path),
                      )
                    : null,
              ),
              Checkbox(
                tristate: true,
                value: selectionState,
                onChanged: (_) => _onCheckboxChanged(node, selectionState),
              ),
              Icon(
                Icons.folder,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Text(
                  '${node.totalMediaCount}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onCheckboxChanged(DirectoryTreeNode node, bool? selectionState) {
    // Checking a folder is also a request to see what is inside it.
    if (selectionState != true && node.hasChildren) {
      setState(() => _expandedPaths.add(node.path));
    }
    widget.onToggle(node.path);
  }

  void _toggleExpansion(String path) {
    setState(() {
      if (!_expandedPaths.remove(path)) {
        _expandedPaths.add(path);
      }
    });
  }

  /// `true` when the whole subtree is selected, `false` when none of it is, and
  /// `null` (indeterminate) in between.
  bool? _selectionState(DirectoryTreeNode node) {
    var total = 0;
    var selected = 0;
    for (final descendant in node.subtree) {
      total += 1;
      if (widget.selectedPaths.contains(descendant.path)) {
        selected += 1;
      }
    }

    if (selected == 0) {
      return false;
    }
    return selected == total ? true : null;
  }
}

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
    final rows = <Widget>[];
    for (final node in widget.nodes) {
      _appendRows(node, 0, rows);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
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
              if (node.hasChildren)
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                  ),
                  iconSize: 20,
                  visualDensity: VisualDensity.compact,
                  tooltip: isExpanded
                      ? 'Collapse ${node.name}'
                      : 'Expand ${node.name}',
                  onPressed: () => _toggleExpansion(node.path),
                )
              else
                const SizedBox(width: 32),
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

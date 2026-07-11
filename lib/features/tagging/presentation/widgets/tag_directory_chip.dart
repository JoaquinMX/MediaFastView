import 'package:flutter/material.dart';

import '../../../media_library/domain/entities/directory_entity.dart';
import 'directory_hover_preview.dart';

class TagDirectoryChip extends StatefulWidget {
  const TagDirectoryChip({
    super.key,
    required this.directory,
    required this.mediaCount,
    required this.onTap,
    this.isSelected = false,
  });

  final DirectoryEntity directory;
  final int mediaCount;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  State<TagDirectoryChip> createState() => _TagDirectoryChipState();
}

class _TagDirectoryChipState extends State<TagDirectoryChip> {
  final GlobalKey<DirectoryHoverPreviewState> _previewKey =
      GlobalKey<DirectoryHoverPreviewState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DirectoryHoverPreview(
      key: _previewKey,
      directoryPath: widget.directory.path,
      child: FilterChip(
        selected: widget.isSelected,
        showCheckmark: false,
        onSelected: (_) {
          _previewKey.currentState?.removeOverlay();
          widget.onTap();
        },
        avatar: Icon(Icons.folder, color: theme.colorScheme.primary),
        label: Text('${widget.directory.name} (${widget.mediaCount})'),
      ),
    );
  }
}

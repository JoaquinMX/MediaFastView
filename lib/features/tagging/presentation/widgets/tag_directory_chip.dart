import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/repository_providers.dart';
import '../../../media_library/domain/entities/directory_entity.dart';

class TagDirectoryChip extends ConsumerStatefulWidget {
  const TagDirectoryChip({
    super.key,
    required this.directory,
    required this.mediaCount,
    required this.onTap,
  });

  final DirectoryEntity directory;
  final int mediaCount;
  final VoidCallback onTap;

  @override
  ConsumerState<TagDirectoryChip> createState() => _TagDirectoryChipState();
}

class _TagDirectoryChipState extends ConsumerState<TagDirectoryChip> {
  OverlayEntry? _overlayEntry;

  static const double _overlayWidth = 240;
  static const double _overlayHeight = 140;
  static const double _overlayPadding = 12;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    _removeOverlay();
    final overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) {
      return;
    }

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenSize = MediaQuery.sizeOf(context);

    var top = offset.dy - _overlayHeight - _overlayPadding;
    if (top < _overlayPadding) {
      top = offset.dy + size.height + _overlayPadding;
    }

    var left = offset.dx;
    if (left + _overlayWidth > screenSize.width - _overlayPadding) {
      left = screenSize.width - _overlayWidth - _overlayPadding;
    }
    if (left < _overlayPadding) {
      left = _overlayPadding;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: left,
          top: top,
          width: _overlayWidth,
          child: IgnorePointer(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).colorScheme.surface,
              child: _DirectoryPreviewStrip(directoryPath: widget.directory.path),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = ActionChip(
      onPressed: () {
        _removeOverlay();
        widget.onTap();
      },
      avatar: Icon(Icons.folder, color: theme.colorScheme.primary),
      label: Text('${widget.directory.name} (${widget.mediaCount})'),
    );

    return MouseRegion(
      onEnter: (_) => _showOverlay(),
      onExit: (_) => _removeOverlay(),
      child: chip,
    );
  }
}

class _DirectoryPreviewStrip extends ConsumerWidget {
  const _DirectoryPreviewStrip({required this.directoryPath});

  final String directoryPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.watch(directoryPreviewStripProvider(directoryPath));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: previewAsync.when(
        data: (paths) {
          if (paths.isEmpty) {
            return _buildMessage(theme, 'No previews available');
          }

          return SizedBox(
            height: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final path in paths)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PreviewThumbnail(path: path),
                  ),
              ],
            ),
          );
        },
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => _buildMessage(theme, 'Preview unavailable'),
      ),
    );
  }

  Widget _buildMessage(ThemeData theme, String message) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          message,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _PreviewThumbnail extends StatelessWidget {
  const _PreviewThumbnail({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: theme.colorScheme.surfaceVariant,
            child: Icon(
              Icons.broken_image,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

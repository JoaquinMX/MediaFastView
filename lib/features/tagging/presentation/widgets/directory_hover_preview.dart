import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/presentation/models/directory_preview.dart';
import '../../../media_library/presentation/providers/directory_cover_controller.dart';
import '../../../media_library/presentation/providers/directory_preview_providers.dart';
import '../../../thumbnails/presentation/file_thumbnail.dart';
import '../../../thumbnails/presentation/media_thumbnail.dart';

/// Shows a floating strip of thumbnails from [directoryPath] while the pointer
/// hovers over [child].
///
/// Pointer-only by design: the overlay is decoration, and every directory it can
/// preview is also reachable through the widget it wraps.
class DirectoryHoverPreview extends StatefulWidget {
  const DirectoryHoverPreview({
    super.key,
    required this.directoryPath,
    required this.child,
  });

  final String directoryPath;
  final Widget child;

  @override
  State<DirectoryHoverPreview> createState() => DirectoryHoverPreviewState();
}

class DirectoryHoverPreviewState extends State<DirectoryHoverPreview> {
  OverlayEntry? _overlayEntry;

  static const double _overlayWidth = 240;
  static const double _overlayHeight = 140;
  static const double _overlayPadding = 12;

  @override
  void dispose() {
    removeOverlay();
    super.dispose();
  }

  void _showOverlay() {
    removeOverlay();

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
              child: _DirectoryPreviewStrip(
                directoryPath: widget.directoryPath,
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Dismisses the preview, if one is showing.
  ///
  /// Public so the wrapped widget can hide the overlay when it is activated —
  /// otherwise it lingers over whatever the tap navigated to.
  void removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showOverlay(),
      onExit: (_) => removeOverlay(),
      child: widget.child,
    );
  }
}

class _DirectoryPreviewStrip extends ConsumerWidget {
  const _DirectoryPreviewStrip({required this.directoryPath});

  final String directoryPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(directoryCoverControllerProvider(directoryPath));
    final previewAsync = ref.watch(
      directoryPreviewStripProvider(directoryPath),
    );
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: previewAsync.when(
        data: (resolution) {
          if (resolution.hasStaleCustomCover) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref
                  .read(
                    directoryCoverControllerProvider(directoryPath).notifier,
                  )
                  .clearStaleCover();
            });
          }
          if (resolution.previews.isEmpty) {
            return _buildMessage(theme, 'No previews available');
          }

          return SizedBox(
            height: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final preview in resolution.previews)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PreviewThumbnail(preview: preview),
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
  const _PreviewThumbnail({required this.preview});

  final DirectoryPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: borderRadius,
      child: AspectRatio(
        aspectRatio: 1,
        child: switch (preview) {
          DirectoryCustomPreview(:final media) => MediaThumbnail(
            media: media,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => _placeholder(theme),
            errorBuilder: (_) => _error(theme),
          ),
          DirectoryImagePreview(:final sourcePath) => FileThumbnail(
            path: sourcePath,
            fit: BoxFit.cover,
            placeholderBuilder: (_) => _placeholder(theme),
            errorBuilder: (_) => _error(theme),
          ),
          DirectoryVideoPreview(:final thumbnailPath) => Image.file(
            File(thumbnailPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _error(theme),
          ),
          DirectoryEmptyPreview() => _error(theme),
        },
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _error(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.broken_image,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

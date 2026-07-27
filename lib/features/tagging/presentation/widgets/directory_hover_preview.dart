import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../media_library/presentation/providers/directory_cover_controller.dart';
import '../../../media_library/presentation/providers/directory_preview_providers.dart';
import '../../../media_library/presentation/widgets/directory_thumbnail.dart';

/// Shows an interactive directory-preview carousel while the pointer is over
/// [child].
///
/// The overlay remains interactive so it can host carousel controls without
/// disappearing as the pointer crosses from its trigger. A short exit grace
/// period bridges the intentional gap between the trigger and the popup.
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
  static const double _overlayWidth = 240;
  static const double _overlayHeight = 140;
  static const double _overlayPadding = 12;
  static const Duration _overlayExitGracePeriod = Duration(milliseconds: 180);

  OverlayEntry? _overlayEntry;
  Timer? _dismissTimer;
  bool _isTriggerHovered = false;
  bool _isOverlayHovered = false;
  bool _isHardwareKeyHandlerRegistered = false;
  final DirectoryPreviewCarouselController _carouselController =
      DirectoryPreviewCarouselController();

  bool get _hasPointerWithin => _isTriggerHovered || _isOverlayHovered;

  bool get _isPointerBrowsing => _hasPointerWithin || _dismissTimer != null;

  @override
  void dispose() {
    removeOverlay();
    super.dispose();
  }

  /// Opens the carousel if it is not already visible.
  void showOverlay() {
    _showOverlay();
  }

  void _showOverlay() {
    _cancelDismissTimer();
    if (_overlayEntry != null) {
      _markOverlayNeedsBuild();
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
          child: MouseRegion(
            onEnter: _onOverlayEnter,
            onExit: _onOverlayExit,
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: _onOverlayKeyEvent,
              child: Material(
                elevation: 8,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                child: SizedBox(
                  height: _overlayHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _DirectoryHoverPreviewCarousel(
                      directoryPath: widget.directoryPath,
                      isPointerHovering: _isPointerBrowsing,
                      controller: _carouselController,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _registerHardwareKeyHandler();
  }

  void _onTriggerEnter(PointerEnterEvent event) {
    _isTriggerHovered = true;
    _cancelDismissTimer();
    _showOverlay();
    _markOverlayNeedsBuild();
  }

  void _onTriggerExit(PointerExitEvent event) {
    _isTriggerHovered = false;
    _markOverlayNeedsBuild();
    _scheduleDismissIfOutside();
  }

  void _onOverlayEnter(PointerEnterEvent event) {
    _isOverlayHovered = true;
    _cancelDismissTimer();
    _markOverlayNeedsBuild();
  }

  void _onOverlayExit(PointerExitEvent event) {
    _isOverlayHovered = false;
    _markOverlayNeedsBuild();
    _scheduleDismissIfOutside();
  }

  void _scheduleDismissIfOutside() {
    if (_hasPointerWithin || _overlayEntry == null) {
      return;
    }
    _cancelDismissTimer();
    _dismissTimer = Timer(_overlayExitGracePeriod, () {
      _dismissTimer = null;
      if (!mounted || _hasPointerWithin) {
        return;
      }
      removeOverlay();
    });
  }

  void _cancelDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
  }

  void _markOverlayNeedsBuild() {
    _overlayEntry?.markNeedsBuild();
  }

  void _onTriggerPointerDown(PointerDownEvent event) {
    removeOverlay();
  }

  KeyEventResult _onTriggerKeyEvent(FocusNode node, KeyEvent event) {
    return _handleKeyEvent(event);
  }

  KeyEventResult _onOverlayKeyEvent(FocusNode node, KeyEvent event) {
    return _handleKeyEvent(event);
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final carouselResult = _carouselController.handleKeyEvent(event);
    if (carouselResult == KeyEventResult.handled) {
      return carouselResult;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      removeOverlay();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      removeOverlay();
    }
    return KeyEventResult.ignored;
  }

  bool _onHardwareKeyEvent(KeyEvent event) {
    if (_overlayEntry == null ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    removeOverlay();
    return true;
  }

  void _registerHardwareKeyHandler() {
    if (_isHardwareKeyHandlerRegistered) {
      return;
    }
    HardwareKeyboard.instance.addHandler(_onHardwareKeyEvent);
    _isHardwareKeyHandlerRegistered = true;
  }

  void _removeHardwareKeyHandler() {
    if (!_isHardwareKeyHandlerRegistered) {
      return;
    }
    HardwareKeyboard.instance.removeHandler(_onHardwareKeyEvent);
    _isHardwareKeyHandlerRegistered = false;
  }

  /// Dismisses the preview, if one is showing.
  ///
  /// Public so wrapped controls can dismiss the popup before their activation
  /// changes the surrounding view.
  void removeOverlay() {
    _cancelDismissTimer();
    _removeHardwareKeyHandler();
    _isTriggerHovered = false;
    _isOverlayHovered = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      onKeyEvent: _onTriggerKeyEvent,
      child: Listener(
        onPointerDown: _onTriggerPointerDown,
        behavior: HitTestBehavior.translucent,
        child: MouseRegion(
          onEnter: _onTriggerEnter,
          onExit: _onTriggerExit,
          child: widget.child,
        ),
      ),
    );
  }
}

class _DirectoryHoverPreviewCarousel extends ConsumerStatefulWidget {
  const _DirectoryHoverPreviewCarousel({
    required this.directoryPath,
    required this.isPointerHovering,
    required this.controller,
  });

  final String directoryPath;
  final bool isPointerHovering;
  final DirectoryPreviewCarouselController controller;

  @override
  ConsumerState<_DirectoryHoverPreviewCarousel> createState() =>
      _DirectoryHoverPreviewCarouselState();
}

class _DirectoryHoverPreviewCarouselState
    extends ConsumerState<_DirectoryHoverPreviewCarousel> {
  bool _cleanupScheduled = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(directoryCoverControllerProvider(widget.directoryPath));
    final catalog = ref.watch(
      directoryPreviewCatalogProvider(
        DirectoryPreviewCatalogQuery(directoryPath: widget.directoryPath),
      ),
    );
    final theme = Theme.of(context);

    return catalog.when(
      data: (value) {
        _scheduleStaleCleanup(value.missingCustomCoverFileNames);
        return DirectoryPreviewCarousel(
          catalog: value,
          fit: BoxFit.cover,
          isPointerHovering: widget.isPointerHovering,
          controller: widget.controller,
          placeholderBuilder: (_) => _placeholder(theme),
          emptyBuilder: (_) => _message(theme, 'No previews available'),
          errorBuilder: (_) => _error(theme),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _message(theme, 'Preview unavailable'),
    );
  }

  void _scheduleStaleCleanup(List<String> missingSourceFileNames) {
    if (missingSourceFileNames.isEmpty) {
      _cleanupScheduled = false;
      return;
    }
    if (_cleanupScheduled) {
      return;
    }
    _cleanupScheduled = true;
    final missingNames = List<String>.of(missingSourceFileNames);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(directoryCoverControllerProvider(widget.directoryPath).notifier)
          .reconcileMissingSelections(missingNames);
    });
  }

  Widget _placeholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _error(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _message(ThemeData theme, String message) {
    return Center(
      child: Text(
        message,
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

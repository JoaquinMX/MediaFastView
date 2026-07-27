import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../../thumbnails/presentation/file_thumbnail.dart';
import '../../../thumbnails/presentation/media_thumbnail.dart';
import '../models/directory_preview.dart';
import '../providers/directory_cover_controller.dart';
import '../providers/directory_preview_providers.dart';

/// Renders a custom directory cover or an automatic collage of direct children.
class DirectoryThumbnail extends ConsumerStatefulWidget {
  const DirectoryThumbnail({
    super.key,
    required this.directoryPath,
    required this.placeholderBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    this.bookmarkData,
    this.fit = BoxFit.cover,
    this.isPointerHovering = false,
    this.isFocused = false,
    this.controller,
  });

  final String directoryPath;
  final String? bookmarkData;
  final BoxFit fit;

  /// Whether the containing directory surface is currently pointer-hovered.
  ///
  /// The carousel deliberately waits for a short dwell before replacing an
  /// automatic collage, so brief pointer passes do not cause visual churn.
  final bool isPointerHovering;

  /// Whether the containing directory surface has keyboard focus.
  ///
  /// Focus opens the first single preview immediately, but does not enable
  /// timed advancement because that is reserved for an active pointer hover.
  final bool isFocused;

  /// Lets a containing focus surface route keyboard navigation to its carousel.
  final DirectoryPreviewCarouselController? controller;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder emptyBuilder;
  final WidgetBuilder errorBuilder;

  @override
  ConsumerState<DirectoryThumbnail> createState() => _DirectoryThumbnailState();
}

class _DirectoryThumbnailState extends ConsumerState<DirectoryThumbnail> {
  bool _cleanupScheduled = false;

  @override
  Widget build(BuildContext context) {
    ref.watch(directoryCoverControllerProvider(widget.directoryPath));
    final catalog = ref.watch(
      directoryPreviewCatalogProvider(
        DirectoryPreviewCatalogQuery(
          directoryPath: widget.directoryPath,
          bookmarkData: widget.bookmarkData,
        ),
      ),
    );
    return catalog.when(
      data: (value) {
        _scheduleStaleCleanup(value.missingCustomCoverFileNames);
        return _buildCatalog(value);
      },
      loading: () => widget.placeholderBuilder(context),
      error: (_, __) => widget.errorBuilder(context),
    );
  }

  Widget _buildCatalog(DirectoryPreviewCatalog catalog) {
    return DirectoryPreviewCarousel(
      catalog: catalog,
      fit: widget.fit,
      isPointerHovering: widget.isPointerHovering,
      isFocused: widget.isFocused,
      controller: widget.controller,
      placeholderBuilder: widget.placeholderBuilder,
      emptyBuilder: widget.emptyBuilder,
      errorBuilder: widget.errorBuilder,
      fallbackBookmarkData: widget.bookmarkData,
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
}

/// Routes external navigation requests to a mounted directory carousel.
///
/// Directory cards deliberately keep their own focusable information areas so
/// activating a folder remains separate from browsing its preview. This small
/// controller lets those focus areas forward Left and Right without exposing a
/// state object or letting the key activate the underlying card, checkbox, or
/// chip.
class DirectoryPreviewCarouselController {
  bool Function()? _showFirstPreview;
  bool Function()? _showPreviousPreview;
  bool Function()? _showNextPreview;

  /// Opens the first single preview, if the carousel has content.
  bool showFirstPreview() => _showFirstPreview?.call() ?? false;

  /// Moves one preview backward without wrapping.
  bool showPreviousPreview() => _showPreviousPreview?.call() ?? false;

  /// Moves one preview forward without wrapping.
  bool showNextPreview() => _showNextPreview?.call() ?? false;

  /// Handles a directional keyboard event and reports whether it was consumed.
  KeyEventResult handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    return switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft =>
        showPreviousPreview() ? KeyEventResult.handled : KeyEventResult.ignored,
      LogicalKeyboardKey.arrowRight =>
        showNextPreview() ? KeyEventResult.handled : KeyEventResult.ignored,
      _ => KeyEventResult.ignored,
    };
  }

  void _attach({
    required bool Function() showFirstPreview,
    required bool Function() showPreviousPreview,
    required bool Function() showNextPreview,
  }) {
    _showFirstPreview = showFirstPreview;
    _showPreviousPreview = showPreviousPreview;
    _showNextPreview = showNextPreview;
  }

  void _detach() {
    _showFirstPreview = null;
    _showPreviousPreview = null;
    _showNextPreview = null;
  }
}

/// Displays a directory's collage at rest and a timed single-preview browser.
///
/// The component intentionally works from a resolved [DirectoryPreviewCatalog]
/// rather than resolving files itself. Cards and hover overlays therefore share
/// ordering, cache, and custom-cover behavior while keeping the visual state
/// local to the surface that is being browsed.
class DirectoryPreviewCarousel extends StatefulWidget {
  const DirectoryPreviewCarousel({
    super.key,
    required this.catalog,
    required this.fit,
    required this.placeholderBuilder,
    required this.emptyBuilder,
    required this.errorBuilder,
    this.fallbackBookmarkData,
    this.isPointerHovering = false,
    this.isFocused = false,
    this.controller,
    this.hoverDwell = const Duration(milliseconds: 250),
    this.autoAdvanceInterval = const Duration(milliseconds: 2500),
    this.transitionDuration = const Duration(milliseconds: 180),
  });

  /// Stable key for tests and visual instrumentation.
  static const Key carouselKey = Key('directory-preview-carousel');

  /// Stable key for the interactive preview hit target.
  static const Key interactionKey = Key(
    'directory-preview-carousel-interaction',
  );

  /// Stable key for the resting collage or custom-cover surface.
  static const Key restingContentKey = Key(
    'directory-preview-carousel-resting-content',
  );

  /// Produces the key of a currently visible single preview.
  static Key previewKey(int index) =>
      Key('directory-preview-carousel-preview-$index');

  /// Stable key for the accessible previous-preview control.
  static const Key previousButtonKey = Key(
    'directory-preview-carousel-previous-button',
  );

  /// Stable key for the accessible next-preview control.
  static const Key nextButtonKey = Key(
    'directory-preview-carousel-next-button',
  );

  /// Stable key for the visible preview position indicator.
  static const Key counterKey = Key('directory-preview-carousel-counter');

  /// Stable key for the visible preview filename.
  static const Key filenameKey = Key('directory-preview-carousel-filename');

  /// Stable key for the semantic filename and position announcement.
  static const Key previewSemanticsKey = Key(
    'directory-preview-carousel-preview-semantics',
  );

  /// Stable key for the iOS finger-following preview strip.
  static const Key scrubStripKey = Key(
    'directory-preview-carousel-scrub-strip',
  );

  /// Stable key for the leading preview positioned in the iOS scrub strip.
  static const Key scrubLeadingPreviewKey = Key(
    'directory-preview-carousel-scrub-leading-preview',
  );

  /// Stable key for the trailing preview positioned in the iOS scrub strip.
  static const Key scrubTrailingPreviewKey = Key(
    'directory-preview-carousel-scrub-trailing-preview',
  );

  /// VoiceOver action that moves to the previous bounded preview.
  static const CustomSemanticsAction previousSemanticsAction =
      CustomSemanticsAction(label: 'Previous preview');

  /// VoiceOver action that moves to the next bounded preview.
  static const CustomSemanticsAction nextSemanticsAction =
      CustomSemanticsAction(label: 'Next preview');

  /// Maps a local horizontal touch position to a fractional preview position.
  @visibleForTesting
  static double previewPositionForLocalDx({
    required double localDx,
    required double width,
    required int previewCount,
  }) {
    if (previewCount <= 1 || width <= 0) {
      return 0;
    }
    final edgeInset = (width * 0.1).clamp(0.0, 12.0);
    final usableWidth = width - (edgeInset * 2);
    if (usableWidth <= 0) {
      return localDx < width / 2 ? 0 : (previewCount - 1).toDouble();
    }
    final normalizedPosition = ((localDx - edgeInset) / usableWidth).clamp(
      0.0,
      1.0,
    );
    return normalizedPosition * (previewCount - 1);
  }

  final DirectoryPreviewCatalog catalog;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder emptyBuilder;
  final WidgetBuilder errorBuilder;
  final String? fallbackBookmarkData;
  final bool isPointerHovering;
  final bool isFocused;
  final DirectoryPreviewCarouselController? controller;

  /// Time the pointer must remain over the surface before browsing starts.
  final Duration hoverDwell;

  /// Delay between automatic preview changes while the pointer remains over it.
  final Duration autoAdvanceInterval;

  /// Cross-fade duration between single previews.
  final Duration transitionDuration;

  @override
  State<DirectoryPreviewCarousel> createState() =>
      _DirectoryPreviewCarouselState();
}

class _DirectoryPreviewCarouselState extends State<DirectoryPreviewCarousel>
    with SingleTickerProviderStateMixin {
  Timer? _hoverDwellTimer;
  Timer? _autoAdvanceTimer;
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  bool _isDisposed = false;
  bool _isPointerBrowsing = false;
  bool _hasInteractiveFocus = false;
  bool _isManuallyBrowsing = false;
  int? _activeScrubPointer;
  double? _scrubPosition;
  int _currentIndex = 0;

  bool get _isBrowsing =>
      _isPointerBrowsing ||
      widget.isFocused ||
      _hasInteractiveFocus ||
      _isManuallyBrowsing;

  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  bool get _hasMultiplePreviews => widget.catalog.previews.length > 1;

  bool get _shouldShowBrowsingOverlay =>
      _isBrowsing &&
      !widget.catalog.isEmpty &&
      (_isIos || _hasMultiplePreviews);

  bool get _canShowPrevious => _currentIndex > 0;

  bool get _canShowNext => _currentIndex < widget.catalog.previews.length - 1;

  bool get _reduceAnimations =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  bool get _canAutoAdvance =>
      _isPointerBrowsing &&
      widget.isPointerHovering &&
      !_reduceAnimations &&
      widget.catalog.previews.length > 1;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      duration: widget.transitionDuration,
      vsync: this,
    )..addListener(_updateSnapPosition);
    _attachController();
    if (widget.isPointerHovering) {
      _startHoverDwell();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAutoAdvance();
  }

  @override
  void didUpdateWidget(covariant DirectoryPreviewCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      _attachController();
    }

    if (!oldWidget.isPointerHovering && widget.isPointerHovering) {
      _startHoverDwell();
    } else if (oldWidget.isPointerHovering && !widget.isPointerHovering) {
      _cancelHoverDwell();
      _isPointerBrowsing = false;
    }

    if (!_samePreviews(oldWidget.catalog.previews, widget.catalog.previews) ||
        _currentIndex >= widget.catalog.previews.length) {
      _snapController.stop();
      _activeScrubPointer = null;
      _scrubPosition = null;
      _currentIndex = 0;
    }

    final didGainExternalFocus = !oldWidget.isFocused && widget.isFocused;
    if (didGainExternalFocus && !_isPointerBrowsing && !_isManuallyBrowsing) {
      _currentIndex = 0;
    }

    if (!widget.isPointerHovering &&
        !widget.isFocused &&
        !_hasInteractiveFocus) {
      _resetToRest();
    } else {
      // A focus transition can temporarily make [_isBrowsing] true before
      // pointer browsing has started. Do not let a focus loss strand a still
      // hovered surface on its collage: retain an existing dwell, or arm one
      // again when the focus change consumed it.
      _ensureHoverDwell();
    }

    if (oldWidget.autoAdvanceInterval != widget.autoAdvanceInterval) {
      _stopAutoAdvance();
    }
    if (oldWidget.transitionDuration != widget.transitionDuration) {
      _snapController.duration = widget.transitionDuration;
    }
    _syncAutoAdvance();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _activeScrubPointer = null;
    _snapController.removeListener(_updateSnapPosition);
    _cancelHoverDwell();
    _stopAutoAdvance();
    widget.controller?._detach();
    _snapController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _attachController() {
    widget.controller?._attach(
      showFirstPreview: _showFirstPreview,
      showPreviousPreview: _showPreviousPreview,
      showNextPreview: _showNextPreview,
    );
  }

  void _startHoverDwell() {
    _cancelHoverDwell();
    _hoverDwellTimer = Timer(widget.hoverDwell, () {
      _hoverDwellTimer = null;
      if (!mounted || !widget.isPointerHovering) {
        return;
      }
      setState(() {
        _isPointerBrowsing = true;
        _currentIndex = 0;
      });
      _syncAutoAdvance();
    });
  }

  void _ensureHoverDwell() {
    if (!widget.isPointerHovering ||
        _isPointerBrowsing ||
        _hoverDwellTimer != null) {
      return;
    }
    _startHoverDwell();
  }

  void _cancelHoverDwell() {
    _hoverDwellTimer?.cancel();
    _hoverDwellTimer = null;
  }

  void _syncAutoAdvance() {
    if (_canAutoAdvance) {
      _autoAdvanceTimer ??= Timer.periodic(
        widget.autoAdvanceInterval,
        (_) => _advanceAutomatically(),
      );
      return;
    }
    _stopAutoAdvance();
  }

  void _stopAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _advanceAutomatically() {
    if (!mounted || _isDisposed) {
      return;
    }
    if (!_canAutoAdvance) {
      _syncAutoAdvance();
      return;
    }
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.catalog.previews.length;
    });
  }

  void _resetToRest() {
    _cancelHoverDwell();
    _stopAutoAdvance();
    _snapController.stop();
    _activeScrubPointer = null;
    _scrubPosition = null;
    _isPointerBrowsing = false;
    _isManuallyBrowsing = false;
    _currentIndex = 0;
  }

  bool _showFirstPreview() {
    if (widget.catalog.isEmpty) {
      return false;
    }
    _beginManualBrowsing(index: 0);
    return true;
  }

  bool _showPreviousPreview() {
    return _navigateBy(-1);
  }

  bool _showNextPreview() {
    return _navigateBy(1);
  }

  bool _navigateBy(int direction) {
    if (widget.catalog.isEmpty) {
      return false;
    }

    final targetIndex = (_currentIndex + direction)
        .clamp(0, widget.catalog.previews.length - 1)
        .toInt();
    _beginManualBrowsing(index: targetIndex);
    return true;
  }

  void _beginManualBrowsing({required int index}) {
    if (!mounted || _isDisposed) {
      return;
    }
    if (_isIos) {
      _snapController.stop();
    }
    final changed =
        !_isManuallyBrowsing || _currentIndex != index || !_isBrowsing;
    if (changed) {
      setState(() {
        _isManuallyBrowsing = true;
        _currentIndex = index;
        if (_isIos && !_reduceAnimations) {
          _scrubPosition = index.toDouble();
        }
      });
    }
    // A manual key, click, or swipe gives the user a full interval to inspect
    // the chosen frame before pointer-only auto-advance resumes.
    _restartAutoAdvance();
  }

  void _restartAutoAdvance() {
    _stopAutoAdvance();
    _syncAutoAdvance();
  }

  void _onFocusChange(bool hasFocus) {
    if (!mounted || _isDisposed || _hasInteractiveFocus == hasFocus) {
      return;
    }
    setState(() {
      _hasInteractiveFocus = hasFocus;
      if (!hasFocus && !widget.isPointerHovering && !widget.isFocused) {
        _isManuallyBrowsing = false;
        _currentIndex = 0;
      }
    });

    if (!hasFocus && !widget.isPointerHovering && !widget.isFocused) {
      _resetToRest();
      return;
    }
    _ensureHoverDwell();
    _syncAutoAdvance();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller?.handleKeyEvent(event) ??
        _handleLocalKeyEvent(event);
  }

  KeyEventResult _handleLocalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    return switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft =>
        _showPreviousPreview()
            ? KeyEventResult.handled
            : KeyEventResult.ignored,
      LogicalKeyboardKey.arrowRight =>
        _showNextPreview() ? KeyEventResult.handled : KeyEventResult.ignored,
      _ => KeyEventResult.ignored,
    };
  }

  void _onIosPointerDown(PointerDownEvent event, double width) {
    if (!mounted ||
        _isDisposed ||
        !_isIos ||
        _activeScrubPointer != null ||
        widget.catalog.isEmpty) {
      return;
    }
    _snapController.stop();
    _activeScrubPointer = event.pointer;
    _focusNode.requestFocus();
    _updateIosScrubPosition(event.localPosition.dx, width);
  }

  void _onIosPointerMove(PointerMoveEvent event, double width) {
    if (!mounted ||
        _isDisposed ||
        !_isIos ||
        _activeScrubPointer != event.pointer) {
      return;
    }
    _updateIosScrubPosition(event.localPosition.dx, width);
  }

  void _onIosPointerUp(PointerEvent event) {
    if (!mounted ||
        _isDisposed ||
        !_isIos ||
        _activeScrubPointer != event.pointer) {
      return;
    }
    _activeScrubPointer = null;
    _snapIosScrubPosition();
  }

  void _updateIosScrubPosition(double localDx, double width) {
    if (!mounted || _isDisposed || widget.catalog.isEmpty) {
      return;
    }
    final position = DirectoryPreviewCarousel.previewPositionForLocalDx(
      localDx: localDx,
      width: width,
      previewCount: widget.catalog.previews.length,
    );
    final selectedIndex = position
        .round()
        .clamp(0, widget.catalog.previews.length - 1)
        .toInt();
    setState(() {
      _isManuallyBrowsing = true;
      _currentIndex = selectedIndex;
      _scrubPosition = _reduceAnimations ? selectedIndex.toDouble() : position;
    });
  }

  void _snapIosScrubPosition() {
    if (!mounted || _isDisposed) {
      return;
    }
    final position = _scrubPosition;
    if (position == null || widget.catalog.isEmpty) {
      return;
    }
    final targetIndex = position
        .round()
        .clamp(0, widget.catalog.previews.length - 1)
        .toInt();
    _currentIndex = targetIndex;
    if (_reduceAnimations || position == targetIndex.toDouble()) {
      setState(() => _scrubPosition = targetIndex.toDouble());
      return;
    }
    _snapAnimation = Tween<double>(
      begin: position,
      end: targetIndex.toDouble(),
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    _snapController.forward(from: 0);
  }

  void _updateSnapPosition() {
    final animation = _snapAnimation;
    if (!mounted || _isDisposed || animation == null) {
      return;
    }
    setState(() => _scrubPosition = animation.value);
  }

  bool _samePreviews(
    List<DirectoryPreview> first,
    List<DirectoryPreview> second,
  ) {
    if (identical(first, second)) {
      return true;
    }
    if (first.length != second.length) {
      return false;
    }
    for (var index = 0; index < first.length; index += 1) {
      final firstPreview = first[index];
      final secondPreview = second[index];
      if (firstPreview.runtimeType != secondPreview.runtimeType ||
          firstPreview.sourcePath != secondPreview.sourcePath) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final duration = _reduceAnimations
        ? Duration.zero
        : widget.transitionDuration;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: _onFocusChange,
      onKeyEvent: _onKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            key: DirectoryPreviewCarousel.interactionKey,
            behavior: HitTestBehavior.opaque,
            // Leave a tap to the containing directory card. The preview
            // still starts browsing on pointer-down, while a horizontal drag
            // is claimed by this child and therefore cannot activate the card.
            onTap: null,
            onLongPress: _isIos ? () {} : null,
            onHorizontalDragStart: _isIos ? (_) {} : null,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _isIos
                  ? (event) => _onIosPointerDown(event, width)
                  : null,
              onPointerMove: _isIos
                  ? (event) => _onIosPointerMove(event, width)
                  : null,
              onPointerUp: _isIos ? _onIosPointerUp : null,
              onPointerCancel: _isIos ? _onIosPointerUp : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    key: DirectoryPreviewCarousel.carouselKey,
                    duration: duration,
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: _isBrowsing
                        ? _buildBrowsingPreview()
                        : _buildRestingContent(),
                  ),
                  if (_shouldShowBrowsingOverlay) _buildNavigationOverlay(),
                  if (_isIos && !_isBrowsing && !widget.catalog.isEmpty)
                    _buildPreviewSemantics(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIosScrubStrip() {
    final previewCount = widget.catalog.previews.length;
    final position = (_scrubPosition ?? _currentIndex.toDouble()).clamp(
      0.0,
      (previewCount - 1).toDouble(),
    );
    final leadingIndex = position.floor();
    final trailingIndex = position.ceil();
    final fractionalOffset = position - leadingIndex;

    return KeyedSubtree(
      key: DirectoryPreviewCarousel.scrubStripKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  key: DirectoryPreviewCarousel.scrubLeadingPreviewKey,
                  left: -fractionalOffset * width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: _buildPreviewTile(leadingIndex),
                ),
                if (trailingIndex != leadingIndex)
                  Positioned(
                    key: DirectoryPreviewCarousel.scrubTrailingPreviewKey,
                    left: (1 - fractionalOffset) * width,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: _buildPreviewTile(trailingIndex),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewTile(int index) {
    return KeyedSubtree(
      key: DirectoryPreviewCarousel.previewKey(index),
      child: DirectoryPreviewTile(
        preview: widget.catalog.previews[index],
        fit: widget.fit,
        placeholderBuilder: widget.placeholderBuilder,
        errorBuilder: widget.errorBuilder,
        fallbackBookmarkData: widget.fallbackBookmarkData,
      ),
    );
  }

  Map<CustomSemanticsAction, VoidCallback> _previewSemanticsActions() {
    return <CustomSemanticsAction, VoidCallback>{
      if (_canShowPrevious)
        DirectoryPreviewCarousel.previousSemanticsAction: _showPreviousPreview,
      if (_canShowNext)
        DirectoryPreviewCarousel.nextSemanticsAction: _showNextPreview,
    };
  }

  Widget _buildPreviewSemantics() {
    final preview = widget.catalog.previews[_currentIndex];
    final previewName = path.basename(preview.sourcePath);
    return Semantics(
      key: DirectoryPreviewCarousel.previewSemanticsKey,
      label:
          '$previewName, preview ${_currentIndex + 1} of '
          '${widget.catalog.previews.length}',
      customSemanticsActions: _previewSemanticsActions(),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildNavigationOverlay() {
    final preview = widget.catalog.previews[_currentIndex];
    final previewName = path.basename(preview.sourcePath);
    final theme = Theme.of(context);
    final overlayColor = theme.colorScheme.scrim.withValues(alpha: 0.68);
    final foregroundColor = theme.colorScheme.onPrimary;

    return Stack(
      children: [
        if (!_isIos)
          Align(
            alignment: Alignment.centerLeft,
            child: _NavigationButton(
              key: DirectoryPreviewCarousel.previousButtonKey,
              icon: Icons.chevron_left,
              tooltip: 'Previous preview',
              isEnabled: _canShowPrevious,
              onPressed: _showPreviousPreview,
            ),
          ),
        if (!_isIos)
          Align(
            alignment: Alignment.centerRight,
            child: _NavigationButton(
              key: DirectoryPreviewCarousel.nextButtonKey,
              icon: Icons.chevron_right,
              tooltip: 'Next preview',
              isEnabled: _canShowNext,
              onPressed: _showNextPreview,
            ),
          ),
        Positioned(
          left: 6,
          right: 6,
          bottom: 6,
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: overlayColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        previewName,
                        key: DirectoryPreviewCarousel.filenameKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: foregroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_currentIndex + 1} / ${widget.catalog.previews.length}',
                      key: DirectoryPreviewCarousel.counterKey,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isIos)
          _buildPreviewSemantics()
        else
          Semantics(
            key: DirectoryPreviewCarousel.previewSemanticsKey,
            label:
                '$previewName, preview ${_currentIndex + 1} of '
                '${widget.catalog.previews.length}',
            child: const SizedBox.expand(),
          ),
      ],
    );
  }

  Widget _buildRestingContent() {
    if (widget.catalog.isEmpty) {
      return KeyedSubtree(
        key: DirectoryPreviewCarousel.restingContentKey,
        child: widget.emptyBuilder(context),
      );
    }

    if (widget.catalog.hasCustomCover) {
      return KeyedSubtree(
        key: DirectoryPreviewCarousel.restingContentKey,
        child: DirectoryPreviewCollage(
          previews: widget.catalog.customPreviews,
          fit: widget.fit,
          fallbackBookmarkData: widget.fallbackBookmarkData,
        ),
      );
    }

    return KeyedSubtree(
      key: DirectoryPreviewCarousel.restingContentKey,
      child: DirectoryPreviewCollage(
        previews: widget.catalog.automaticPreviews
            .take(4)
            .toList(growable: false),
        fit: widget.fit,
        fallbackBookmarkData: widget.fallbackBookmarkData,
      ),
    );
  }

  Widget _buildBrowsingPreview() {
    if (widget.catalog.isEmpty) {
      return KeyedSubtree(
        key: DirectoryPreviewCarousel.restingContentKey,
        child: widget.emptyBuilder(context),
      );
    }

    if (_isIos && !_reduceAnimations) {
      return _buildIosScrubStrip();
    }
    return _buildPreviewTile(_currentIndex);
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.isEnabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: isEnabled,
      label: tooltip,
      child: Material(
        color: colorScheme.scrim.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon),
          iconSize: 22,
          color: colorScheme.onPrimary,
          disabledColor: colorScheme.onPrimary.withValues(alpha: 0.4),
          tooltip: tooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          visualDensity: VisualDensity.compact,
          onPressed: isEnabled ? onPressed : null,
        ),
      ),
    );
  }
}

/// Displays up to four automatic previews without creating a composite image.
///
/// A single preview fills the card. Two divide it evenly, three reserve a
/// larger left tile, and four form quadrants. Each cell owns its failure state
/// so one damaged image never replaces a healthy directory collage.
class DirectoryPreviewCollage extends StatelessWidget {
  const DirectoryPreviewCollage({
    super.key,
    required this.previews,
    required this.fit,
    this.fallbackBookmarkData,
  });

  static const Key collageKey = Key('directory-preview-collage');
  static const double _gutter = 2;

  final List<DirectoryPreview> previews;
  final BoxFit fit;
  final String? fallbackBookmarkData;

  @override
  Widget build(BuildContext context) {
    final visiblePreviews = previews.take(4).toList(growable: false);
    final theme = Theme.of(context);
    if (visiblePreviews.isEmpty) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      key: collageKey,
      color: theme.colorScheme.surface,
      child: switch (visiblePreviews.length) {
        1 => _tile(context, visiblePreviews[0], 0),
        2 => Row(
          children: [
            Expanded(child: _tile(context, visiblePreviews[0], 0)),
            const SizedBox(width: _gutter),
            Expanded(child: _tile(context, visiblePreviews[1], 1)),
          ],
        ),
        3 => Row(
          children: [
            Expanded(flex: 2, child: _tile(context, visiblePreviews[0], 0)),
            const SizedBox(width: _gutter),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _tile(context, visiblePreviews[1], 1)),
                  const SizedBox(height: _gutter),
                  Expanded(child: _tile(context, visiblePreviews[2], 2)),
                ],
              ),
            ),
          ],
        ),
        _ => Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, visiblePreviews[0], 0)),
                  const SizedBox(width: _gutter),
                  Expanded(child: _tile(context, visiblePreviews[1], 1)),
                ],
              ),
            ),
            const SizedBox(height: _gutter),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _tile(context, visiblePreviews[2], 2)),
                  const SizedBox(width: _gutter),
                  Expanded(child: _tile(context, visiblePreviews[3], 3)),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }

  Widget _tile(BuildContext context, DirectoryPreview preview, int index) {
    return SizedBox.expand(
      key: Key('directory-preview-collage-tile-$index'),
      child: DirectoryPreviewTile(
        preview: preview,
        fit: fit,
        placeholderBuilder: (_) => _placeholder(context),
        errorBuilder: (_) => _failure(context, index),
        fallbackBookmarkData: fallbackBookmarkData,
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _failure(BuildContext context, int index) {
    return ColoredBox(
      key: Key('directory-preview-collage-failure-$index'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Renders one preview source using the existing lazy thumbnail pipeline.
class DirectoryPreviewTile extends StatelessWidget {
  const DirectoryPreviewTile({
    super.key,
    required this.preview,
    required this.fit,
    required this.placeholderBuilder,
    required this.errorBuilder,
    this.fallbackBookmarkData,
  });

  final DirectoryPreview preview;
  final BoxFit fit;
  final WidgetBuilder placeholderBuilder;
  final WidgetBuilder errorBuilder;
  final String? fallbackBookmarkData;

  @override
  Widget build(BuildContext context) {
    final bookmarkData = preview.bookmarkData ?? fallbackBookmarkData;
    return switch (preview) {
      DirectoryCustomPreview(:final media) => MediaThumbnail(
        media: media,
        bookmarkData: bookmarkData,
        fit: fit,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      ),
      DirectoryImagePreview(:final sourcePath) => FileThumbnail(
        path: sourcePath,
        bookmarkData: bookmarkData,
        fit: fit,
        placeholderBuilder: placeholderBuilder,
        errorBuilder: errorBuilder,
      ),
      DirectoryVideoPreview(:final thumbnailPath) => Image.file(
        File(thumbnailPath),
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => errorBuilder(context),
      ),
      DirectoryEmptyPreview() => errorBuilder(context),
    };
  }
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/ui_constants.dart';
import '../../../profiles/presentation/widgets/directory_profile_dialog.dart';
import '../../domain/entities/directory_entity.dart';
import 'directory_cover_picker_dialog.dart';
import 'directory_tag_assignment_dialog.dart';
import 'directory_thumbnail.dart';

/// Grid item widget for displaying a directory with hover effects.
class DirectoryGridItem extends StatefulWidget {
  const DirectoryGridItem({
    super.key,
    required this.directory,
    required this.onTap,
    required this.onDelete,
    required this.onAssignTags,
    required this.onSelectionToggle,
    required this.isSelected,
    required this.isSelectionMode,
    required this.showTaggedMediaCounts,
  });

  final DirectoryEntity directory;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final Future<void> Function(List<String>) onAssignTags;
  final VoidCallback onSelectionToggle;
  final bool isSelected;
  final bool isSelectionMode;
  final bool showTaggedMediaCounts;

  @override
  State<DirectoryGridItem> createState() => _DirectoryGridItemState();
}

class _DirectoryGridItemState extends State<DirectoryGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isPointerHovering = false;
  bool _hasKeyboardFocus = false;
  final DirectoryPreviewCarouselController _carouselController =
      DirectoryPreviewCarouselController();

  void _ensureSelected() {
    if (!widget.isSelected) {
      widget.onSelectionToggle();
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: UiAnimations.standard,
      vsync: this,
    );

    _scaleAnimation =
        Tween<double>(
          begin: UiAnimations.scaleNormal,
          end: UiAnimations.scaleHover,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _elevationAnimation =
        Tween<double>(
          begin: UiAnimations.elevationNormal,
          end: UiAnimations.elevationHover,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onHover(bool isHovering) {
    if (_isPointerHovering != isHovering) {
      setState(() => _isPointerHovering = isHovering);
    }
    if (isHovering) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onFocusChange(bool hasFocus) {
    if (_hasKeyboardFocus != hasFocus) {
      setState(() => _hasKeyboardFocus = hasFocus);
    }
  }

  KeyEventResult _onPreviewKeyEvent(FocusNode node, KeyEvent event) {
    return _carouselController.handleKeyEvent(event);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive padding: smaller on small heights
        final double paddingValue =
            constraints.maxHeight < UiSizing.responsiveHeightThreshold
            ? UiSpacing.extraSmallGap
            : UiSpacing.verticalGap;
        final double iconSize =
            constraints.maxHeight < UiSizing.responsiveHeightThreshold
            ? UiSizing.iconExtraSmall
            : UiSizing.iconSmall;

        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final theme = Theme.of(context);
            final selectionHighlightColor = theme.colorScheme.primary;
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Listener(
                onPointerDown: (event) {
                  if (event.kind == PointerDeviceKind.mouse &&
                      event.buttons == kSecondaryMouseButton) {
                    _ensureSelected();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Card(
                  elevation: _elevationAnimation.value,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      UiSizing.borderRadiusMedium,
                    ),
                    side: widget.isSelected
                        ? BorderSide(
                            color: selectionHighlightColor,
                            width: UiSizing.borderWidth,
                          )
                        : BorderSide.none,
                  ),
                  child: Focus(
                    onFocusChange: _onFocusChange,
                    onKeyEvent: _onPreviewKeyEvent,
                    child: InkWell(
                      onTap: widget.onTap,
                      onLongPress: () {
                        _ensureSelected();
                      },
                      onHover: _onHover,
                      onFocusChange: _onFocusChange,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Thumbnail area
                              Expanded(
                                flex: UiGrid.thumbnailFlex,
                                child: Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: DirectoryThumbnail(
                                    directoryPath: widget.directory.path,
                                    bookmarkData: widget.directory.bookmarkData,
                                    isPointerHovering: _isPointerHovering,
                                    isFocused: _hasKeyboardFocus,
                                    controller: _carouselController,
                                    placeholderBuilder: (_) =>
                                        _buildPlaceholder(),
                                    emptyBuilder: (_) => _buildPlaceholder(),
                                    errorBuilder: (_) => _buildPlaceholder(),
                                  ),
                                ),
                              ),
                              // Directory info
                              Expanded(
                                flex: UiGrid.infoFlex,
                                child: Padding(
                                  padding: EdgeInsets.all(paddingValue),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.directory.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                        maxLines: UiContent.maxLinesTitle,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: UiSpacing.extraSmallGap),
                                      Text(
                                        '${widget.directory.tagIds.length} tags',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                      if (widget.showTaggedMediaCounts) ...[
                                        SizedBox(
                                          height: UiSpacing.extraSmallGap,
                                        ),
                                        Text(
                                          '${widget.directory.mediaCounts.taggedMediaCount} / '
                                          '${widget.directory.mediaCounts.totalMediaCount} tagged',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.tag,
                                              size: iconSize,
                                            ),
                                            onPressed: () =>
                                                _showTagAssignmentDialog(
                                                  context,
                                                ),
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints.tight(
                                              Size(iconSize, iconSize),
                                            ),
                                            tooltip: 'Assign tags',
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.people_outline,
                                              size: iconSize,
                                            ),
                                            onPressed: () =>
                                                DirectoryProfileDialog.show(
                                                  context,
                                                  widget.directory,
                                                ),
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints.tight(
                                              Size(iconSize, iconSize),
                                            ),
                                            tooltip: 'Profiles',
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.image_outlined,
                                              size: iconSize,
                                            ),
                                            onPressed: _showCoverPicker,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            tooltip: 'Choose directory cover',
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints.tight(
                                              Size(iconSize, iconSize),
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete,
                                              size: iconSize,
                                            ),
                                            onPressed: widget.onDelete,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints.tight(
                                              Size(iconSize, iconSize),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.isSelectionMode || widget.isSelected)
                            Positioned(
                              top: UiSpacing.extraSmallGap,
                              left: UiSpacing.extraSmallGap,
                              child: Semantics(
                                selected: widget.isSelected,
                                button: true,
                                label: widget.isSelected
                                    ? 'Deselect directory ${widget.directory.name}'
                                    : 'Select directory ${widget.directory.name}',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.onSelectionToggle,
                                    borderRadius: BorderRadius.circular(
                                      UiSizing.borderRadiusSmall,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: widget.isSelected
                                            ? selectionHighlightColor
                                            : theme.colorScheme.surface,
                                        borderRadius: BorderRadius.circular(
                                          UiSizing.borderRadiusSmall,
                                        ),
                                        border: Border.all(
                                          color: widget.isSelected
                                              ? selectionHighlightColor
                                              : theme.colorScheme.outline,
                                          width: UiSizing.borderWidth / 1.5,
                                        ),
                                      ),
                                      padding: EdgeInsets.all(
                                        UiSpacing.extraSmallGap / 2,
                                      ),
                                      child: Icon(
                                        widget.isSelected
                                            ? Icons.check
                                            : Icons.circle_outlined,
                                        size: UiSizing.iconExtraSmall,
                                        color: widget.isSelected
                                            ? theme.colorScheme.onPrimary
                                            : theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTagAssignmentDialog(BuildContext context) {
    DirectoryTagAssignmentDialog.show(
      context,
      directory: widget.directory,
      onTagsAssigned: widget.onAssignTags,
    );
  }

  Future<void> _showCoverPicker() {
    return DirectoryCoverPickerDialog.show(
      context,
      directoryPath: widget.directory.path,
      directoryName: widget.directory.name,
      bookmarkData: widget.directory.bookmarkData,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.folder,
        size: UiSizing.iconExtraLarge,
        color: UiColors.grey,
      ),
    );
  }
}

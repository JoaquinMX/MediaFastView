import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

/// Describes an action that can be displayed inside the bulk selection toolbar.
class SelectionToolbarAction {
  const SelectionToolbarAction({
    required this.icon,
    required this.label,
    this.onPressed,
    this.tooltip,
    this.isVisible = true,
  });

  /// Icon displayed for the action button.
  final IconData icon;

  /// Text label for the action button.
  final String label;

  /// Callback invoked when the action is pressed. If null, the action is
  /// considered disabled.
  final VoidCallback? onPressed;

  /// Optional tooltip message shown on hover.
  final String? tooltip;

  /// Whether the action should be rendered.
  final bool isVisible;

  /// Whether the action is currently enabled.
  bool get isEnabled => onPressed != null;
}

/// A floating toolbar that surfaces actions that operate on the current
/// multi-selection.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onClearSelection,
    required this.actions,
    this.selectionIcon = Icons.check_box_outlined,
    this.clearButtonIcon = Icons.close,
    this.clearButtonLabel = 'Clear',
    this.selectionLabelBuilder,
  });

  /// Number of items currently selected.
  final int selectedCount;

  /// Callback invoked when the user wants to clear the current selection.
  final VoidCallback onClearSelection;

  /// Actions displayed within the toolbar.
  final List<SelectionToolbarAction> actions;

  /// Icon used to indicate the current selection.
  final IconData selectionIcon;

  /// Icon used for the clear-selection button.
  final IconData clearButtonIcon;

  /// Label used for the clear-selection button.
  final String clearButtonLabel;

  /// Builder used to generate the selection label text. If null, defaults to
  /// `"{count} selected"`.
  final String Function(int count)? selectionLabelBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleActions = actions.where((action) => action.isVisible);

    return SafeArea(
      minimum: EdgeInsets.symmetric(
        horizontal: UiSpacing.verticalGap,
        vertical: UiSpacing.smallGap,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          elevation: UiSizing.elevationHigh,
          borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
          color: colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: UiSpacing.verticalGap,
              vertical: UiSpacing.smallGap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selectionIcon, color: colorScheme.primary),
                SizedBox(width: UiSpacing.smallGap),
                Text(
                  selectionLabelBuilder?.call(selectedCount) ??
                      '$selectedCount selected',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: UiSpacing.smallGap),
                for (final action in visibleActions) ...[
                  Tooltip(
                    message: action.tooltip ?? action.label,
                    child: FilledButton.icon(
                      onPressed: action.onPressed,
                      icon: Icon(action.icon),
                      label: Text(action.label),
                      style: FilledButton.styleFrom(
                        backgroundColor: action.isEnabled
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest,
                        foregroundColor: action.isEnabled
                            ? colorScheme.onPrimary
                            : colorScheme.onSurfaceVariant,
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
                        disabledForegroundColor: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(width: UiSpacing.smallGap),
                ],
                const VerticalDivider(width: 1.0),
                SizedBox(width: UiSpacing.smallGap),
                TextButton.icon(
                  onPressed: onClearSelection,
                  icon: Icon(clearButtonIcon),
                  label: Text(clearButtonLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

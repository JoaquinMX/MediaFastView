import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

/// Visual emphasis levels for descriptive messaging within a
/// [PermissionIssuePanel].
enum PermissionIssueMessageType {
  /// Standard emphasis for primary descriptive messaging.
  primary,

  /// Reduced emphasis for secondary messaging.
  secondary,

  /// Small helper copy used for additional hints or follow-up guidance.
  helper,
}

/// Model describing a block of text shown inside a [PermissionIssuePanel].
class PermissionIssueMessage {
  const PermissionIssueMessage(
    this.text, {
    this.type = PermissionIssueMessageType.primary,
  });

  /// Message to render.
  final String text;

  /// Styling hint to determine text emphasis.
  final PermissionIssueMessageType type;
}

/// Button style variants supported by the [PermissionIssuePanel].
enum PermissionIssueActionStyle {
  /// Elevated button – primary action.
  primary,

  /// Outlined button – secondary action.
  secondary,

  /// Text button – tertiary action.
  tertiary,
}

/// Configuration for an actionable control rendered by [PermissionIssuePanel].
class PermissionIssueAction {
  const PermissionIssueAction({
    required this.label,
    this.icon,
    this.onPressed,
    this.style = PermissionIssueActionStyle.primary,
    this.buttonStyle,
  });

  /// Display label for the button.
  final String label;

  /// Optional leading icon.
  final IconData? icon;

  /// Callback triggered when the button is pressed.
  final FutureOr<void> Function()? onPressed;

  /// Visual style to apply to the button.
  final PermissionIssueActionStyle style;

  /// Optional custom button style overrides.
  final ButtonStyle? buttonStyle;
}

/// Shared panel used to surface permission or access issues alongside
/// recovery actions.
class PermissionIssuePanel extends StatelessWidget {
  const PermissionIssuePanel({
    super.key,
    this.title = 'Access to this directory has been revoked',
    this.messages = const <PermissionIssueMessage>[
      PermissionIssueMessage(
        'The permissions for this directory are no longer available.',
      ),
      PermissionIssueMessage(
        'This can happen when security-scoped bookmarks expire or when directory permissions change.',
        type: PermissionIssueMessageType.helper,
      ),
    ],
    this.icon = Icons.lock,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
    this.actions = const <PermissionIssueAction>[],
    this.footer,
    this.margin,
    this.padding = UiSpacing.dialogPadding,
    this.maxWidth,
    this.boxShadow,
  });

  /// Headline displayed at the top of the panel.
  final String title;

  /// Supporting descriptive copy shown under the title.
  final List<PermissionIssueMessage> messages;

  /// Icon used to represent the issue state.
  final IconData icon;

  /// Overrides the icon color if provided.
  final Color? iconColor;

  /// Overrides the container background color if provided.
  final Color? backgroundColor;

  /// Overrides the container border color if provided.
  final Color? borderColor;

  /// Actions rendered below the descriptive messaging.
  final List<PermissionIssueAction> actions;

  /// Optional trailing widget, typically additional helper copy.
  final Widget? footer;

  /// Margin applied around the panel.
  final EdgeInsetsGeometry? margin;

  /// Padding applied within the panel.
  final EdgeInsetsGeometry padding;

  /// Maximum width constraint for the panel. Leave `null` for no constraint.
  final double? maxWidth;

  /// Overrides the panel box shadow if provided. Use an empty list to remove
  /// shadows.
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final resolvedIconColor = iconColor ?? colorScheme.error;
    final resolvedBorderColor = borderColor ?? resolvedIconColor;
    final resolvedBackgroundColor =
        backgroundColor ?? colorScheme.surface.withValues(alpha: 0.95);
    final resolvedBoxShadow =
        boxShadow ?? <BoxShadow>[UiShadows.standard];

    Widget panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackgroundColor,
        borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
        border: Border.all(
          color: resolvedBorderColor,
          width: UiSizing.borderWidth,
        ),
        boxShadow: resolvedBoxShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: UiSizing.iconHuge, color: resolvedIconColor),
          SizedBox(height: UiSpacing.verticalGap),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          for (var index = 0; index < messages.length; index++) ...[
            SizedBox(
              height:
                  index == 0 ? UiSpacing.smallGap : UiSpacing.extraSmallGap,
            ),
            Text(
              messages[index].text,
              style: _resolveMessageStyle(
                theme,
                colorScheme,
                messages[index].type,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (actions.isNotEmpty) ...[
            SizedBox(height: UiSpacing.verticalGap),
            for (var i = 0; i < actions.length; i++) ...[
              _buildActionButton(actions[i]),
              if (i != actions.length - 1)
                SizedBox(height: UiSpacing.smallGap),
            ],
          ],
          if (footer != null) ...[
            SizedBox(height: UiSpacing.smallGap),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ) ??
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
              child: footer!,
            ),
          ],
        ],
      ),
    );

    if (maxWidth != null) {
      panel = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: panel,
      );
    }

    if (margin != null) {
      panel = Padding(padding: margin!, child: panel);
    }

    return panel;
  }

  TextStyle _resolveMessageStyle(
    ThemeData theme,
    ColorScheme colorScheme,
    PermissionIssueMessageType type,
  ) {
    switch (type) {
      case PermissionIssueMessageType.primary:
        return theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ) ??
            TextStyle(color: colorScheme.onSurface, fontSize: 16);
      case PermissionIssueMessageType.secondary:
        return theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16);
      case PermissionIssueMessageType.helper:
        return theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ) ??
            TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12);
    }
  }

  Widget _buildActionButton(PermissionIssueAction action) {
    final label = Text(action.label);
    final icon = action.icon != null ? Icon(action.icon) : null;

    switch (action.style) {
      case PermissionIssueActionStyle.primary:
        return icon != null
            ? ElevatedButton.icon(
                onPressed: action.onPressed == null
                    ? null
                    : () async => await action.onPressed!.call(),
                icon: icon,
                label: label,
                style: action.buttonStyle,
              )
            : ElevatedButton(
                onPressed: action.onPressed == null
                    ? null
                    : () async => await action.onPressed!.call(),
                style: action.buttonStyle,
                child: label,
              );
      case PermissionIssueActionStyle.secondary:
        return icon != null
            ? OutlinedButton.icon(
                onPressed: action.onPressed == null
                    ? null
                    : () async => await action.onPressed!.call(),
                icon: icon,
                label: label,
                style: action.buttonStyle,
              )
            : OutlinedButton(
                onPressed: action.onPressed == null
                    ? null
                    : () async => await action.onPressed!.call(),
                style: action.buttonStyle,
                child: label,
              );
      case PermissionIssueActionStyle.tertiary:
        return icon != null
            ? TextButton.icon(
                onPressed: action.onPressed == null
                    ? null
                    : () async => await action.onPressed!.call(),
                icon: icon,
                label: label,
                style: action.buttonStyle,
              )
            : TextButton(
                onPressed: action.onPressed == null
                    ? null
                    : () async => await action.onPressed!.call(),
                style: action.buttonStyle,
                child: label,
              );
    }
  }
}

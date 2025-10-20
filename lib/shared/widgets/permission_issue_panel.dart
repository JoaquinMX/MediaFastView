import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

/// A shared panel widget for displaying permission or access issues with
/// consistent styling across the application.
class PermissionIssuePanel extends StatelessWidget {
  const PermissionIssuePanel({
    super.key,
    this.icon = Icons.lock,
    this.showIcon = true,
    this.title = 'Access to this directory has been revoked',
    this.message,
    this.helpText,
    this.footerText,
    this.onRecover,
    this.onTryAgain,
    this.onBack,
    this.recoverLabel = 'Recover Access',
    this.tryAgainLabel = 'Try Again',
    this.backLabel = 'Back',
    this.recoverIcon = Icons.refresh,
    this.tryAgainIcon = Icons.refresh,
    this.backIcon = Icons.arrow_back,
    this.accentColor,
    this.backgroundColor,
    this.borderColor,
    this.margin,
    this.padding,
    this.fullWidth = false,
    this.dense = false,
  });

  /// Icon displayed at the top of the panel.
  final IconData icon;

  /// Whether the icon should be displayed.
  final bool showIcon;

  /// Title text describing the permission issue.
  final String title;

  /// Optional descriptive message providing more context.
  final String? message;

  /// Optional helper text to guide the user.
  final String? helpText;

  /// Optional footer text shown after the actions.
  final String? footerText;

  /// Callback executed when the recover action is triggered.
  final Future<void> Function()? onRecover;

  /// Callback executed when the retry action is triggered.
  final VoidCallback? onTryAgain;

  /// Callback executed when the back action is triggered.
  final VoidCallback? onBack;

  /// Label for the recover action button.
  final String recoverLabel;

  /// Label for the retry action button.
  final String tryAgainLabel;

  /// Label for the back action button.
  final String backLabel;

  /// Icon for the recover action button.
  final IconData recoverIcon;

  /// Icon for the retry action button.
  final IconData tryAgainIcon;

  /// Icon for the back action button.
  final IconData backIcon;

  /// Accent color used for the icon, border, and emphasis.
  final Color? accentColor;

  /// Background color of the panel container.
  final Color? backgroundColor;

  /// Border color of the panel container.
  final Color? borderColor;

  /// Margin applied around the panel.
  final EdgeInsetsGeometry? margin;

  /// Padding applied within the panel container.
  final EdgeInsetsGeometry? padding;

  /// Whether the panel should expand to the maximum width available.
  final bool fullWidth;

  /// Reduces spacing between elements when set to true.
  final bool dense;

  bool get _hasActions => onRecover != null || onTryAgain != null || onBack != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAccent = accentColor ?? colorScheme.error;
    final effectiveBorder = borderColor ?? effectiveAccent;
    final effectiveBackground = backgroundColor ?? colorScheme.surface;
    final effectiveMargin = margin ?? UiSpacing.dialogMargin;
    final effectivePadding = padding ?? UiSpacing.dialogPadding;
    final verticalGap = dense ? UiSpacing.smallGap : UiSpacing.verticalGap;

    return Container(
      width: fullWidth ? double.infinity : null,
      margin: effectiveMargin,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(UiSizing.borderRadiusMedium),
        border: Border.all(color: effectiveBorder, width: UiSizing.borderWidth),
        boxShadow: const [UiShadows.standard],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showIcon)
            Icon(
              icon,
              size: UiSizing.iconHuge,
              color: effectiveAccent,
            ),
          if (showIcon) SizedBox(height: verticalGap),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            SizedBox(height: UiSpacing.smallGap),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
            ),
          ],
          if (helpText != null) ...[
            SizedBox(height: UiSpacing.smallGap),
            Text(
              helpText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
          if (_hasActions) ...[
            SizedBox(height: dense ? UiSpacing.smallGap : UiSpacing.verticalGap * 1.5),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: UiSpacing.smallGap,
              runSpacing: UiSpacing.smallGap,
              children: [
                if (onRecover != null)
                  ElevatedButton.icon(
                    onPressed: () async => await onRecover!(),
                    icon: Icon(recoverIcon),
                    label: Text(recoverLabel),
                  ),
                if (onTryAgain != null)
                  OutlinedButton.icon(
                    onPressed: onTryAgain,
                    icon: Icon(tryAgainIcon),
                    label: Text(tryAgainLabel),
                  ),
                if (onBack != null)
                  TextButton.icon(
                    onPressed: onBack,
                    icon: Icon(backIcon),
                    label: Text(backLabel),
                  ),
              ],
            ),
          ],
          if (footerText != null) ...[
            SizedBox(height: UiSpacing.smallGap),
            Text(
              footerText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

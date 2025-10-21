import 'package:flutter/material.dart';

/// Signature for async callbacks triggered when the favorite toggle button is
/// pressed.
typedef FavoriteToggleCallback = Future<void> Function();

/// A reusable favorite toggle icon button that centralizes styling, tooltip
/// messaging and busy state handling.
class FavoriteToggleButton extends StatelessWidget {
  const FavoriteToggleButton({
    super.key,
    required this.isFavorite,
    this.onToggle,
    this.isBusy = false,
    this.enableWhileBusy = false,
    this.showBusyIndicator = false,
    this.iconSize,
    this.backgroundColor,
    this.favoriteColor,
    this.idleColor,
    this.tooltip,
  });

  /// Whether the associated media is currently a favorite.
  final bool isFavorite;

  /// Callback invoked when the toggle is pressed.
  final FavoriteToggleCallback? onToggle;

  /// Indicates whether a favorite operation is currently in progress.
  final bool isBusy;

  /// Allows presses even when [isBusy] is true.
  final bool enableWhileBusy;

  /// Displays a busy indicator overlay when [isBusy] is true.
  final bool showBusyIndicator;

  /// Overrides the icon size used by the button.
  final double? iconSize;

  /// Overrides the background color applied to the button.
  final Color? backgroundColor;

  /// Overrides the color used when the media is a favorite.
  final Color? favoriteColor;

  /// Overrides the color used when the media is not a favorite.
  final Color? idleColor;

  /// Overrides the tooltip message displayed on hover or long press.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconTheme = IconTheme.of(context);
    final resolvedIconSize = iconSize ?? iconTheme.size ?? 24.0;
    final resolvedFavoriteColor = favoriteColor ?? colorScheme.error;
    final resolvedIdleColor = idleColor ?? colorScheme.onSurface;
    final resolvedBackground = backgroundColor;
    final resolvedTooltip =
        tooltip ?? (isFavorite ? 'Remove from favorites' : 'Add to favorites');

    final isDisabled = onToggle == null || (isBusy && !enableWhileBusy);

    Widget button = IconButton(
      iconSize: resolvedIconSize,
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        size: resolvedIconSize,
        color: isFavorite ? resolvedFavoriteColor : resolvedIdleColor,
      ),
      tooltip: resolvedTooltip,
      onPressed: isDisabled
          ? null
          : () async {
              await onToggle!.call();
            },
      style: IconButton.styleFrom(
        backgroundColor: resolvedBackground,
        foregroundColor:
            isFavorite ? resolvedFavoriteColor : resolvedIdleColor,
      ),
    );

    if (isBusy && showBusyIndicator) {
      button = Stack(
        alignment: Alignment.center,
        children: [
          button,
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withOpacity(0.35),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    height: resolvedIconSize * 0.55,
                    width: resolvedIconSize * 0.55,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isFavorite
                            ? resolvedFavoriteColor
                            : resolvedIdleColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return button;
  }
}

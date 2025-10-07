// Centralized UI constants for consistent styling and layout across the application.
// This file contains all hardcoded values for animations, spacing, sizing, colors, and layout parameters.

import 'package:flutter/material.dart';

/// Animation constants
class UiAnimations {
  /// Standard animation duration for UI transitions
  static const Duration standard = Duration(milliseconds: 200);

  /// Progress update interval for slideshow
  static const Duration progressUpdate = Duration(milliseconds: 100);

  /// Animation scale values
  static const double scaleNormal = 1.0;
  static const double scaleHover = 1.05;

  /// Animation elevation values
  static const double elevationNormal = 2.0;
  static const double elevationHover = 8.0;
}

/// Spacing and padding constants
class UiSpacing {
  /// Standard grid padding
  static const EdgeInsets gridPadding = EdgeInsets.all(16);

  /// Tag filter padding
  static const EdgeInsets tagFilterPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  /// Dialog content padding
  static const EdgeInsets dialogPadding = EdgeInsets.all(24);

  /// Dialog margin
  static const EdgeInsets dialogMargin = EdgeInsets.symmetric(horizontal: 32);

  /// Button padding for elevated buttons
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 24, vertical: 12);

  /// Small padding for overlays and chips
  static const EdgeInsets smallPadding = EdgeInsets.all(4);

  /// Horizontal padding for text elements
  static const EdgeInsets horizontalSmall = EdgeInsets.symmetric(horizontal: 4);

  /// Filter chip right padding
  static const EdgeInsets filterChipRight = EdgeInsets.only(right: 8);

  /// Standard vertical spacing between elements
  static const double verticalGap = 16;

  /// Small vertical spacing
  static const double smallGap = 8;

  /// Extra small vertical spacing
  static const double extraSmallGap = 4;
}

/// Sizing constants
class UiSizing {
  /// Standard icon sizes
  static const double iconExtraSmall = 16;
  static const double iconSmall = 20;
  static const double iconMedium = 28;
  static const double iconLarge = 32;
  static const double iconExtraLarge = 48;
  static const double iconHuge = 64;

  /// Border radius values
  static const double borderRadiusSmall = 8;
  static const double borderRadiusMedium = 12;

  /// Border width
  static const double borderWidth = 2;

  /// Elevation values
  static const double elevationLow = 2;
  static const double elevationHigh = 8;

  /// Progress bar height
  static const double progressBarHeight = 4;

  /// Tag filter container height
  static const double tagFilterHeight = 50;

  /// Circular progress indicator size
  static const double progressIndicatorSize = 16;

  /// Responsive sizing thresholds
  static const double responsiveHeightThreshold = 60;
}

/// Opacity constants
class UiOpacity {
  /// Semi-transparent overlay
  static const double overlay = 0.7;

  /// Low opacity for disabled states
  static const double disabled = 0.5;

  /// Very low opacity for subtle effects
  static const double subtle = 0.1;

  /// Medium opacity for backgrounds
  static const double background = 0.3;

  /// High opacity for dark overlays
  static const double darkOverlay = 0.9;
}

/// Grid and layout constants
class UiGrid {
  /// Grid spacing
  static const double crossAxisSpacing = 16;
  static const double mainAxisSpacing = 16;

  /// Grid aspect ratio
  static const double childAspectRatio = 0.8;

  /// Maximum cross-axis extent for responsive grid
  static const double maxCrossAxisExtent = 160.0;

  /// Maximum number of filter chips to show
  static const int maxFilterChips = 8;

  /// Flex ratios for grid items
  static const int thumbnailFlex = 3;
  static const int infoFlex = 2;

  /// Directory preview flex ratios
  static const int directoryPreviewFlex = 7;
  static const int directoryNameFlex = 1;
}

/// Shadow and blur constants
class UiShadows {
  /// Standard box shadow
  static const BoxShadow standard = BoxShadow(
    color: Colors.black,
    blurRadius: 10,
    offset: Offset(0, 4),
  );

  /// Subtle box shadow for tag picker
  static const BoxShadow subtle = BoxShadow(
    color: Colors.black,
    blurRadius: 4,
    spreadRadius: 1,
  );
}

/// Position constants
class UiPosition {
  /// Hover overlay position
  static const double overlayTop = 4;
  static const double overlayRight = 4;

  /// Context menu position
  static const RelativeRect contextMenu = RelativeRect.fromLTRB(100, 100, 0, 0);
}

/// Text and content constants
class UiContent {
  /// Maximum text preview length
  static const int textPreviewMaxLength = 200;

  /// Maximum lines for text display
  static const int maxLinesTitle = 2;
  static const int maxLinesBody = 5;
  static const int maxLinesSingle = 1;
}

/// Color constants (non-theme dependent)
class UiColors {
  /// Standard colors
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color red = Colors.red;
  static const Color green = Colors.green;
  static const Color orange = Colors.orange;
  static const Color grey = Colors.grey;

  /// Opacity variants
  static const Color blackOverlay = Color(0xB3000000); // Black with 0.7 opacity
  static const Color whiteOverlay = Color(0x4DFFFFFF); // White with 0.3 opacity
}

/// 📏 App Spacing System
/// Consistent padding, margins, and gaps throughout the app
/// Based on Material Design 3 spacing scale (8px base unit)

import 'package:flutter/material.dart';

class AppSpacing {
  // ZERO
  static const double none = 0;

  // EXTRA SMALL (4px - quarter unit)
  static const double xs = 4.0;

  // SMALL (8px - base unit)
  static const double sm = 8.0;

  // MEDIUM (12px - 1.5x base)
  static const double md = 12.0;

  // LARGE (16px - 2x base)
  static const double lg = 16.0;

  // EXTRA LARGE (20px - 2.5x base)
  static const double xl = 20.0;

  // DOUBLE EXTRA LARGE (24px - 3x base)
  static const double xxl = 24.0;

  // TRIPLE EXTRA LARGE (32px - 4x base)
  static const double xxxl = 32.0;

  // QUAD (40px - 5x base)
  static const double quad = 40.0;

  // QUINT (48px - 6x base)
  static const double quint = 48.0;

  // SCREEN PADDING
  /// Standard horizontal padding for screens
  static const double screenHorizontal = lg; // 16px

  /// Standard vertical padding for screens
  static const double screenVertical = lg; // 16px

  /// Combined screen padding (horizontal and vertical)
  static const double screenPadding = lg;

  // COMPONENT SPACING

  /// Product Card Padding
  static const double productCardPadding = md; // 12px

  /// Product Card Image Height
  static const double productCardImageHeight = 140.0;

  /// List Item Padding
  static const double listItemPadding = lg; // 16px

  /// List Item Vertical Gap
  static const double listItemGap = sm; // 8px

  // BUTTON SPACING

  /// Button Horizontal Padding
  static const double buttonHorizontalPadding = lg; // 16px

  /// Button Vertical Padding (Small)
  static const double buttonVerticalPaddingSmall = sm; // 8px

  /// Button Vertical Padding (Medium)
  static const double buttonVerticalPaddingMedium = md; // 12px

  /// Button Vertical Padding (Large)
  static const double buttonVerticalPaddingLarge = lg; // 16px

  // INPUT FIELD SPACING

  /// Text Field Horizontal Padding
  static const double inputHorizontalPadding = lg; // 16px

  /// Text Field Vertical Padding
  static const double inputVerticalPadding = md; // 12px

  // CARD SPACING

  /// Card Padding
  static const double cardPadding = lg; // 16px

  /// Card Margin
  static const double cardMargin = sm; // 8px

  // BORDER RADIUS

  /// Small Border Radius (Tight curves)
  static const double radiusSmall = 4.0;

  /// Medium Border Radius (Standard)
  static const double radiusMedium = 8.0;

  /// Large Border Radius (Rounded)
  static const double radiusLarge = 12.0;

  /// Extra Large Border Radius (Very rounded)
  static const double radiusXL = 16.0;

  /// Card Border Radius (Default)
  static const double radiusCard = radiusMedium; // 8px

  /// Button Border Radius
  static const double radiusButton = radiusMedium; // 8px

  /// Dialog/Modal Border Radius
  static const double radiusDialog = radiusLarge; // 12px

  /// Full Pill Shape (100% border-radius)
  static const double radiusPill = 100.0;

  // ELEVATION / SHADOW

  /// No Shadow
  static const double elevationNone = 0;

  /// Elevation Level 1 (Subtle)
  static const double elevation1 = 2.0;

  /// Elevation Level 2 (Standard)
  static const double elevation2 = 4.0;

  /// Elevation Level 3 (Prominent)
  static const double elevation3 = 6.0;

  /// Elevation Level 4 (High)
  static const double elevation4 = 8.0;

  /// Elevation Level 5 (Very High)
  static const double elevation5 = 12.0;

  // TOUCH TARGET SIZE
  /// Minimum touch target size (Material Design recommendation: 48dp)
  static const double touchTargetMinimum = 48.0;

  /// Button Height (Touch-optimized)
  static const double buttonHeightSmall = 36.0;
  static const double buttonHeightMedium = 44.0;
  static const double buttonHeightLarge = 56.0;

  // ICON SIZES
  static const double iconSmall = 16.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;
  static const double iconXLarge = 48.0;

  // GAP SIZES (For Row/Column spacing)
  static const double gapXSmall = 4.0;
  static const double gapSmall = 8.0;
  static const double gapMedium = 12.0;
  static const double gapLarge = 16.0;
  static const double gapXLarge = 20.0;

  // LINE HEIGHT MULTIPLIERS (For text)
  static const double lineHeightTight = 1.2;
  static const double lineHeightNormal = 1.4;
  static const double lineHeightRelaxed = 1.5;
  static const double lineHeightLoose = 1.6;

  // DIVIDER / BORDER SPACING
  static const double dividerThickness = 1.0;
  static const double borderThicknessSmall = 1.0;
  static const double borderThicknessMedium = 2.0;
  static const double borderThicknessLarge = 3.0;
}

/// Common spacing combinations for quick use
class SpacingPresets {
  /// Default content padding
  static const EdgeInsets contentPadding = EdgeInsets.all(AppSpacing.lg);

  /// Horizontal padding only
  static const EdgeInsets horizontalPadding =
      EdgeInsets.symmetric(horizontal: AppSpacing.lg);

  /// Vertical padding only
  static const EdgeInsets verticalPadding =
      EdgeInsets.symmetric(vertical: AppSpacing.lg);

  /// Small card padding
  static const EdgeInsets smallCardPadding = EdgeInsets.all(AppSpacing.md);

  /// Standard card padding
  static const EdgeInsets cardPadding = EdgeInsets.all(AppSpacing.lg);

  /// Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Input field padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(AppSpacing.lg);

  /// List item padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );

  /// Dialog padding
  static const EdgeInsets dialogPadding = EdgeInsets.all(AppSpacing.xxl);

  /// No padding
  static const EdgeInsets none = EdgeInsets.zero;
}

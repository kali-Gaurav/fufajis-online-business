/// 📝 App Typography System
/// Design tokens for text styles
/// Font: Noto Sans (supports Devanagari for Hindi)
/// Optimized for: Reading on mobile (4.5" to 6.5" screens)

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  /// Font Family
  /// Noto Sans supports both Latin (English) and Devanagari (Hindi)
  static const String fontFamily = 'NotoSans';

  /// HEADING STYLES

  /// H1 - Large Page Title
  /// Size: 32px | Weight: 700 | Line Height: 1.2
  /// Use: App title, main headers
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  /// H2 - Section Heading
  /// Size: 24px | Weight: 600 | Line Height: 1.3
  /// Use: Screen titles, major sections
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  /// H3 - Subsection Heading
  /// Size: 20px | Weight: 600 | Line Height: 1.4
  /// Use: Subsection titles, card headings
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// H4 - Small Heading
  /// Size: 18px | Weight: 600 | Line Height: 1.4
  /// Use: Product names, important labels
  static const TextStyle h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// H5 - Extra Small Heading
  /// Size: 16px | Weight: 600 | Line Height: 1.5
  /// Use: Product card title, sub-headings
  static const TextStyle h5 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// BODY STYLES

  /// Body Large - Main Content
  /// Size: 16px | Weight: 400 | Line Height: 1.5
  /// Use: Paragraphs, long-form text, descriptions
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Body Medium - Standard Text
  /// Size: 14px | Weight: 400 | Line Height: 1.5
  /// Use: Regular content, labels
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  /// Body Small - Secondary Text
  /// Size: 12px | Weight: 400 | Line Height: 1.5
  /// Use: Hints, secondary information, fine print
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// LABEL STYLES

  /// Label Large - Large Label
  /// Size: 14px | Weight: 600 | Line Height: 1.4
  /// Use: Button text, field labels
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  /// Label Medium - Standard Label
  /// Size: 12px | Weight: 500 | Line Height: 1.4
  /// Use: Badge text, small labels
  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textPrimary,
    letterSpacing: 0.4,
  );

  /// Label Small - Small Label
  /// Size: 11px | Weight: 600 | Line Height: 1.4
  /// Use: Discount badge, tiny labels
  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  /// PRICE STYLES

  /// Price Large - Main Price Display
  /// Size: 24px | Weight: 700 | Color: Green
  /// Use: Discounted/sale price on product cards
  static const TextStyle priceLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.priceGreen,
    letterSpacing: -0.5,
  );

  /// Price Medium - Secondary Price
  /// Size: 18px | Weight: 700 | Color: Green
  /// Use: Price in product details
  static const TextStyle priceMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.priceGreen,
  );

  /// Original Price - Strikethrough
  /// Size: 14px | Weight: 400 | Color: Gray
  /// Use: Original/list price (shown with strikethrough)
  static const TextStyle originalPrice = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.priceGray,
    decoration: TextDecoration.lineThrough,
  );

  /// BUTTON STYLES

  /// Button Large
  /// Size: 16px | Weight: 600 | Line Height: 1.3
  /// Use: Large CTA buttons
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.5,
  );

  /// Button Medium
  /// Size: 14px | Weight: 600 | Line Height: 1.3
  /// Use: Standard CTA buttons
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.5,
  );

  /// Button Small
  /// Size: 12px | Weight: 600 | Line Height: 1.3
  /// Use: Small action buttons
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.5,
  );

  /// SPECIAL STYLES

  /// Caption - Very Small Text
  /// Size: 10px | Weight: 400 | Color: Tertiary
  /// Use: Timestamps, metadata
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  /// Overline - All Caps Label
  /// Size: 12px | Weight: 600 | Color: Tertiary
  /// Use: Section labels (all caps)
  static const TextStyle overline = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textTertiary,
    letterSpacing: 1.5,
  );

  /// ERROR TEXT STYLE
  /// Size: 12px | Weight: 500 | Color: Danger
  /// Use: Error messages, validation messages
  static const TextStyle error = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.danger,
  );

  /// SUCCESS TEXT STYLE
  /// Size: 12px | Weight: 500 | Color: Success
  /// Use: Success messages, confirmations
  static const TextStyle success = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.success,
  );

  /// PRODUCT CARD STYLES

  /// Product Name - English
  /// Size: 16px | Weight: 600
  static const TextStyle productNameEn = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  /// Product Name - Hindi (Subtitle)
  /// Size: 12px | Weight: 400 | Color: Secondary
  static const TextStyle productNameHi = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Product Weight/Unit
  /// Size: 12px | Weight: 400 | Color: Tertiary
  static const TextStyle productWeight = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textTertiary,
  );

  /// Product Rating
  /// Size: 12px | Weight: 500
  static const TextStyle productRating = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// Product Description
  /// Size: 13px | Weight: 400 | Line Height: 1.5
  static const TextStyle productDescription = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  /// Discount Percentage Badge
  /// Size: 11px | Weight: 600 | Color: White
  static const TextStyle discountBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Colors.white,
  );

  /// Stock Status Badge
  /// Size: 12px | Weight: 600 | Color: White
  static const TextStyle stockBadge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: Colors.white,
  );

  /// Disabled Text
  /// Similar to bodyMedium but with disabled color
  static const TextStyle disabled = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textDisabled,
  );

  /// RESPONSIVE FONT SIZES
  /// Use these methods to scale text based on screen size

  static double responsiveSize(double baseSize, {double maxSize = 32}) {
    // This would be called with screen width in actual usage
    // For now, just return base size
    // Implementation: return (baseSize * (screenWidth / 375)).clamp(baseSize, maxSize);
    return baseSize;
  }
}

/// Extension for easy TextStyle creation with custom colors
extension TextStyleExtension on TextStyle {
  /// Create a copy with a different color
  TextStyle withColor(Color color) {
    return copyWith(color: color);
  }

  /// Create a copy with different weight
  TextStyle withWeight(FontWeight weight) {
    return copyWith(fontWeight: weight);
  }

  /// Create a copy with different size
  TextStyle withSize(double size) {
    return copyWith(fontSize: size);
  }

  /// Create a copy with opacity
  TextStyle withOpacity(double opacity) {
    return copyWith(
      color: color?.withOpacity(opacity),
    );
  }

  /// Make text bold
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);

  /// Make text semibold
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);

  /// Make text light
  TextStyle get light => copyWith(fontWeight: FontWeight.w300);

  /// Make text italic
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);

  /// Add strikethrough
  TextStyle get strikethrough => copyWith(
        decoration: TextDecoration.lineThrough,
      );

  /// Add underline
  TextStyle get underline => copyWith(
        decoration: TextDecoration.underline,
      );
}

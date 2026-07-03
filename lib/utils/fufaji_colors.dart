import 'package:flutter/material.dart';

/// Fufaji Brand Color System (Redesigned)
///
/// Unified color palette utilizing Warm Sunset Orange & Cream White.
class FufajiColors {
  // Brand Colors
  static const Color primary = Color(0xFFFF8C42); // Primary Sunset Orange
  static const Color primaryDark = Color(0xFFE56F1F); // Dark Orange
  static const Color primaryLight = Color(0xFFFFE5D0); // Light Orange

  // Backgrounds & Surfaces
  static const Color cream = Color(0xFFFFF8F2); // Cream Background
  static const Color sand = Color(0xFFFAECE3); // Sand Surface
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // Neutral Greys
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF1F2937); // Text Dark (matching palette)

  // Status & Semantic Colors (WCAG compliant)
  static const Color success = Color(0xFF22C55E); // Success Green
  static const Color warning = Color(0xFFF59E0B); // Warning Amber
  static const Color error = Color(0xFFEF4444); // Error Red
  static const Color info = Color(0xFF3B82F6); // Info Blue

  // Legacy Aliases for compatibility
  static const Color primaryColor = primary;
  static const Color errorColor = error;
  static const Color ownerColor = info;
  static const Color deliveryColor = success;

  // Text Colors
  static const Color textPrimary = grey900;
  static const Color textSecondary = grey700;
  static const Color textTertiary = grey600;
  static const Color textHint = grey400;
  static const Color textDisabled = grey300;
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFEEEEEE);

  // Category Colors
  static const Map<String, Color> categoryColors = {
    'groceries': Color(0xFF22C55E),
    'vegetables': Color(0xFF84CC16),
    'fruits': Color(0xFFF97316),
    'dairy': Color(0xFFEAB308),
    'bakery': Color(0xFF854D0E),
    'snacks': Color(0xFFFF8C42),
    'beverages': Color(0xFF06B6D4),
    'household': Color(0xFF64748B),
    'personalCare': Color(0xFFEC4899),
    'electronics': Color(0xFF3B82F6),
    'clothing': Color(0xFFA855F7),
    'footwear': Color(0xFF6366F1),
    'homeDecor': Color(0xFF14B8A6),
    'kitchenware': Color(0xFFFF8C42),
    'stationery': Color(0xFF64748B),
    'agricultural': Color(0xFF84CC16),
    'other': Color(0xFF64748B),
  };

  static Color getTextColorForBackground(Color background) {
    final value = background.toARGB32() & 0x00FFFFFF;
    final r = (value >> 16) & 0xFF;
    final g = (value >> 8) & 0xFF;
    final b = value & 0xFF;
    final luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    return luminance > 0.5 ? textPrimary : textPrimaryDark;
  }
}

@Deprecated('Use FufajiColors instead')
typedef FujajiColors = FufajiColors;

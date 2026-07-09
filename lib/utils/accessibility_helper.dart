import 'dart:math' show pow;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/rendering.dart';
import 'fufaji_colors.dart';

/// AccessibilityHelper - Centralized Accessibility Utilities
///
/// Provides reusable methods for:
/// - Focus ring styling
/// - Screen reader announcements
/// - Keyboard event handling
/// - Contrast checking
/// - High contrast mode detection
///
/// Usage:
/// ```dart
/// // Get focus outline decoration
/// Container(
///   decoration: AccessibilityHelper.getFocusOutlineDecoration(hasFocus: true),
///   child: MyWidget(),
/// )
///
/// // Announce to screen reader
/// AccessibilityHelper.announceToScreenReader('Item added to cart');
/// ```

class AccessibilityHelper {
  // Focus Ring Styling Constants
  static const double focusOutlineWidth = 2.0;
  static const double focusOutlineCornerRadius = 8.0;
  static const Color focusOutlineColor = FufajiColors.primary; // Orange
  static const Duration focusAnimationDuration = Duration(milliseconds: 200);

  /// Detects if high contrast mode is enabled on the device
  static bool shouldShowFocusRing(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Show focus ring unless high contrast is already enabled
    return !mediaQuery.highContrast;
  }

  /// Detects if reduced motion is preferred (accessibility setting)
  static bool isReducedMotionEnabled(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Announce text to screen reader (TalkBack/VoiceOver)
  ///
  /// Example:
  /// ```dart
  /// AccessibilityHelper.announceToScreenReader('Order confirmed');
  /// ```
  static Future<void> announceToScreenReader(String message) {
    return SemanticsService.announce(message);
  }

  /// Get focus ring decoration for containers
  ///
  /// Usage:
  /// ```dart
  /// Container(
  ///   decoration: AccessibilityHelper.getFocusOutlineDecoration(
  ///     hasFocus: _focusNode.hasFocus,
  ///   ),
  ///   child: child,
  /// )
  /// ```
  static BoxDecoration getFocusOutlineDecoration({
    required bool hasFocus,
    double cornerRadius = focusOutlineCornerRadius,
  }) {
    if (!hasFocus) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(cornerRadius),
      );
    }

    return BoxDecoration(
      border: Border.all(
        color: focusOutlineColor,
        width: focusOutlineWidth,
      ),
      borderRadius: BorderRadius.circular(cornerRadius),
    );
  }

  /// Get focus ring border for cards
  static OutlineInputBorder getFocusBorder({
    double borderRadius = focusOutlineCornerRadius,
    bool isFocused = false,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      borderSide: BorderSide(
        color: isFocused ? focusOutlineColor : FufajiColors.grey300,
        width: isFocused ? focusOutlineWidth : 1.0,
      ),
    );
  }

  /// Build a semantic button wrapper
  ///
  /// Ensures proper accessibility for custom buttons
  static Widget semanticButton({
    required VoidCallback? onPressed,
    required Widget child,
    String? label,
    String? hint,
  }) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      enabled: onPressed != null,
      onTap: onPressed,
      child: child,
    );
  }

  /// Build a semantic card wrapper
  ///
  /// Ensures proper accessibility for card containers
  static Widget semanticCard({
    required Widget child,
    required String label,
    String? hint,
    VoidCallback? onTap,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: onTap != null,
      enabled: onTap != null,
      onTap: onTap,
      child: child,
    );
  }

  /// Check color contrast ratio between two colors
  /// Returns true if contrast is WCAG AA compliant (4.5:1 for text, 3:1 for UI)
  static bool isContrastCompliant(Color foreground, Color background) {
    final fgLum = _getRelativeLuminance(foreground);
    final bgLum = _getRelativeLuminance(background);

    final contrast = (max(fgLum, bgLum) + 0.05) / (min(fgLum, bgLum) + 0.05);
    // WCAG AA level: 4.5:1 for small text
    return contrast >= 4.5;
  }

  /// Get relative luminance of a color (for contrast calculations)
  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.red / 255);
    final g = _linearize(color.green / 255);
    final b = _linearize(color.blue / 255);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize color value
  static double _linearize(double value) {
    if (value <= 0.03928) {
      return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Create a focus node with proper initial state
  static FocusNode createAccessibleFocusNode({
    String? debugLabel,
  }) {
    return FocusNode(debugLabel: debugLabel);
  }

  /// Handle keyboard shortcuts globally
  ///
  /// Common patterns:
  /// - Escape: unfocus or close
  /// - Enter: activate
  /// - Space: activate
  /// - Tab: navigate
  static KeyEventResult handleGlobalKeyPress(
    RawKeyEvent event,
    VoidCallback? onEscape,
    VoidCallback? onEnter,
    VoidCallback? onSpace,
  ) {
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      onEscape?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      onEnter?.call();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.space) {
      onSpace?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Announce navigation to screen reader
  ///
  /// Example:
  /// ```dart
  /// AccessibilityHelper.announceNavigation('Navigated to Orders');
  /// ```
  static Future<void> announceNavigation(String screenName) {
    return announceToScreenReader('Navigated to $screenName');
  }

  /// Announce error to screen reader
  static Future<void> announceError(String errorMessage) {
    return announceToScreenReader('Error: $errorMessage');
  }

  /// Announce success message
  static Future<void> announceSuccess(String message) {
    return announceToScreenReader('Success: $message');
  }

  /// Announce form field value
  static Future<void> announceFormField(String fieldName, String value) {
    return announceToScreenReader('$fieldName: $value');
  }
}

// Helper function for max
double max(double a, double b) => a > b ? a : b;

// Helper function for min
double min(double a, double b) => a < b ? a : b;

import 'package:flutter/material.dart';

/// Accessibility helper for respecting user motion preferences
class AnimationHelper {
  /// Check if user has enabled "Reduce motion" in accessibility settings
  ///
  /// On Android: Settings → Accessibility → Display → Remove animations
  /// On iOS: Settings → Accessibility → Motion → Reduce Motion
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.of(context).disableAnimations;
  }

  /// Get animation duration, respecting user preference
  ///
  /// If motion is reduced, returns Duration.zero for instant animations.
  /// Otherwise returns the normal duration.
  static Duration getDuration(
    BuildContext context,
    Duration normalDuration,
  ) {
    return shouldReduceMotion(context) ? Duration.zero : normalDuration;
  }

  /// Get animation curve, respecting user preference
  ///
  /// If motion is reduced, returns Curves.linear (no easing).
  /// Otherwise returns the normal curve.
  static Curve getCurve(BuildContext context, Curve normalCurve) {
    return shouldReduceMotion(context) ? Curves.linear : normalCurve;
  }

  /// Wraps a duration with motion preference check
  ///
  /// Useful for conditional animation setup in initState()
  static Duration respectReducedMotion(
    BuildContext context, {
    required Duration normal,
    Duration reduced = Duration.zero,
  }) {
    return shouldReduceMotion(context) ? reduced : normal;
  }
}

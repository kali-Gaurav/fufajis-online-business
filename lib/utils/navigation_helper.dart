import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safe navigation helpers to prevent GoRouter errors
class NavigationHelper {
  /// Safely pop the current route if possible
  static void safePop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      // Default fallback - go to home
      context.go('/customer/home');
    }
  }

  /// Safely pop with a result if possible
  static void safePopWithResult<T>(BuildContext context, T result) {
    if (context.canPop()) {
      context.pop(result);
    } else {
      // Default fallback - go to home (result is lost, but app doesn't crash)
      context.go('/customer/home');
    }
  }

  /// Check if we can pop
  static bool canPop(BuildContext context) => context.canPop();

  /// Safely navigate with fallback
  static void safeNavigate(BuildContext context, String route) {
    try {
      context.go(route);
    } catch (e) {
      debugPrint('Navigation error: $e');
      // Fallback to home
      context.go('/customer/home');
    }
  }
}

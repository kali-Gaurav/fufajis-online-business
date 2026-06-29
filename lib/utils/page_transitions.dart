import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';

/// Custom GoRouter Page Transitions for Fufaji's Online
class FufajiPageTransition extends CustomTransitionPage<void> {
  FufajiPageTransition({
    required super.key,
    required super.child,
    Offset slideOffset = const Offset(0.1, 0.0),
    Duration duration = AppTheme.durationMedium,
    bool useScale = false,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final CurvedAnimation curve = CurvedAnimation(
              parent: animation,
              curve: AppTheme.curveEntrance,
              reverseCurve: Curves.easeInCubic,
            );

            if (useScale) {
              return ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
                child: FadeTransition(
                  opacity: curve,
                  child: child,
                ),
              );
            }

            return SlideTransition(
              position: Tween<Offset>(
                begin: slideOffset,
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(
                opacity: curve,
                child: child,
              ),
            );
          },
        );
}

/// Specialized Slide from Bottom transition for Modals & Dialogs
class FufajiSlideUpTransition extends CustomTransitionPage<void> {
  FufajiSlideUpTransition({
    required super.key,
    required super.child,
    Duration duration = AppTheme.durationMedium,
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final CurvedAnimation curve = CurvedAnimation(
              parent: animation,
              curve: AppTheme.curveEntrance,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.15),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(
                opacity: curve,
                child: child,
              ),
            );
          },
        );
}

// ============================================================
//  Fufaji Page Transitions — complete set
//  FufajiPageTransition      : slide+fade right (standard push)
//  FufajiSlideUpTransition   : slide+fade from bottom (modals)
//  FufajiFadeScaleTransition : fade+scale (auth, overlays)
//  FufajiSharedAxisH         : horizontal shared-axis (wizards)
//  FufajiZoomTransition      : zoom from 88% (product reveal)
//  FufajiNoTransition        : instant swap (splash→home)
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'app_theme.dart';

/// Standard push — slide from right + fade
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
           final curve = CurvedAnimation(
             parent: animation,
             curve: AppTheme.curveEntrance,
             reverseCurve: Curves.easeInCubic,
           );
           if (useScale) {
             return ScaleTransition(
               scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
               child: FadeTransition(opacity: curve, child: child),
             );
           }
           return SlideTransition(
             position: Tween<Offset>(begin: slideOffset, end: Offset.zero).animate(curve),
             child: FadeTransition(opacity: curve, child: child),
           );
         },
       );
}

/// Slide from bottom — modals, checkout, bottom-heavy flows
class FufajiSlideUpTransition extends CustomTransitionPage<void> {
  FufajiSlideUpTransition({
    required super.key,
    required super.child,
    Duration duration = AppTheme.durationMedium,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curve = CurvedAnimation(
             parent: animation,
             curve: AppTheme.curveEntrance,
             reverseCurve: Curves.easeInCubic,
           );
           return SlideTransition(
             position: Tween<Offset>(
               begin: const Offset(0.0, 0.15),
               end: Offset.zero,
             ).animate(curve),
             child: FadeTransition(opacity: curve, child: child),
           );
         },
       );
}

/// Fade + gentle scale — auth screens, onboarding, role picker
class FufajiFadeScaleTransition extends CustomTransitionPage<void> {
  FufajiFadeScaleTransition({
    required super.key,
    required super.child,
    Duration duration = AppTheme.durationMedium,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           return FadeTransition(
             opacity: curved,
             child: ScaleTransition(
               scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
               child: child,
             ),
           );
         },
       );
}

/// Shared-axis horizontal — wizard steps, sequential auth screens
class FufajiSharedAxisH extends CustomTransitionPage<void> {
  FufajiSharedAxisH({
    required super.key,
    required super.child,
    bool reverse = false,
    Duration duration = AppTheme.durationMedium,
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           final begin = reverse ? const Offset(-0.08, 0) : const Offset(0.08, 0);
           return SlideTransition(
             position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
             child: FadeTransition(opacity: curved, child: child),
           );
         },
       );
}

/// Zoom from 88% — product detail reveals, celebration screens
class FufajiZoomTransition extends CustomTransitionPage<void> {
  FufajiZoomTransition({
    required super.key,
    required super.child,
    Duration duration = const Duration(milliseconds: 380),
  }) : super(
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutBack,
             reverseCurve: Curves.easeInCubic,
           );
           return FadeTransition(
             opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
             child: ScaleTransition(
               scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
               child: child,
             ),
           );
         },
       );
}

/// Instant swap — splash → home, no animation needed
class FufajiNoTransition extends CustomTransitionPage<void> {
  FufajiNoTransition({required super.key, required super.child})
    : super(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, __, ___, child) => child,
      );
}

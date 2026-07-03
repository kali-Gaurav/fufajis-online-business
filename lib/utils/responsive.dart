// ============================================================
//  Responsive Utility — Fufaji's Online
//
//  Breakpoints:
//    mobile  : width < 600
//    tablet  : 600 <= width < 1200
//    desktop : width >= 1200
//
//  Usage:
//    Responsive.isMobile(context)
//    Responsive.isTablet(context)
//    Responsive.isDesktop(context)
//    Responsive.value(context, mobile: 12.0, tablet: 16.0, desktop: 20.0)
//    Responsive.contentWidth(context)   // max content width, centred on large screens
//    Responsive.horizontalPadding(context)
// ============================================================

import 'package:flutter/material.dart';

class Responsive {
  static const double _mobileBreak = 600;
  static const double _tabletBreak = 1200;

  // ── Breakpoint checks ─────────────────────────────────────
  static bool isMobile(BuildContext context) => MediaQuery.of(context).size.width < _mobileBreak;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= _mobileBreak && w < _tabletBreak;
  }

  static bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width >= _tabletBreak;

  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _mobileBreak;

  // ── Adaptive value helper ──────────────────────────────────
  /// Returns [mobile], [tablet], or [desktop] value based on current width.
  /// Falls back: desktop → tablet → mobile if specific value is omitted.
  static T value<T>(BuildContext context, {required T mobile, T? tablet, T? desktop}) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  // ── Layout helpers ─────────────────────────────────────────

  /// Max content width — prevents over-stretching on very wide screens.
  static double contentMaxWidth(BuildContext context) =>
      value(context, mobile: double.infinity, tablet: 720, desktop: 1100);

  /// Horizontal page padding.
  static double horizontalPadding(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 32.0, desktop: 48.0);

  /// Vertical page padding.
  static double verticalPadding(BuildContext context) =>
      value(context, mobile: 16.0, tablet: 24.0, desktop: 32.0);

  /// Number of grid columns for product grids.
  static int gridColumns(BuildContext context) => value(context, mobile: 2, tablet: 3, desktop: 4);

  /// Number of grid columns for KPI cards.
  static int kpiColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 400) return 2;
    if (w < 800) return 4;
    return 6;
  }

  /// Number of grid columns for POS product grid.
  static int posColumns(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 600) return 2;
    if (w < 1000) return 3;
    if (w < 1400) return 4;
    return 6;
  }

  /// Card elevation — subtle on mobile, more pop on large screens.
  static double cardElevation(BuildContext context) =>
      value(context, mobile: 1.0, tablet: 2.0, desktop: 3.0);

  /// Font size scaler — avoids tiny text on large screens.
  static double fontScale(BuildContext context) =>
      value(context, mobile: 1.0, tablet: 1.05, desktop: 1.1);

  /// Logo size for splash / branding.
  static double logoSize(BuildContext context) =>
      value(context, mobile: 110.0, tablet: 140.0, desktop: 160.0);

  /// Icon size for navigation items.
  static double navIconSize(BuildContext context) =>
      value(context, mobile: 24.0, tablet: 26.0, desktop: 28.0);

  /// Whether to show a side NavigationRail instead of BottomNavigationBar.
  static bool useRailNav(BuildContext context) => isTabletOrDesktop(context);

  /// Width of the NavigationRail drawer on tablet/desktop.
  static double railWidth(BuildContext context) =>
      value(context, mobile: 0, tablet: 72, desktop: 200);

  /// Extended rail (shows labels) on desktop.
  static bool extendedRail(BuildContext context) => isDesktop(context);
}

// ── Responsive wrapper widget ──────────────────────────────
/// Centres content on large screens with a max width and symmetric padding.
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsivePage({super.key, required this.child, this.maxWidth, this.padding});

  @override
  Widget build(BuildContext context) {
    final effectiveMax = maxWidth ?? Responsive.contentMaxWidth(context);
    final effectivePad =
        padding ??
        EdgeInsets.symmetric(
          horizontal: Responsive.horizontalPadding(context),
          vertical: Responsive.verticalPadding(context),
        );

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMax),
        child: Padding(padding: effectivePad, child: child),
      ),
    );
  }
}

// ── Responsive layout builder ──────────────────────────────
/// Renders different widgets for mobile / tablet / desktop.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({super.key, required this.mobile, this.tablet, this.desktop});

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (Responsive.isTablet(context)) return tablet ?? mobile;
    return mobile;
  }
}

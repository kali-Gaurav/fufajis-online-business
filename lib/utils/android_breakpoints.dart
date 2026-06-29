/// Android responsive design breakpoints
///
/// Standard Android screen widths (in density-independent pixels - dp)
/// Used to determine layout strategy across all screens
library;

class AndroidBreakpoints {
  // Device screen width classifications
  /// Small phone (e.g., iPhone SE, Galaxy A12) — 360dp baseline
  static const double smallPhone = 360.0;

  /// Normal phone (e.g., Pixel 5, iPhone 12) — 411dp baseline
  static const double normalPhone = 411.0;

  /// Large phone (e.g., OnePlus 9, Galaxy S21) — 480dp baseline
  static const double largePhone = 480.0;

  /// Tablet small (e.g., iPad Mini, Samsung Tab S6 Lite) — 600dp
  static const double tabletSmall = 600.0;

  /// Tablet large (e.g., iPad, Samsung Tab S6) — 960dp
  static const double tabletLarge = 960.0;

  /// Desktop / very large tablet (e.g., 2-in-1 tablets)
  static const double desktop = 1200.0;

  // Safe usable width (accounting for navigation bar, padding)
  /// Usable width on phones (minus safe areas)
  static const double usablePhoneWidth = 360.0;

  /// Usable width on tablets (minus safe areas)
  static const double usableTabletWidth = 600.0;

  /// Max content width (for desktop, prevents super-wide layouts)
  static const double maxContentWidth = 800.0;

  // Device type detection helpers
  /// Returns true if screen is small phone (<400dp)
  static bool isSmallPhone(double width) => width < 400;

  /// Returns true if screen is normal phone (400-480dp)
  static bool isNormalPhone(double width) => width >= 400 && width < 600;

  /// Returns true if screen is large phone (480-600dp)
  static bool isLargePhone(double width) => width >= 480 && width < 600;

  /// Returns true if screen is tablet (600-960dp)
  static bool isTablet(double width) => width >= 600 && width < 960;

  /// Returns true if screen is large tablet or desktop (960dp+)
  static bool isLargeScreen(double width) => width >= 960;

  // Grid column helpers
  /// Get optimal grid column count based on screen width
  /// Returns 2 for phones, 3 for tablets, 4+ for desktop
  static int getGridColumns(double width) {
    if (width < 600) return 2;      // Phone: 2 columns
    if (width < 960) return 3;      // Tablet: 3 columns
    if (width < 1440) return 4;     // Desktop: 4 columns
    return 5;                        // Large desktop: 5 columns
  }

  /// Get optimal grid columns for product display
  /// Returns 2 for phones, 3 for tablets, 4-5 for desktop
  static int getProductGridColumns(double width) {
    if (width < 600) return 2;      // Phone
    if (width < 960) return 3;      // Tablet
    if (width < 1440) return 4;     // Desktop
    return 5;                        // Large desktop
  }

  /// Get responsive padding based on screen width
  /// Tighter on mobile, more breathing room on tablet/desktop
  static double getResponsivePadding(double width) {
    if (width < 600) return 12.0;   // Phone: 12dp
    if (width < 960) return 16.0;   // Tablet: 16dp
    return 24.0;                    // Desktop: 24dp
  }

  /// Get responsive padding for cards
  static double getCardPadding(double width) {
    if (width < 600) return 12.0;
    if (width < 960) return 14.0;
    return 16.0;
  }

  /// Get responsive spacing between elements
  static double getResponsiveSpacing(double width) {
    if (width < 600) return 8.0;    // Phone: 8dp
    if (width < 960) return 12.0;   // Tablet: 12dp
    return 16.0;                    // Desktop: 16dp
  }

  /// Get responsive font size for body text
  static double getResponsiveBodySize(double width) {
    if (width < 600) return 14.0;   // Phone: 14pt
    if (width < 960) return 14.0;   // Tablet: 14pt
    return 16.0;                    // Desktop: 16pt
  }

  /// Get responsive font size for headings
  static double getResponsiveHeadingSize(double width) {
    if (width < 600) return 18.0;   // Phone: 18pt
    if (width < 960) return 20.0;   // Tablet: 20pt
    return 24.0;                    // Desktop: 24pt
  }
}

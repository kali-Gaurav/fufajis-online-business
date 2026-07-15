import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors (Warm Sunset Orange & Cream White)
  static const Color primary = Color(0xFFFF8C42); // Brand Orange
  static const Color primaryDark = Color(0xFFE56F1F); // Darker Orange
  static const Color primaryLight = Color(0xFFFFE5D0); // Light Orange
  static const Color cream = Color(0xFFFFF8F2); // Cream Background
  static const Color sand = Color(0xFFFAECE3); // Sand Surface
  static const Color secondary = Color(0xFFFFF5F0); // Legacy/Off-white
  static const Color secondaryDark = Color(0xFFF5F0E8); // Legacy/Slightly darker off-white
  static const Color secondaryLight = Color(0xFFFFFFFF); // Legacy/Pure white

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF1F2937); // Text Dark

  // Status Colors
  static const Color success = Color(0xFF22C55E); // Green
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color error = Color(0xFFEF4444); // Red
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color primaryColor = primary;
  static const Color errorColor = error;
  static const Color ownerColor = info;
  static const Color deliveryColor = success;

  static const Color infoGrey = grey500;
  static const Color ownerAccentGrey = grey600;

  // Animation Constants & Curves
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 350);
  static const Duration durationSlow = Duration(milliseconds: 500);

  static const Curve curveDefault = Curves.easeInOut;
  static const Curve curveEntrance = Curves.easeOutCubic;
  static const Curve curveBounce = Curves.elasticOut;

  static FestiveSeason activeFestiveSeason = FestiveSeason.none;

  static const Map<FestiveSeason, FestiveThemeConfig> festiveConfigs = {
    FestiveSeason.diwali: FestiveThemeConfig(
      primary: Color(0xFFFF9900), // Marigold Golden Yellow
      primaryDark: Color(0xFFE65100), // Deep Clay Diya Orange
      primaryLight: Color(0xFFFFF3E0),
      cream: Color(0xFFFFFDF9),
      sand: Color(0xFFFFF3E0),
      tagline: 'Happy Diwali! • शुभ दीपावली! 🪔',
    ),
    FestiveSeason.eid: FestiveThemeConfig(
      primary: Color(0xFF0F766E), // Emerald Green
      primaryDark: Color(0xFF115E59), // Deep Teal
      primaryLight: Color(0xFFCCFBF1),
      cream: Color(0xFFF0FDF4),
      sand: Color(0xFFDCFCE7),
      tagline: 'Eid Mubarak! • ईद मुबारक! 🌙',
    ),
    FestiveSeason.independence: FestiveThemeConfig(
      primary: Color(0xFFFF9933), // Saffron
      primaryDark: Color(0xFF138808), // Green
      primaryLight: Color(0xFFE8F5E9),
      cream: Color(0xFFF5F5F5), // White
      sand: Color(0xFFE3F2FD), // Navy blue hint
      tagline: 'Happy Independence Day! 🇮🇳',
    ),
  };

  static FestiveThemeConfig get currentConfig {
    return festiveConfigs[activeFestiveSeason] ??
        const FestiveThemeConfig(
          primary: primary,
          primaryDark: primaryDark,
          primaryLight: primaryLight,
          cream: cream,
          sand: sand,
        );
  }

  // ─── Deep-orange accent palette ──────────────────────────────────────────────
  static const Color deepOrange = Color(0xFFFF6B00);
  static const Color vibrantOrange = Color(0xFFFF8C42);
  static const Color softOrange = Color(0xFFFFAB72);
  static const Color warmOrange = Color(0xFFFFD4A8);

  // Gradients
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [currentConfig.primary, currentConfig.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A110B), Color(0xFF2D1F14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get heroGradient => LinearGradient(
    colors: [
      currentConfig.primary,
      Color.lerp(currentConfig.primary, currentConfig.primaryLight, 0.3) ?? currentConfig.primary,
      currentConfig.primaryDark,
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: const [0.0, 0.6, 1.0],
  );

  // Premium splash gradient — deep-to-vibrant orange diagonal
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B00), Color(0xFFFF8C42), Color(0xFFE55B00)],
    stops: [0.0, 0.55, 1.0],
  );

  // Auth/login hero gradient
  static const LinearGradient heroGradientFixed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B00), Color(0xFFFF9140), Color(0xFFE55B00)],
    stops: [0.0, 0.60, 1.0],
  );

  static LinearGradient get authGradient => LinearGradient(
    colors: [currentConfig.cream, currentConfig.primaryLight],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient get cardGlowGradient => LinearGradient(
    colors: [currentConfig.primary, currentConfig.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Subtle warm card gradient for premium tiles
  static const LinearGradient warmCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFF8F2), Color(0xFFFFF0E0)],
  );

  // Rich elevated button gradient
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
  );

  // Light Theme
  static ThemeData get lightTheme {
    final config = currentConfig;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: config.primary,
        primary: config.primary,
        secondary: secondary,
        surface: config.cream, // Cream Background
        error: error,
      ),
      fontFamily: 'Poppins',
      textTheme: GoogleFonts.poppinsTextTheme(),
      scaffoldBackgroundColor: config.cream, // Warm background
      appBarTheme: AppBarTheme(
        backgroundColor: config.cream,
        foregroundColor: grey900,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: config.sand, // Sand Surface for cards
        elevation: 1,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)), // 16dp rounded corners
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: config.primary,
          foregroundColor: white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: config.primary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: config.primary, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: grey300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: grey300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: config.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: grey600),
        hintStyle: const TextStyle(color: grey400),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: config.primary,
        unselectedItemColor: grey400,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: grey100,
        selectedColor: config.primaryLight,
        labelStyle: const TextStyle(color: grey700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
    );
  }

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: primary,
      secondary: secondary,
      surface: const Color(0xFF1E1E1E),
      error: error,
      onSurface: white,
    ),
    fontFamily: 'Poppins',
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: white,
      displayColor: white,
      decorationColor: white,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1E1E1E),
      elevation: 4,
      margin: EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: const BorderSide(color: Color(0xFF404040), width: 1.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: grey400),
      hintStyle: const TextStyle(color: grey600),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF121212),
      selectedItemColor: primary,
      unselectedItemColor: grey600,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // Custom Colors for Categories
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

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(spacingXs);
  static const EdgeInsets paddingSm = EdgeInsets.all(spacingSm);
  static const EdgeInsets paddingMd = EdgeInsets.all(spacingMd);
  static const EdgeInsets paddingLg = EdgeInsets.all(spacingLg);
  static const EdgeInsets paddingXl = EdgeInsets.all(spacingXl);

  static const SizedBox gap4 = SizedBox(height: spacingXs, width: spacingXs);
  static const SizedBox gap8 = SizedBox(height: spacingSm, width: spacingSm);
  static const SizedBox gap12 = SizedBox(height: 12, width: 12);
  static const SizedBox gap16 = SizedBox(height: spacingMd, width: spacingMd);
  static const SizedBox gap24 = SizedBox(height: spacingLg, width: spacingLg);
  static const SizedBox gap32 = SizedBox(height: spacingXl, width: spacingXl);

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Shadows
  static const List<BoxShadow> cardShadows = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x05000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> elevatedCardShadows = [
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x08000000), blurRadius: 40, offset: Offset(0, 12)),
  ];

  static List<BoxShadow> primaryGlowShadows({double intensity = 1.0}) => [
    BoxShadow(
      color: primary.withOpacity(0.35 * intensity),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: primary.withOpacity(0.15 * intensity),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];

  // ─── Card decorations ─────────────────────────────────────────────────────
  static BoxDecoration get premiumCardDecoration => const BoxDecoration(
    color: white,
    borderRadius: BorderRadius.all(Radius.circular(radiusLg)),
    boxShadow: elevatedCardShadows,
  );

  static BoxDecoration get orangeCardDecoration => BoxDecoration(
    gradient: buttonGradient,
    borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
    boxShadow: primaryGlowShadows(),
  );

  static BoxDecoration get softOrangeCardDecoration => BoxDecoration(
    color: primaryLight.withOpacity(0.35),
    borderRadius: const BorderRadius.all(Radius.circular(radiusLg)),
    border: Border.all(color: primary.withOpacity(0.18)),
  );

  // Text Styles
  static TextStyle displayLarge(BuildContext context) => GoogleFonts.poppins(
    fontSize: 57,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle displayMedium(BuildContext context) => GoogleFonts.poppins(
    fontSize: 45,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle displaySmall(BuildContext context) => GoogleFonts.poppins(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle headlineLarge(BuildContext context) => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle headlineMedium(BuildContext context) => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle headlineSmall(BuildContext context) => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle titleLarge(BuildContext context) => GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle titleMedium(BuildContext context) => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle titleSmall(BuildContext context) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle bodyLarge(BuildContext context) => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle bodyMedium(BuildContext context) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle labelLarge(BuildContext context) => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle labelMedium(BuildContext context) => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
  );

  static TextStyle labelSmall(BuildContext context) => GoogleFonts.poppins(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: Theme.of(context).colorScheme.onSurface,
  );

  // ─── Glassmorphism helpers ────────────────────────────────────────────────────
  static BoxDecoration glassDecoration({
    Color tint = const Color(0x18FFFFFF),
    double borderRadius = 20,
    Color borderColor = const Color(0x33FFFFFF),
  }) {
    return BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static Widget glassMorphic({
    required Widget child,
    double borderRadius = 20,
    double blur = 12,
    Color tint = const Color(0x18FFFFFF),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: glassDecoration(borderRadius: borderRadius, tint: tint),
          child: child,
        ),
      ),
    );
  }

  // ─── Role-specific brand colors ───────────────────────────────────────────────
  static const Color customerAccent = primary;
  static const Color ownerAccent = Color(0xFF1E3A8A); // Warm/Dark Indigo/Blue
  static const Color deliveryAccent = Color(0xFF15803D); // Warm Forest Green
  static const Color employeeAccent = Color(0xFF701A75); // Warm Plum Purple
  static const Color adminAccent = Color(0xFFB91C1C); // Warm Crimson Red

  // ─── Additional UI Properties ─────────────────────────────────────────────────
  static const Color textPrimary = grey900;
  static const Color background = cream;
  static const Color warningColor = warning;

  // ─── Shimmer colors ───────────────────────────────────────────────────────────
  static const Color shimmerBase = sand;
  static const Color shimmerHighlight = cream;

  static Color statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('delivered') || s.contains('completed')) return success;
    if (s.contains('cancel')) return error;
    if (s.contains('pending') || s.contains('placed')) return warning;
    if (s.contains('confirmed') || s.contains('preparing')) return info;
    if (s.contains('out') || s.contains('transit')) return primaryLight;
    return grey500;
  }

  static String statusEmoji(String status) {
    final s = status.toLowerCase();
    if (s.contains('delivered')) return '✅';
    if (s.contains('cancel')) return '❌';
    if (s.contains('pending') || s.contains('placed')) return '🕐';
    if (s.contains('confirmed')) return '✓';
    if (s.contains('preparing') || s.contains('packing')) return '📦';
    if (s.contains('out') || s.contains('transit')) return '🚚';
    return '🔄';
  }
}

enum FestiveSeason { none, diwali, eid, independence }

class FestiveThemeConfig {
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color cream;
  final Color sand;
  final String? tagline;

  const FestiveThemeConfig({
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.cream,
    required this.sand,
    this.tagline,
  });
}

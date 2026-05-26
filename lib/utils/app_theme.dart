import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFFFF5722);
  static const Color primaryDark = Color(0xFFE64A19);
  static const Color primaryLight = Color(0xFFFF8A65);
  static const Color secondary = Color(0xFF4CAF50);
  static const Color secondaryDark = Color(0xFF388E3C);
  static const Color secondaryLight = Color(0xFF81C784);

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
  static const Color grey900 = Color(0xFF212121);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  static const Color primaryColor = primary;
  static const Color errorColor = error;
  static const Color ownerColor = info;
  static const Color deliveryColor = secondary;

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: white,
      error: error,
    ),
    fontFamily: 'Poppins',
    textTheme: GoogleFonts.poppinsTextTheme(),
    scaffoldBackgroundColor: grey50,
    appBarTheme: const AppBarTheme(
      backgroundColor: white,
      foregroundColor: grey900,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: white,
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(color: primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: grey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: grey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: grey600),
      hintStyle: const TextStyle(color: grey400),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: white,
      selectedItemColor: primary,
      unselectedItemColor: grey500,
      type: BottomNavigationBarType.fixed,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: grey100,
      selectedColor: primary,
      labelStyle: const TextStyle(color: grey700),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: grey900,
      error: error,
      surfaceContainerHighest: grey800,
    ),
    fontFamily: 'Poppins',
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: white,
      displayColor: white,
    ),
    scaffoldBackgroundColor: grey800,
    appBarTheme: const AppBarTheme(
      backgroundColor: grey900,
      foregroundColor: white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: const CardThemeData(
      color: grey800,
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(color: primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: grey800,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: grey600),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: grey600),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: grey400),
      hintStyle: const TextStyle(color: grey500),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: grey900,
      selectedItemColor: primary,
      unselectedItemColor: grey500,
      type: BottomNavigationBarType.fixed,
    ),
  );

  // Custom Colors for Categories
  static const Map<String, Color> categoryColors = {
    'groceries': Color(0xFF4CAF50),
    'vegetables': Color(0xFF8BC34A),
    'fruits': Color(0xFFFF9800),
    'dairy': Color(0xFFFFEB3B),
    'bakery': Color(0xFF795548),
    'snacks': Color(0xFFFF5722),
    'beverages': Color(0xFF03A9F4),
    'household': Color(0xFF607D8B),
    'personalCare': Color(0xFFE91E63),
    'electronics': Color(0xFF2196F3),
    'clothing': Color(0xFF9C27B0),
    'footwear': Color(0xFF673AB7),
    'homeDecor': Color(0xFF009688),
    'kitchenware': Color(0xFFFF5722),
    'stationery': Color(0xFF607D8B),
    'toys': Color(0xFFFFEB3B),
    'medicines': Color(0xFFF44336),
    'agricultural': Color(0xFF8BC34A),
    'other': Color(0xFF9E9E9E),
  };

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;

  // Border Radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0;

  // Shadows
  static const List<BoxShadow> cardShadows = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  // Text Styles
  static TextStyle displayLarge(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle displayMedium(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle displaySmall(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle headlineLarge(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle headlineMedium(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle headlineSmall(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle titleLarge(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle titleMedium(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle titleSmall(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle bodyLarge(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle bodyMedium(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle bodySmall(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle labelLarge(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle labelMedium(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );

  static TextStyle labelSmall(BuildContext context) =>
      GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurface,
      );
}

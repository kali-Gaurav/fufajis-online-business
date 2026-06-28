import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeType { system, light, dark }

class ThemeProvider with ChangeNotifier {
  ThemeModeType _themeMode = ThemeModeType.system;
  Locale _locale = const Locale('en');
  SharedPreferences? _prefs;

  ThemeModeType get themeMode => _themeMode;
  Locale get locale => _locale;

  ThemeProvider(SharedPreferences prefs) {
    _prefs = prefs;
    final savedMode = prefs.getString('themeMode');
    if (savedMode != null) {
      _themeMode = ThemeModeType.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => ThemeModeType.system,
      );
    }

    // Load saved locale
    final savedLocale = prefs.getString('appLocale');
    if (savedLocale != null) {
      try {
        final parts = savedLocale.split('_');
        _locale = parts.length > 1
            ? Locale(parts[0], parts[1])
            : Locale(parts[0]);
      } catch (e) {
        _locale = const Locale('en');
      }
    }
  }

  void setThemeMode(ThemeModeType mode) {
    _themeMode = mode;
    notifyListeners();
    _saveThemeMode();
  }

  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeMode.toString());
  }

  void toggleTheme() {
    switch (_themeMode) {
      case ThemeModeType.system:
        _themeMode = ThemeModeType.light;
        break;
      case ThemeModeType.light:
        _themeMode = ThemeModeType.dark;
        break;
      case ThemeModeType.dark:
        _themeMode = ThemeModeType.system;
        break;
    }
    notifyListeners();
    _saveThemeMode();
  }

  /// Sets the app locale/language
  Future<void> setLocale(Locale newLocale) async {
    _locale = newLocale;
    notifyListeners();

    // Save to SharedPreferences
    if (_prefs != null) {
      final localeString = newLocale.countryCode != null
          ? '${newLocale.languageCode}_${newLocale.countryCode}'
          : newLocale.languageCode;
      await _prefs!.setString('appLocale', localeString);
    }
  }

  /// Gets the current language code
  String get languageCode => _locale.languageCode;

  /// Toggles between supported languages
  Future<void> toggleLanguage() async {
    final newLocale = _locale.languageCode == 'en'
        ? const Locale('hi')  // English to Hindi
        : const Locale('en'); // Hindi to English
    await setLocale(newLocale);
  }
}

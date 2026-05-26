import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeModeType { system, light, dark }

class ThemeProvider with ChangeNotifier {
  ThemeModeType _themeMode = ThemeModeType.system;
  ThemeModeType get themeMode => _themeMode;

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  ThemeProvider(SharedPreferences prefs) {
    final savedMode = prefs.getString('themeMode');
    if (savedMode != null) {
      _themeMode = ThemeModeType.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => ThemeModeType.system,
      );
    }

    final savedLocale = prefs.getString('locale');
    if (savedLocale != null) {
      _locale = Locale(savedLocale);
    }
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
    _saveLocale();
  }

  Future<void> _saveLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale', _locale.languageCode);
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
}

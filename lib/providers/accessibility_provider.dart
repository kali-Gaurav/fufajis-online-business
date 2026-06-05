import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AccessibilityProvider manages elderly/simple mode settings.
///
/// Persisted via SharedPreferences so it survives app restarts.
///
/// Features:
///   - isElderlyMode: enables large buttons, simplified navigation, Hindi labels
///   - fontScale: 1.0 (normal) to 1.6 (extra large) for text scaling
///   - preferredLanguage: 'en' or 'hi' for label switching
///   - highContrast: increases border/shadow intensity for better visibility
class AccessibilityProvider extends ChangeNotifier {
  static const String _elderlyModeKey = 'elderly_mode';
  static const String _fontScaleKey = 'font_scale';
  static const String _languageKey = 'preferred_language';
  static const String _highContrastKey = 'high_contrast';

  bool _isElderlyMode = false;
  double _fontScale = 1.0;
  String _preferredLanguage = 'en';
  bool _highContrast = false;
  bool _isInitialized = false;

  // Getters
  bool get isElderlyMode => _isElderlyMode;
  double get fontScale => _fontScale;
  String get preferredLanguage => _preferredLanguage;
  bool get highContrast => _highContrast;
  bool get isInitialized => _isInitialized;
  bool get isHindi => _preferredLanguage == 'hi';

  /// Computed text scale for MediaQuery override
  double get effectiveFontScale => _isElderlyMode ? _fontScale : 1.0;

  /// Computed button height for elderly-accessible tap targets
  double get minTapTargetSize => _isElderlyMode ? 56.0 : 44.0;

  /// Maximum items to show per section in elderly mode (reduce clutter)
  int get maxSectionItems => _isElderlyMode ? 6 : 20;

  /// Icon size multiplier for elderly mode
  double get iconScale => _isElderlyMode ? 1.4 : 1.0;

  AccessibilityProvider() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isElderlyMode = prefs.getBool(_elderlyModeKey) ?? false;
      _fontScale =
          prefs.getDouble(_fontScaleKey) ?? (_isElderlyMode ? 1.3 : 1.0);
      _preferredLanguage = prefs.getString(_languageKey) ?? 'en';
      _highContrast = prefs.getBool(_highContrastKey) ?? false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Toggle elderly mode on/off with smart defaults
  Future<void> setElderlyMode(bool enabled) async {
    _isElderlyMode = enabled;

    // Auto-adjust related settings when toggling
    if (enabled) {
      if (_fontScale < 1.3) _fontScale = 1.3;
      if (_preferredLanguage == 'en') {
        _preferredLanguage = 'hi'; // default to Hindi for elderly
      }
      _highContrast = true;
    } else {
      _fontScale = 1.0;
      _highContrast = false;
    }

    await _savePreferences();
    notifyListeners();
  }

  /// Set font scale (1.0 - 1.6)
  Future<void> setFontScale(double scale) async {
    _fontScale = scale.clamp(0.8, 1.6);
    await _savePreferences();
    notifyListeners();
  }

  /// Set preferred language ('en' or 'hi')
  Future<void> setPreferredLanguage(String lang) async {
    _preferredLanguage = lang;
    await _savePreferences();
    notifyListeners();
  }

  /// Toggle high contrast mode
  Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    await _savePreferences();
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_elderlyModeKey, _isElderlyMode);
      await prefs.setDouble(_fontScaleKey, _fontScale);
      await prefs.setString(_languageKey, _preferredLanguage);
      await prefs.setBool(_highContrastKey, _highContrast);
    } catch (e) {
      debugPrint('[AccessibilityProvider] Save error: $e');
    }
  }

  /// Get localized label — returns Hindi or English based on preference
  String label({required String en, required String hi}) {
    return _preferredLanguage == 'hi' ? hi : en;
  }
}

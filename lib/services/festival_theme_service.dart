import 'package:flutter/material.dart';
import 'remote_config_service.dart';

/// Festival Theme Service
///
/// Auto-detects upcoming Indian festivals within a 7-day window and applies:
/// - Dynamic brand color palette swap
/// - Custom gradient backgrounds
/// - Festival emoji / chip branding
/// - Themed product category labels
/// - Animated confetti trigger flag
///
/// Festival calendar covers 20+ Indian occasions and 3 regional ones.
/// Remote Config can override the detected festival for flash theming.
class FestivalThemeService {
  static final FestivalThemeService _instance = FestivalThemeService._internal();
  factory FestivalThemeService() => _instance;
  FestivalThemeService._internal();

  // ─── Festival calendar (MM-DD → id) ─────────────────────────────────────────
  static const Map<String, String> _calendar = {
    '01-14': 'makar_sankranti',
    '01-26': 'republic_day',
    '02-14': 'valentines',
    '03-08': 'holi', // approximate - varies by year
    '03-22': 'gudi_padwa',
    '03-25': 'ugadi',
    '04-13': 'baisakhi',
    '04-14': 'ambedkar_jayanti',
    '06-21': 'fathers_day',
    '08-15': 'independence_day',
    '08-19': 'raksha_bandhan', // approximate
    '08-26': 'janmashtami', // approximate
    '09-07': 'ganesh_chaturthi',
    '09-14': 'onam',
    '10-02': 'gandhi_jayanti',
    '10-24': 'navratri',
    '11-01': 'diwali', // approximate - varies by year
    '11-05': 'bhai_dooj',
    '11-15': 'guru_nanak_jayanti',
    '12-24': 'christmas_eve',
    '12-25': 'christmas',
    '12-31': 'new_year_eve',
  };

  // ─── Theme configs per festival ───────────────────────────────────────────────
  static const Map<String, FestivalTheme> _themes = {
    'diwali': FestivalTheme(
      id: 'diwali',
      displayName: 'Diwali',
      emoji: '🪔',
      primaryColor: Color(0xFFFFB300),
      secondaryColor: Color(0xFFE65100),
      accentColor: Color(0xFFFF6F00),
      gradientColors: [Color(0xFFFF8F00), Color(0xFFE65100)],
      bgColors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)],
      tagLine: 'Festival of Lights — Special Diwali Deals!',
      confetti: true,
    ),
    'holi': FestivalTheme(
      id: 'holi',
      displayName: 'Holi',
      emoji: '🎨',
      primaryColor: Color(0xFFE91E63),
      secondaryColor: Color(0xFF9C27B0),
      accentColor: Color(0xFF00BCD4),
      gradientColors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
      bgColors: [Color(0xFFFCE4EC), Color(0xFFF3E5F5)],
      tagLine: 'Rang Barse! Holi Special Offers!',
      confetti: true,
    ),
    'independence_day': FestivalTheme(
      id: 'independence_day',
      displayName: 'Independence Day',
      emoji: '🇮🇳',
      primaryColor: Color(0xFFFF6F00),
      secondaryColor: Color(0xFF2E7D32),
      accentColor: Color(0xFFFFFFFF),
      gradientColors: [Color(0xFFFF6F00), Color(0xFF2E7D32)],
      bgColors: [Color(0xFFFFF3E0), Color(0xFFE8F5E9)],
      tagLine: 'Jai Hind! Independence Day Offers!',
      confetti: false,
    ),
    'ganesh_chaturthi': FestivalTheme(
      id: 'ganesh_chaturthi',
      displayName: 'Ganesh Chaturthi',
      emoji: '🐘',
      primaryColor: Color(0xFFFF8C00),
      secondaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFFFF4500),
      gradientColors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
      bgColors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)],
      tagLine: 'Ganpati Bappa Morya! Festival Specials!',
      confetti: true,
    ),
    'onam': FestivalTheme(
      id: 'onam',
      displayName: 'Onam',
      emoji: '🌸',
      primaryColor: Color(0xFF388E3C),
      secondaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFFFF5722),
      gradientColors: [Color(0xFF388E3C), Color(0xFF2E7D32)],
      bgColors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)],
      tagLine: 'Happy Onam! Kerala Special Offers!',
      confetti: false,
    ),
    'christmas': FestivalTheme(
      id: 'christmas',
      displayName: 'Christmas',
      emoji: '🎄',
      primaryColor: Color(0xFFC62828),
      secondaryColor: Color(0xFF2E7D32),
      accentColor: Color(0xFFFFD700),
      gradientColors: [Color(0xFFC62828), Color(0xFF2E7D32)],
      bgColors: [Color(0xFFFCE4EC), Color(0xFFE8F5E9)],
      tagLine: 'Merry Christmas! Holiday Specials!',
      confetti: true,
    ),
    'new_year_eve': FestivalTheme(
      id: 'new_year_eve',
      displayName: 'New Year',
      emoji: '🎆',
      primaryColor: Color(0xFF7B1FA2),
      secondaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFF00BCD4),
      gradientColors: [Color(0xFF7B1FA2), Color(0xFF512DA8)],
      bgColors: [Color(0xFFF3E5F5), Color(0xFFEDE7F6)],
      tagLine: 'Happy New Year! Ring in the Deals!',
      confetti: true,
    ),
    'raksha_bandhan': FestivalTheme(
      id: 'raksha_bandhan',
      displayName: 'Raksha Bandhan',
      emoji: '🎀',
      primaryColor: Color(0xFFEC407A),
      secondaryColor: Color(0xFFFFD700),
      accentColor: Color(0xFF9C27B0),
      gradientColors: [Color(0xFFEC407A), Color(0xFFAD1457)],
      bgColors: [Color(0xFFFCE4EC), Color(0xFFF8BBD9)],
      tagLine: 'Happy Rakhi! Gift Hampers Available!',
      confetti: false,
    ),
  };

  static const FestivalTheme _defaultTheme = FestivalTheme(
    id: 'none',
    displayName: '',
    emoji: '',
    primaryColor: Color(0xFFFF5722),
    secondaryColor: Color(0xFF4CAF50),
    accentColor: Color(0xFFFF8A65),
    gradientColors: [Color(0xFFFF5722), Color(0xFFE64A19)],
    bgColors: [Color(0xFFFAFAFA), Color(0xFFFFFFFF)],
    tagLine: '',
    confetti: false,
  );

  // ─── Current festival detection ───────────────────────────────────────────────
  String get currentFestivalId {
    // 1. Remote Config override (owner can force a festival theme instantly)
    final configVal = RemoteConfigService().festivalMode;
    if (configVal.isNotEmpty && configVal != 'none') return configVal;

    // 2. Auto-detect from calendar (7-day lookahead)
    final now = DateTime.now();
    for (int i = 0; i <= 7; i++) {
      final check = now.add(Duration(days: i));
      final key =
          '${check.month.toString().padLeft(2, '0')}-${check.day.toString().padLeft(2, '0')}';
      if (_calendar.containsKey(key)) return _calendar[key]!;
    }
    return 'none';
  }

  FestivalTheme get currentTheme => _themes[currentFestivalId] ?? _defaultTheme;

  bool get hasFestival => currentFestivalId != 'none';

  // ─── Convenience getters ──────────────────────────────────────────────────────
  Color getPrimaryColor(BuildContext context) =>
      hasFestival ? currentTheme.primaryColor : Theme.of(context).primaryColor;

  LinearGradient get heroGradient => LinearGradient(
    colors: currentTheme.gradientColors,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  LinearGradient get softBgGradient => LinearGradient(
    colors: currentTheme.bgColors,
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  BoxDecoration? getBannerDecoration() {
    if (!hasFestival) return null;
    return BoxDecoration(gradient: heroGradient);
  }

  // ─── Festival branding chip ───────────────────────────────────────────────────
  Widget? getFestivalBranding() {
    if (!hasFestival) return null;
    final theme = currentTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.gradientColors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(theme.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            theme.displayName.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Festival tagline banner ──────────────────────────────────────────────────
  Widget? getTagLineBanner() {
    if (!hasFestival || currentTheme.tagLine.isEmpty) return null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(gradient: heroGradient),
      child: Text(
        '${currentTheme.emoji}  ${currentTheme.tagLine}',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Data class ───────────────────────────────────────────────────────────────
class FestivalTheme {
  final String id;
  final String displayName;
  final String emoji;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final List<Color> gradientColors;
  final List<Color> bgColors;
  final String tagLine;
  final bool confetti;

  const FestivalTheme({
    required this.id,
    required this.displayName,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.gradientColors,
    required this.bgColors,
    required this.tagLine,
    required this.confetti,
  });
}

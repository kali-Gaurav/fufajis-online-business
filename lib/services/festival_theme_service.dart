import 'package:flutter/material.dart';
import 'remote_config_service.dart';

class FestivalThemeService {
  static final FestivalThemeService _instance = FestivalThemeService._internal();
  factory FestivalThemeService() => _instance;
  FestivalThemeService._internal();

  /// Localized calendar of Indian festivals mapping (MM-DD)
  static const Map<String, String> _festivalDates = {
    '01-14': 'makar_sankranti',
    '03-10': 'holi',
    '08-15': 'independence_day',
    '10-30': 'diwali',
    '12-25': 'christmas',
  };

  /// Auto detects if there is an upcoming festival within 7 days
  String get currentFestival {
    // 1. Try remote config override first
    final configVal = RemoteConfigService().festivalMode;
    if (configVal != 'none' && configVal.isNotEmpty) {
      return configVal;
    }

    // 2. Check local calendar auto triggers
    final now = DateTime.now();
    for (int i = 0; i <= 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final monthStr = checkDate.month.toString().padLeft(2, '0');
      final dayStr = checkDate.day.toString().padLeft(2, '0');
      final key = '$monthStr-$dayStr';
      if (_festivalDates.containsKey(key)) {
        return _festivalDates[key]!;
      }
    }

    return 'none';
  }

  /// Returns a primary color based on the active festival
  Color getFestivalPrimaryColor(BuildContext context) {
    switch (currentFestival) {
      case 'holi':
        return Colors.pinkAccent;
      case 'diwali':
        return Colors.amber[700]!;
      case 'independence_day':
        return Colors.orange[800]!;
      case 'christmas':
        return Colors.red[700]!;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  /// Returns a background decoration for the home page based on the festival
  BoxDecoration? getFestivalBackgroundDecoration() {
    switch (currentFestival) {
      case 'diwali':
        return const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1506784983877-45594efa4cbe?w=400'),
            repeat: ImageRepeat.repeat,
            opacity: 0.1,
          ),
        );
      case 'holi':
        return BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.pink.withValues(alpha: 0.1), Colors.blue.withValues(alpha: 0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        );
      default:
        return null;
    }
  }

  /// Returns a specific festival icon or asset
  Widget? getFestivalBranding() {
    if (currentFestival == 'none') return null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Chip(
        label: Text(
          currentFestival.replaceAll('_', ' ').toUpperCase(),
          style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

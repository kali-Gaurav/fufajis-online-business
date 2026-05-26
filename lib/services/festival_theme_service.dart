import 'package:flutter/material.dart';
import 'remote_config_service.dart';

class FestivalThemeService {
  static final FestivalThemeService _instance = FestivalThemeService._internal();
  factory FestivalThemeService() => _instance;
  FestivalThemeService._internal();

  /// Gets the current active festival mode from Remote Config
  String get currentFestival => RemoteConfigService().festivalMode;

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
            image: NetworkImage('https://example.com/diwali_pattern.png'),
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

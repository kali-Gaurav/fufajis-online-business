import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Runtime Configuration Service
///
/// Loads safe application configuration from the backend at startup.
/// This ensures secrets (like RAZORPAY_KEY_SECRET) are NEVER embedded in the APK.
///
/// Flow:
/// 1. App starts
/// 2. Flutter loads default config from build environment
/// 3. RuntimeConfigService.load() fetches fresh config from /config/app-config
/// 4. Merges with defaults, storing in memory
/// 5. All app code uses RuntimeConfig instead of AppConfig
///
/// Example Usage:
/// ```dart
/// void main() async {
///   // Load runtime config before initializing app
///   await RuntimeConfigService.instance.load();
///   runApp(MyApp());
/// }
///
/// // In your code:
/// final apiUrl = RuntimeConfig.apiBaseUrl;
/// final razorpayKeyId = RuntimeConfig.razorpayKeyId;
/// ```

class RuntimeConfigService {
  static final RuntimeConfigService _instance = RuntimeConfigService._();

  factory RuntimeConfigService() => _instance;

  RuntimeConfigService._();

  static RuntimeConfigService get instance => _instance;

  Map<String, dynamic> _config = {};
  bool _isLoaded = false;

  /// Load configuration from backend
  Future<void> load() async {
    try {
      // Use default API URL from build environment
      final apiUrl = AppConfig.apiBaseUrl;
      final configUrl = Uri.parse('$apiUrl/config/app-config');

      debugPrint('[RuntimeConfig] Loading from $configUrl');

      // Fix 16 (2026-07-04): was a 45s timeout. This call runs in the
      // background (see main.dart) against a Render free-tier backend,
      // which cold-starts after inactivity. A 45s hang left the app
      // running on stale/default config far longer than necessary and
      // risked looking stuck if anything awaited `load()` directly.
      // Build-time defaults (_loadDefaults) cover every value this
      // endpoint returns, so failing fast is strictly better than
      // waiting out a slow cold start.
      final response = await http
          .get(configUrl, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _config = json['data'] ?? {};
        _isLoaded = true;
        debugPrint('[RuntimeConfig] Successfully loaded configuration');
        if (kDebugMode) {
          debugPrint('[RuntimeConfig] Received keys: ${_config.keys.join(', ')}');
          if (_config['supabase'] == null) {
            debugPrint('[RuntimeConfig] CRITICAL: "supabase" section missing in config response!');
          } else {
            final sb = _config['supabase'];
            debugPrint('[RuntimeConfig] Supabase Config: url=${sb['url'] != null}, key=${sb['anonKey'] != null}');
          }
        }
      } else {
        debugPrint(
          '[RuntimeConfig] Failed to load config (${response.statusCode}): ${response.body}',
        );
        _loadDefaults();
      }
    } catch (e, stack) {
      debugPrint('[RuntimeConfig] Error loading config: $e\n$stack');
      _loadDefaults();
    }
  }

  /// Fallback to build-time configuration
  void _loadDefaults() {
    debugPrint('[RuntimeConfig] Using build-time defaults');
    try {
      _config = {
        'apiBaseUrl': AppConfig.apiBaseUrl,
        'payments': {'razorpayKeyId': AppConfig.razorpayKeyId},
        'monitoring': {'sentryDsn': AppConfig.sentryDsn},
        'shop': {
          'latitude': AppConfig.shopLatitude,
          'longitude': AppConfig.shopLongitude,
          'maxDeliveryRadiusKm': AppConfig.deliveryRadiusKm,
        },
      };
    } catch (e) {
      debugPrint('[RuntimeConfig] Critical: Failed to load defaults: $e');
      _config = {};
    }
    _isLoaded = true;
  }

  // ─────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────

  bool get isLoaded => _isLoaded;

  String get apiBaseUrl => _config['apiBaseUrl'] ?? AppConfig.apiBaseUrl;

  String get razorpayKeyId => _config['payments']?['razorpayKeyId'] ?? AppConfig.razorpayKeyId;

  String get sentryDsn => _config['monitoring']?['sentryDsn'] ?? AppConfig.sentryDsn;

  String get supabaseUrl => _config['supabase']?['url'] ?? AppConfig.supabaseUrl;

  String get supabaseAnonKey => _config['supabase']?['anonKey'] ?? AppConfig.supabaseAnonKey;

  double get shopLatitude => (_config['shop']?['latitude'] ?? AppConfig.shopLatitude).toDouble();

  double get shopLongitude => (_config['shop']?['longitude'] ?? AppConfig.shopLongitude).toDouble();

  double get deliveryRadiusKm =>
      (_config['shop']?['maxDeliveryRadiusKm'] ?? AppConfig.deliveryRadiusKm).toDouble();

  bool get whatsappEnabled => _config['features']?['whatsappEnabled'] ?? false;

  /// Get raw config for debugging
  Map<String, dynamic> get rawConfig => Map.from(_config);
}

/// Convenience singleton access
/// Usage: RuntimeConfig.instance.apiBaseUrl
class RuntimeConfig {
  static RuntimeConfigService get instance => RuntimeConfigService.instance;
}

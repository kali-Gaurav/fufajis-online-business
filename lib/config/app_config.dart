import '../services/shop_config_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const appName = "Fufaji's Online";

  // Helper to get env value with multiple fallbacks
  static String _getEnv(String key, {String defaultValue = ''}) {
    // 1. Try --dart-define (compile-time)
    final fromEnv = String.fromEnvironment(key);
    if (fromEnv.isNotEmpty) return fromEnv;
    
    // 2. Try .env file (runtime)
    return dotenv.env[key] ?? defaultValue;
  }

  // Shop: Jalawar Road, Tel Factory, Baran, Rajasthan 325205
  static double get shopLatitude {
    return ShopConfigService().cachedConfig?.shopLatitude ?? 25.1006;
  }

  static double get shopLongitude {
    return ShopConfigService().cachedConfig?.shopLongitude ?? 76.5156;
  }

  static double get deliveryRadiusKm {
    return ShopConfigService().cachedConfig?.maxDeliveryRadiusKm ?? 15.0;
  }

  static const String shopCity = 'Baran';
  static const String shopState = 'Rajasthan';
  static const String shopAddress = 'Jalawar Road, Tel Factory, Baran, Rajasthan 325205';

  static String get apiBaseUrl {
    return _getEnv('API_BASE_URL', defaultValue: 'https://fufajis-online-business.onrender.com');
  }

  static String get supabaseUrl {
    return _getEnv('SUPABASE_URL');
  }

  static String get supabaseAnonKey {
    // Support both naming conventions
    final key = _getEnv('SUPABASE_ANON_KEY');
    if (key.isNotEmpty) return key;
    return _getEnv('SUPABASE_PUBLISHABLE_KEY');
  }

  @Deprecated('Redis must only be accessed via secure backend proxy.')
  static String get upstashRedisRestUrl {
    return '';
  }

  @Deprecated('Redis token must be kept server-side only.')
  static String get upstashRedisRestToken {
    return '';
  }

  static String get googleMapsKey {
    return _getEnv('GOOGLE_MAPS_KEY');
  }

  static String get razorpayKeyId {
    return _getEnv('RAZORPAY_KEY_ID');
  }

  @Deprecated('Razorpay secret must be kept server-side only.')
  static String get razorpayKeySecret {
    return '';
  }

  static String get sentryDsn {
    final dsn = _getEnv('SENTRY_DSN');
    if (dsn.contains('your-sentry-dsn')) return ''; // Ignore placeholder
    return dsn;
  }

  static String get apkDownloadUrl => _getEnv('APK_DOWNLOAD_URL');
  static String get supportWhatsappNumber => _getEnv('SUPPORT_WHATSAPP_NUMBER');

  @Deprecated('Razorpay webhook secret must be kept server-side only.')
  static String get razorpayWebhookSecret {
    return '';
  }

  static double get deliveryRadiusMeters => deliveryRadiusKm * 1000;

  static String get shopPhone =>
      ShopConfigService().cachedConfig?.shopPhone ?? '+91 9876543210';
}

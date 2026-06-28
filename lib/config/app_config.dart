import '../services/shop_config_service.dart';

class AppConfig {
  static const appName = "Fufaji's Online";

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
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://fufaji-api.render.com'
    );
  }

  static String get supabaseUrl {
    return const String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  }

  static String get supabaseAnonKey {
    return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  }

  static String get upstashRedisRestUrl {
    return const String.fromEnvironment('UPSTASH_REDIS_REST_URL', defaultValue: '');
  }

  static String get upstashRedisRestToken {
    return const String.fromEnvironment('UPSTASH_REDIS_REST_TOKEN', defaultValue: '');
  }

  static String get googleMapsKey {
    return const String.fromEnvironment('GOOGLE_MAPS_KEY', defaultValue: '');
  }

  static String get razorpayKeyId {
    return const String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: '');
  }

  @deprecated
  static String get razorpayKeySecret {
    // Deprecated: Razorpay secret must be kept server-side only. Returning empty string to prevent APK leakage.
    return '';
  }

  static String get sentryDsn {
    return const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  }

  static const apkDownloadUrl = String.fromEnvironment('APK_DOWNLOAD_URL');
  static const supportWhatsappNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP_NUMBER',
  );

  @deprecated
  static String get razorpayWebhookSecret {
    // Deprecated: Razorpay webhook secret must be kept server-side only. Returning empty string to prevent APK leakage.
    return '';
  }

  static double get deliveryRadiusMeters => deliveryRadiusKm * 1000;

  static String get shopPhone =>
      ShopConfigService().cachedConfig?.shopPhone ?? '+91 9876543210';

}

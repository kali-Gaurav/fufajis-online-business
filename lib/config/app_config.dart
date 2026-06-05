import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  static String get razorpayKeyId => dotenv.env['LIVE_API_KEY'] ?? '';
  static String get razorpayKeySecret => dotenv.env['LIVE_KEY_SECRET'] ?? '';

  static const apkDownloadUrl = String.fromEnvironment('APK_DOWNLOAD_URL');
  static const supportWhatsappNumber = String.fromEnvironment(
    'SUPPORT_WHATSAPP_NUMBER',
  );

  static double get deliveryRadiusMeters => deliveryRadiusKm * 1000;

  static String get shopPhone =>
      ShopConfigService().cachedConfig?.shopPhone ?? '+91 9876543210';
}

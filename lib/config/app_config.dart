import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/shop_config_service.dart';

class AppConfig {
  static const appName = "Fufaji's Online";

  static double get shopLatitude {
    return ShopConfigService().cachedConfig?.shopLatitude ?? 26.9124;
  }

  static double get shopLongitude {
    return ShopConfigService().cachedConfig?.shopLongitude ?? 75.7873;
  }

  static double get deliveryRadiusKm {
    return ShopConfigService().cachedConfig?.maxDeliveryRadiusKm ?? 8.0;
  }

  static String get razorpayKeyId => dotenv.env['LIVE_API_KEY'] ?? '';
  static String get razorpayKeySecret => dotenv.env['LIVE_KEY_SECRET'] ?? '';

  static const apkDownloadUrl = String.fromEnvironment('APK_DOWNLOAD_URL');
  static const supportWhatsappNumber =
      String.fromEnvironment('SUPPORT_WHATSAPP_NUMBER');

  static double get deliveryRadiusMeters => deliveryRadiusKm * 1000;
}

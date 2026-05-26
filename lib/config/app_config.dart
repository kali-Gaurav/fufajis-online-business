import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static const appName = "Fufaji's Online";

  static double get shopLatitude => double.tryParse(
    const String.fromEnvironment('SHOP_LATITUDE'),
  ) ?? 26.9124;

  static double get shopLongitude => double.tryParse(
    const String.fromEnvironment('SHOP_LONGITUDE'),
  ) ?? 75.7873;

  static double get deliveryRadiusKm => double.tryParse(
    const String.fromEnvironment('DELIVERY_RADIUS_KM'),
  ) ?? 8.0;

  static String get razorpayKeyId => dotenv.env['LIVE_API_KEY'] ?? '';
  static String get razorpayKeySecret => dotenv.env['LIVE_KEY_SECRET'] ?? '';

  static const apkDownloadUrl = String.fromEnvironment('APK_DOWNLOAD_URL');
  static const supportWhatsappNumber =
      String.fromEnvironment('SUPPORT_WHATSAPP_NUMBER');

  static double get deliveryRadiusMeters => deliveryRadiusKm * 1000;
}

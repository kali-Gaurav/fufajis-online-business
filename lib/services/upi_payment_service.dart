import 'package:url_launcher/url_launcher.dart';

class UpiPaymentService {
  /// Standard merchants parameters for Fufaji Stores
  static const String upiId = 'fufajistores@ybl';
  static const String merchantName = 'Fufaji Stores';

  /// Generates a standard BHIM UPI intent URI.
  /// Format: upi://pay?pa=VPA&pn=NAME&tr=TXNID&am=AMOUNT&cu=INR&tn=NOTE
  static String generateUpiUri({
    required String orderId,
    required double amount,
    String? note,
  }) {
    final cleanNote = Uri.encodeComponent(note ?? 'Order $orderId');
    final cleanName = Uri.encodeComponent(merchantName);
    return 'upi://pay?pa=$upiId&pn=$cleanName&tr=$orderId&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$cleanNote';
  }

  /// Attempts to launch the UPI intent on the local mobile device.
  /// Returns true if the launch was successful, false otherwise.
  static Future<bool> launchUpiIntent(String upiUri) async {
    final Uri url = Uri.parse(upiUri);
    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

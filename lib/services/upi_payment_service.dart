import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class UpiPaymentService {
  /// Default fallback parameters
  static const String defaultUpiId = 'fufajistores@ybl';
  static const String defaultMerchantName = 'Fufaji Stores';

  static String _upiId = defaultUpiId;
  static String _merchantName = defaultMerchantName;

  /// Loads dynamic UPI merchant configurations from Firestore
  static Future<void> init() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('payment_config')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data['isActive'] == true) {
          _upiId = data['upiId'] as String? ?? defaultUpiId;
          _merchantName = data['merchantName'] as String? ?? defaultMerchantName;
          debugPrint(
            '[UpiPaymentService] Loaded dynamic UPI Config: $_upiId ($_merchantName)',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[UpiPaymentService] Error loading dynamic UPI VPA, using defaults: $e',
      );
    }
  }

  static String get upiId => _upiId;
  static String get merchantName => _merchantName;

  /// Generates a standard BHIM UPI intent URI.
  /// Format: upi://pay?pa=VPA&pn=NAME&tr=TXNID&am=AMOUNT&cu=INR&tn=NOTE
  static String generateUpiUri({
    required String orderId,
    required double amount,
    String? note,
  }) {
    final cleanNote = Uri.encodeComponent(note ?? 'Order $orderId');
    final cleanName = Uri.encodeComponent(_merchantName);
    return 'upi://pay?pa=$_upiId&pn=$cleanName&tr=$orderId&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$cleanNote';
  }

  /// Attempts to launch the UPI intent on the local mobile device.
  /// Returns true if the launch was successful, false otherwise.
  static Future<bool> launchUpiIntent(String upiUri) async {
    final Uri url = Uri.parse(upiUri);
    try {
      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

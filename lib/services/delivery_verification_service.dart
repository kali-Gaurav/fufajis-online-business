import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import 'whatsapp_notification_service.dart';

/// Service for delivery OTP verification and completion
class DeliveryVerificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();


  static final DeliveryVerificationService _instance =
      DeliveryVerificationService._internal();
  factory DeliveryVerificationService() => _instance;
  DeliveryVerificationService._internal();

  /// Verify delivery OTP
  /// Returns true if OTP matches, false otherwise
  Future<bool> verifyDeliveryOTP({
    required String orderId,
    required String providedOTP,
    required String agentId,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final orderRef = _db.collection('orders').doc(orderId);
      final snapshot = await orderRef.get();

      if (!snapshot.exists) {
        throw Exception('Order not found');
      }

      final orderData = snapshot.data()!;
      final storedOTP = orderData['otp']?.toString() ?? '';

      // Verify OTP matches
      if (storedOTP.isEmpty) {
        throw Exception('No OTP found for this order');
      }

      if (storedOTP != providedOTP) {
        // Log failed OTP attempt
        await _logDeliveryEvent(
          orderId: orderId,
          agentId: agentId,
          eventType: 'otp_verification_failed',
          details: {
            'providedOTP': providedOTP,
            'attemptedAt': FieldValue.serverTimestamp(),
          },
        );
        return false;
      }

      // OTP verified - mark order as delivered
      final customerId = orderData['customerId']?.toString() ?? '';
      final customerName = orderData['customerName']?.toString() ?? '';
      final orderNumber = orderData['orderNumber']?.toString() ?? orderId;

      await _db.runTransaction((transaction) async {
        // Update order status to delivered
        transaction.update(orderRef, {
          'status': 'OrderStatus.delivered',
          'otpVerified': true,
          'deliveredAt': FieldValue.serverTimestamp(),
          'deliveryVerification': {
            'otp': providedOTP,
            'verifiedBy': agentId,
            'verifiedAt': FieldValue.serverTimestamp(),
            'latitude': latitude,
            'longitude': longitude,
          },
        });

        // Log successful delivery
        await _logDeliveryEvent(
          orderId: orderId,
          agentId: agentId,
          eventType: 'otp_verification_success',
          details: {
            'latitude': latitude,
            'longitude': longitude,
            'verifiedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      // Send notifications to customer
      if (customerId.isNotEmpty) {
        _notificationService.sendNotificationToUser(
          userId: customerId,
          title: 'Order Delivered',
          body: 'Order #$orderNumber has been delivered successfully!',
          data: {'type': 'orderUpdate', 'orderId': orderId},
        );

        // Send WhatsApp notification if phone available
        final customerPhone = orderData['customerPhone']?.toString();
        if (customerPhone != null && customerPhone.isNotEmpty) {
          WhatsAppNotificationService.sendOrderStatusUpdate(
            phoneNumber: customerPhone,
            customerName: customerName,
            orderNumber: orderNumber,
            status: 'delivered',
          );
        }
      }

      debugPrint('Order $orderId successfully delivered');
      return true;
    } catch (e) {
      debugPrint('Error verifying delivery OTP: $e');
      rethrow;
    }
  }

  /// Generate and store OTP for an order
  Future<String> generateAndStoreOTP(String orderId) async {
    try {
      final random = DateTime.now().millisecond + DateTime.now().microsecond;
      final otp = List.generate(6, (index) => (random + index * 7) % 10)
          .join(); // Generate 6-digit OTP

      await _db.collection('orders').doc(orderId).update({
        'otp': otp,
        'otpGeneratedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Generated OTP for order $orderId: $otp');
      return otp;
    } catch (e) {
      debugPrint('Error generating OTP: $e');
      rethrow;
    }
  }

  /// Get OTP for an order
  Future<String?> getOrderOTP(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return null;
      return doc.data()?['otp']?.toString();
    } catch (e) {
      debugPrint('Error fetching OTP: $e');
      return null;
    }
  }

  /// Check if OTP is verified
  Future<bool> isOTPVerified(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) return false;
      return doc.data()?['otpVerified'] as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking OTP status: $e');
      return false;
    }
  }

  /// Log delivery events (internal helper)
  Future<void> _logDeliveryEvent({
    required String orderId,
    required String agentId,
    required String eventType,
    required Map<String, dynamic> details,
  }) async {
    try {
      final logId =
          '${orderId}_${DateTime.now().millisecondsSinceEpoch}';
      await _db
          .collection('delivery_events')
          .doc(logId)
          .set({
            'id': logId,
            'orderId': orderId,
            'agentId': agentId,
            'eventType': eventType,
            'timestamp': FieldValue.serverTimestamp(),
            ...details,
          });
    } catch (e) {
      debugPrint('Error logging delivery event: $e');
    }
  }

  /// Log delivery event (public method)
  Future<void> logDeliveryEvent({
    required String orderId,
    required String agentId,
    required String eventType, // 'assigned', 'accepted', 'en_route', 'arrived', 'delivered'
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final logId =
          '${orderId}_${eventType}_${DateTime.now().millisecondsSinceEpoch}';
      await _db
          .collection('delivery_events')
          .doc(logId)
          .set({
            'id': logId,
            'orderId': orderId,
            'agentId': agentId,
            'eventType': eventType,
            'notes': notes,
            'latitude': latitude,
            'longitude': longitude,
            'timestamp': FieldValue.serverTimestamp(),
          });

      debugPrint('Logged delivery event: $eventType for order $orderId');
    } catch (e) {
      debugPrint('Error logging delivery event: $e');
    }
  }

  /// Get delivery event history for an order
  Stream<List<Map<String, dynamic>>> getDeliveryEventsStream(
    String orderId,
  ) {
    return _db
        .collection('delivery_events')
        .where('orderId', isEqualTo: orderId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Get delivery event history for an agent
  Stream<List<Map<String, dynamic>>> getAgentDeliveryEventsStream(
    String agentId,
  ) {
    return _db
        .collection('delivery_events')
        .where('agentId', isEqualTo: agentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  /// Resend OTP via SMS/WhatsApp
  Future<void> resendOTP({
    required String orderId,
    required String customerPhone,
    required String customerName,
  }) async {
    try {
      final otp = await getOrderOTP(orderId);
      final orderDoc = await _db.collection('orders').doc(orderId).get();
      final orderNumber = orderDoc.data()?['orderNumber'] ?? 'N/A';

      if (otp == null || otp.isEmpty) {
        // Generate new OTP if not exists
        final newOtp = await generateAndStoreOTP(orderId);
        await WhatsAppNotificationService.sendOTPMessage(
          phoneNumber: customerPhone,
          customerName: customerName,
          otp: newOtp,
          orderNumber: orderNumber,
        );
      } else {
        // Resend existing OTP
        await WhatsAppNotificationService.sendOTPMessage(
          phoneNumber: customerPhone,
          customerName: customerName,
          otp: otp,
          orderNumber: orderNumber,
        );
      }

      debugPrint('OTP resent for order $orderId');
    } catch (e) {
      debugPrint('Error resending OTP: $e');
      rethrow;
    }
  }

  /// Calculate delivery metrics
  Future<Map<String, dynamic>> getDeliveryMetrics(String agentId) async {
    try {
      final deliveredSnapshot = await _db
          .collection('orders')
          .where('deliveryAgentId', isEqualTo: agentId)
          .where('status', isEqualTo: 'OrderStatus.delivered')
          .get();

      final otpVerifiedCount = deliveredSnapshot.docs
          .where((doc) => doc.data()['otpVerified'] == true)
          .length;

      return {
        'totalDeliveries': deliveredSnapshot.docs.length,
        'otpVerifiedDeliveries': otpVerifiedCount,
        'verificationRate': deliveredSnapshot.docs.isNotEmpty
            ? (otpVerifiedCount / deliveredSnapshot.docs.length * 100)
                .toStringAsFixed(2)
            : '0.00',
      };
    } catch (e) {
      debugPrint('Error calculating metrics: $e');
      return {};
    }
  }
}

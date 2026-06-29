import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import 'notification_service.dart';
import 'whatsapp_notification_service.dart';
import 'email_service.dart';
import 'invoice_service.dart';
import '../constants/order_status.dart';

/// Handles automated notifications triggered by order events
/// Coordinates multi-channel delivery: FCM, WhatsApp, SMS, in-app
class OrderNotificationService {
  static final OrderNotificationService _instance = OrderNotificationService._internal();
  factory OrderNotificationService() => _instance;
  OrderNotificationService._internal();

  FirebaseFirestore? _customFirestore;
  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  set firestore(FirebaseFirestore database) => _customFirestore = database;
  FirebaseMessaging? _customFcm;
  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;
  set fcm(FirebaseMessaging value) => _customFcm = value;
  final NotificationService _notificationService = NotificationService();
  final EmailService _emailService = EmailService();

  // ════════════════════════════════════════════════════════════════════════
  //  ORDER CONFIRMATION - When order is placed
  // ════════════════════════════════════════════════════════════════════════

  Future<void> notifyOrderConfirmed(OrderModel order) async {
    try {
      debugPrint('[OrderNotification] Order confirmed: ${order.id}');

      // 1. Create order-linked chat
      await _createOrderChat(order);

      // 2. Send in-app notification
      await _sendNotification(
        userId: order.customerId,
        title: '✅ Order #${order.orderNumber.toUpperCase()} Confirmed',
        body: 'We received your order. Expected delivery: ${_formatDate(order.scheduledDeliveryDate)}',
        type: 'orderConfirmed',
        orderId: order.id,
        data: {
          'estimatedDelivery': order.scheduledDeliveryDate?.toIso8601String() ?? '',
          'totalAmount': order.totalAmount.toString(),
        },
      );

      // 3. Send WhatsApp confirmation
      await WhatsAppNotificationService.sendStatusUpdate(
        phoneNumber: order.customerPhone,
        customerName: order.customerName,
        orderNumber: order.orderNumber,
        status: 'confirmed',
      );

      // 4. Send order confirmation email (if customer has an email on file)
      final confirmChannels = ['inApp', 'whatsapp'];
      if (order.customerEmail != null && EmailService.isValidEmail(order.customerEmail!)) {
        final sent = await _emailService.sendOrderConfirmationEmail(
          email: order.customerEmail!,
          customerName: order.customerName,
          orderNumber: order.orderNumber,
          estimatedDeliveryDate: _formatDate(order.scheduledDeliveryDate),
          totalAmount: order.totalAmount.toDouble(),
          items: order.items.map((e) => e.toMap()).toList(),
        );
        if (sent) confirmChannels.add('email');
      }

      // 5. Log notification
      await _logNotificationDelivery(
        orderId: order.id,
        type: 'orderConfirmed',
        channels: confirmChannels,
      );

      // 6. Subscribe customer to order-specific FCM topic
      await _subscribeToOrderTopic(order.customerId, order.id);
    } catch (e) {
      debugPrint('[OrderNotification] Error notifying order confirmed: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ORDER STATUS UPDATES
  // ════════════════════════════════════════════════════════════════════════

  Future<void> notifyOrderStatusChanged(
    OrderModel order,
    OrderStatus previousStatus,
  ) async {
    try {
      debugPrint('[OrderNotification] Order status changed: ${order.id} → ${order.status}');

      final notification = _getStatusNotification(order.status);
      if (notification == null) return;

      // 1. Send notification
      await _sendNotification(
        userId: order.customerId,
        title: notification['title']!,
        body: notification['body']!,
        type: notification['type']!,
        orderId: order.id,
        data: {
          'status': order.status.toString(),
          'previousStatus': previousStatus.toString(),
        },
      );

      // 2. Add system message to chat
      await _addSystemMessage(
        orderId: order.id,
        message: 'Order status changed to: ${order.status.displayName}',
      );

      // 3. Send WhatsApp status update
      if (order.status == OrderStatus.outForDelivery) {
        await WhatsAppNotificationService.sendStatusUpdate(
          phoneNumber: order.customerPhone,
          customerName: order.customerName,
          orderNumber: order.orderNumber,
          status: 'outfordelivery',
          otp: order.otp,
        );
      } else if (order.status == OrderStatus.delivered) {
        await WhatsAppNotificationService.sendStatusUpdate(
          phoneNumber: order.customerPhone,
          customerName: order.customerName,
          orderNumber: order.orderNumber,
          status: 'delivered',
        );
      }

      // 4. Show local notification if app is open
      _notificationService.triggerLocalOrderStatusNotification(
        order.orderNumber,
        order.status.displayName,
      );

      // 5. Log delivery
      await _logNotificationDelivery(
        orderId: order.id,
        type: 'orderStatusChanged',
        channels: ['inApp', 'whatsapp'],
        metadata: {'newStatus': order.status.toString()},
      );
    } catch (e) {
      debugPrint('[OrderNotification] Error notifying status change: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  DELIVERY COMPLETION - Send invoice
  // ════════════════════════════════════════════════════════════════════════

  Future<void> notifyDeliveryComplete(OrderModel order) async {
    try {
      debugPrint('[OrderNotification] Delivery complete: ${order.id}');

      // 1. Send delivery notification
      await _sendNotification(
        userId: order.customerId,
        title: '✅ Your order has been delivered!',
        body: 'Thank you for shopping with Fufaji! Tap to download invoice »',
        type: 'delivered',
        orderId: order.id,
      );

      // 2. Send invoice via chat
      await _sendInvoiceViChat(order);

      // 3. Send WhatsApp delivery confirmation with invoice
      await WhatsAppNotificationService.sendInvoice(
        phoneNumber: order.customerPhone,
        customerName: order.customerName,
        orderNumber: order.orderNumber,
        items: order.items.map((e) => e.toMap()).toList(),
        subtotal: order.subtotal.toDouble(),
        deliveryCharge: order.deliveryCharge.toDouble(),
        discount: order.discount.toDouble(),
        totalAmount: order.totalAmount.toDouble(),
        paymentMethod: order.paymentMethod.toString().split('.').last,
      );

      // 4. Request feedback suggestion
      await _suggestFeedback(order);

      // 5. Send order receipt email (if customer has an email on file)
      final deliveredChannels = ['inApp', 'chat', 'whatsapp'];
      if (order.customerEmail != null && EmailService.isValidEmail(order.customerEmail!)) {
        final sent = await _emailService.sendOrderReceiptEmail(
          email: order.customerEmail!,
          customerName: order.customerName,
          orderNumber: order.orderNumber,
          subtotal: order.subtotal.toDouble(),
          deliveryCharge: order.deliveryCharge.toDouble(),
          discount: order.discount.toDouble(),
          tax: order.tax.toDouble(),
          totalAmount: order.totalAmount.toDouble(),
          paymentMethod: order.paymentMethod.toString().split('.').last,
          items: order.items.map((e) => e.toMap()).toList(),
        );
        if (sent) deliveredChannels.add('email');
      }

      // 6. Log delivery
      await _logNotificationDelivery(
        orderId: order.id,
        type: 'delivered',
        channels: deliveredChannels,
      );
    } catch (e) {
      debugPrint('[OrderNotification] Error notifying delivery: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAYMENT RECEIVED
  // ════════════════════════════════════════════════════════════════════════

  Future<void> notifyPaymentReceived(
    String orderId,
    String customerId,
    double amount,
  ) async {
    try {
      await _sendNotification(
        userId: customerId,
        title: '💳 Payment Received',
        body: 'We received your payment of ₹${amount.toStringAsFixed(0)}. Your order will be processed soon.',
        type: 'paymentReceived',
        orderId: orderId,
        data: {'amount': amount.toString()},
      );

      await _logNotificationDelivery(
        orderId: orderId,
        type: 'paymentReceived',
        channels: ['inApp'],
      );
    } catch (e) {
      debugPrint('[OrderNotification] Error notifying payment: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SUGGESTED NOTIFICATIONS
  // ════════════════════════════════════════════════════════════════════════

  Future<void> suggestReorder(
    String customerId,
    String productName,
    String productId,
    int daysAgo,
  ) async {
    try {
      await _sendNotification(
        userId: customerId,
        title: '🛒 Smart Kitchen: $productName running low?',
        body: 'You usually buy $productName every few days. Last purchase was $daysAgo days ago.',
        type: 'reorderSuggestion',
        data: {
          'productId': productId,
          'suggestionType': 'stapleRefill',
        },
      );
    } catch (e) {
      debugPrint('[OrderNotification] Error suggesting reorder: $e');
    }
  }

  Future<void> notifyPriceDrop(
    String customerId,
    String productName,
    double oldPrice,
    double newPrice,
  ) async {
    try {
      final discount = ((oldPrice - newPrice) / oldPrice * 100).toStringAsFixed(0);

      await _sendNotification(
        userId: customerId,
        title: '💰 Price Drop: $productName!',
        body: 'Was ₹${oldPrice.toStringAsFixed(0)}, now ₹${newPrice.toStringAsFixed(0)} ($discount% off)',
        type: 'priceDrop',
        data: {
          'oldPrice': oldPrice.toString(),
          'newPrice': newPrice.toString(),
          'discount': discount,
        },
      );
    } catch (e) {
      debugPrint('[OrderNotification] Error notifying price drop: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HELPER METHODS
  // ════════════════════════════════════════════════════════════════════════

  /// Get notification content based on order status
  Map<String, String>? _getStatusNotification(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return {
          'title': '✅ Order Confirmed',
          'body': 'Your order is confirmed and we\'re preparing it.',
          'type': 'orderConfirmed',
        };
      case OrderStatus.processing:
        return {
          'title': '📦 Order Processing',
          'body': 'We\'re preparing your order. Updates coming soon.',
          'type': 'orderProcessing',
        };
      case OrderStatus.packed:
        return {
          'title': '📦 Order Packed',
          'body': 'Your order has been packed and is ready for dispatch.',
          'type': 'orderPacked',
        };
      case OrderStatus.outForDelivery:
        return {
          'title': '🚗 Out for Delivery',
          'body': 'Your order is on the way! Expected delivery today.',
          'type': 'outForDelivery',
        };
      case OrderStatus.delivered:
        return {
          'title': '✅ Delivered!',
          'body': 'Your order has been delivered. Thank you for shopping!',
          'type': 'delivered',
        };
      case OrderStatus.cancelled:
        return {
          'title': '❌ Order Cancelled',
          'body': 'Your order has been cancelled. Refund will be processed soon.',
          'type': 'cancelled',
        };
      case OrderStatus.returned:
        return {
          'title': '↩️ Return Received',
          'body': 'We received your return. Processing refund...',
          'type': 'returned',
        };
      case OrderStatus.refunded:
        return {
          'title': '💰 Refund Processed',
          'body': 'Your refund has been processed successfully.',
          'type': 'refunded',
        };
      default:
        return null;
    }
  }

  /// Send in-app notification stored in Firestore
  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? orderId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

      await docRef.set({
        'id': docRef.id,
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'data': data ?? {},
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      debugPrint('[OrderNotification] In-app notification sent: $type');
    } catch (e) {
      debugPrint('[OrderNotification] Error sending in-app notification: $e');
    }
  }

  /// Create chat for order (only if not already created)
  Future<void> _createOrderChat(OrderModel order) async {
    try {
      final chatId = 'order_${order.id}';
      final chatRef = _firestore.collection('chats').doc(chatId);

      final chatDoc = await chatRef.get();
      if (chatDoc.exists) {
        debugPrint('[OrderNotification] Chat already exists for order');
        return;
      }

      // Create new chat
      await chatRef.set({
        'id': chatId,
        'orderId': order.id,
        'customerId': order.customerId,
        'status': 'open',
        'type': 'order_support',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'participants': [order.customerId],
        'unreadCountCustomer': 0,
        'unreadCountOwner': 1,
      });

      // Add welcome message
      await chatRef.collection('messages').add({
        'type': 'systemMessage',
        'content': 'Welcome! 👋 We\'re here to help with your order. Do you have any questions?',
        'senderId': 'system',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint('[OrderNotification] Order chat created: $chatId');
    } catch (e) {
      debugPrint('[OrderNotification] Error creating order chat: $e');
    }
  }

  /// Add system message to order chat
  Future<void> _addSystemMessage({
    required String orderId,
    required String message,
  }) async {
    try {
      final chatId = 'order_$orderId';
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'type': 'systemMessage',
        'content': message,
        'senderId': 'system',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      debugPrint('[OrderNotification] System message added to chat');
    } catch (e) {
      debugPrint('[OrderNotification] Error adding system message: $e');
    }
  }

  /// Send invoice via chat message
  Future<void> _sendInvoiceViChat(OrderModel order) async {
    try {
      final chatId = 'order_${order.id}';

      // ✅ FIXED: Generate invoice PDF
      final invoice = await InvoiceService().generateInvoice(order);

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'type': 'invoice',
        'content': 'Your invoice #${invoice.invoiceNumber} is ready!',
        'senderId': 'system',
        'orderId': order.id,
        'invoiceId': invoice.id,
        'invoice': {
          'invoiceNumber': invoice.invoiceNumber,
          'amount': order.subtotal,
          'tax': order.tax,
          'delivery': order.deliveryCharge,
          'discount': order.discount,
          'total': order.totalAmount,
          'itemCount': order.items.length,
          'pdfSize': invoice.pdfSize,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[OrderNotification] ✅ Invoice sent via chat: ${invoice.invoiceNumber}');
    } catch (e) {
      debugPrint('[OrderNotification] ❌ Error sending invoice: $e');
    }
  }

  /// Suggest feedback/review
  Future<void> _suggestFeedback(OrderModel order) async {
    try {
      await Future.delayed(const Duration(seconds: 10)); // Wait 10 sec before asking

      await _sendNotification(
        userId: order.customerId,
        title: '⭐ How was your delivery experience?',
        body: 'Help us improve by rating your experience with Fufaji.',
        type: 'feedbackRequest',
        orderId: order.id,
      );
    } catch (e) {
      debugPrint('[OrderNotification] Error suggesting feedback: $e');
    }
  }

  /// Subscribe to order-specific FCM topic
  Future<void> _subscribeToOrderTopic(String customerId, String orderId) async {
    try {
      final topic = 'order_$orderId';
      await _fcm.subscribeToTopic(topic);
      debugPrint('[OrderNotification] Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('[OrderNotification] Error subscribing to topic: $e');
    }
  }

  /// Log notification delivery for analytics/debugging
  Future<void> _logNotificationDelivery({
    required String orderId,
    required String type,
    required List<String> channels,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('notification_delivery_log').add({
        'orderId': orderId,
        'type': type,
        'channels': channels,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata ?? {},
        'status': 'sent',
      });
    } catch (e) {
      debugPrint('[OrderNotification] Error logging delivery: $e');
    }
  }

  /// Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return 'soon';
    final today = DateTime.now();
    final tomorrow = today.add(const Duration(days: 1));

    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'today by 10 PM';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'tomorrow by 10 PM';
    } else {
      return '${date.day}/${date.month} by 10 PM';
    }
  }
}

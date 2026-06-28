import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Analytics Service - Track key events across the app
/// Events are logged to Firebase Analytics for business metrics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  static AnalyticsService get instance => _instance;
  AnalyticsService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Track app launch
  Future<void> logAppLaunch({
    required String version,
    required String buildNumber,
    String? deviceModel,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_launch',
        parameters: {
          'app_version': version,
          'build_number': buildNumber,
          'device_model': deviceModel ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] app_launch tracked');
    } catch (e) {
      debugPrint('[Analytics] Error logging app_launch: $e');
      Sentry.captureException(e);
    }
  }

  /// Track user login success
  Future<void> logLoginSuccess({
    required String userId,
    required String userRole,
    String? loginMethod,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'login_success',
        parameters: {
          'user_id': userId,
          'user_role': userRole,
          'login_method': loginMethod ?? 'email',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] login_success tracked for user: $userId');
    } catch (e) {
      debugPrint('[Analytics] Error logging login_success: $e');
      Sentry.captureException(e);
    }
  }

  /// Track order creation
  Future<void> logOrderCreated({
    required String orderId,
    required String userId,
    required double amount,
    required int itemCount,
    String? shopId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_created',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'amount': amount.toString(),
          'item_count': itemCount.toString(),
          'shop_id': shopId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] order_created tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging order_created: $e');
      Sentry.captureException(e);
    }
  }

  /// Track payment initiation (Razorpay checkout opened)
  Future<void> logPaymentInitiated({
    required String orderId,
    required String userId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment_initiated',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'amount': amount.toString(),
          'payment_method': paymentMethod,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] payment_initiated tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging payment_initiated: $e');
      Sentry.captureException(e);
    }
  }

  /// Track payment verification success
  Future<void> logPaymentVerified({
    required String orderId,
    required String userId,
    required double amount,
    required String paymentId,
    int? duration,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment_verified',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'amount': amount.toString(),
          'payment_id': paymentId,
          'duration_ms': (duration ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] payment_verified tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging payment_verified: $e');
      Sentry.captureException(e);
    }
  }

  /// Track order confirmed (moved to packing)
  Future<void> logOrderConfirmed({
    required String orderId,
    required String userId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_confirmed',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] order_confirmed tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging order_confirmed: $e');
      Sentry.captureException(e);
    }
  }

  /// Track packing completion
  Future<void> logPackingCompleted({
    required String orderId,
    required String userId,
    int? duration,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'packing_completed',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'duration_ms': (duration ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] packing_completed tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging packing_completed: $e');
      Sentry.captureException(e);
    }
  }

  /// Track delivery assignment
  Future<void> logDeliveryAssigned({
    required String orderId,
    required String userId,
    required String riderId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'delivery_assigned',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'rider_id': riderId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] delivery_assigned tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging delivery_assigned: $e');
      Sentry.captureException(e);
    }
  }

  /// Track order delivery completion
  Future<void> logOrderDelivered({
    required String orderId,
    required String userId,
    required String riderId,
    int? deliveryDuration,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_delivered',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'rider_id': riderId,
          'delivery_duration_ms': (deliveryDuration ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] order_delivered tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging order_delivered: $e');
      Sentry.captureException(e);
    }
  }

  /// Track order cancellation
  Future<void> logOrderCancelled({
    required String orderId,
    required String userId,
    String? reason,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_cancelled',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'reason': reason ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] order_cancelled tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging order_cancelled: $e');
      Sentry.captureException(e);
    }
  }

  /// Track refund processing
  Future<void> logRefundProcessed({
    required String orderId,
    required String userId,
    required double refundAmount,
    String? status,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'refund_processed',
        parameters: {
          'order_id': orderId,
          'user_id': userId,
          'refund_amount': refundAmount.toString(),
          'status': status ?? 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] refund_processed tracked: $orderId');
    } catch (e) {
      debugPrint('[Analytics] Error logging refund_processed: $e');
      Sentry.captureException(e);
    }
  }

  /// Track critical error with context
  Future<void> logErrorOccurred({
    required String errorType,
    required String errorMessage,
    String? userId,
    String? orderId,
    String? paymentId,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      final params = {
        'error_type': errorType,
        'error_message': errorMessage,
        'timestamp': DateTime.now().toIso8601String(),
        if (userId != null) 'user_id': userId,
        if (orderId != null) 'order_id': orderId,
        if (paymentId != null) 'payment_id': paymentId,
        if (additionalContext != null)
          ...additionalContext
              .map((k, v) => MapEntry(k, v.toString()))
              .cast<String, String>(),
      };

      await _analytics.logEvent(
        name: 'error_occurred',
        parameters: params,
      );
      debugPrint('[Analytics] error_occurred tracked: $errorType');
    } catch (e) {
      debugPrint('[Analytics] Error logging error_occurred: $e');
      Sentry.captureException(e);
    }
  }

  /// Track screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    String? userId,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: {
          'user_id': userId ?? 'anonymous',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] screen_view tracked: $screenName');
    } catch (e) {
      debugPrint('[Analytics] Error logging screen_view: $e');
    }
  }

  /// Set user properties for analytics segmentation
  Future<void> setUserProperties({
    required String userId,
    required String userRole,
    String? shopId,
    String? phoneNumber,
    String? userTier,
  }) async {
    try {
      await _analytics.setUserId(id: userId);

      final properties = {
        'user_role': userRole,
        'shop_id': shopId ?? 'none',
        'phone_number': phoneNumber ?? 'anonymous',
        'user_tier': userTier ?? 'free',
      };

      for (final entry in properties.entries) {
        await _analytics.setUserProperty(
          name: entry.key,
          value: entry.value,
        );
      }

      debugPrint('[Analytics] User properties set for: $userId');
    } catch (e) {
      debugPrint('[Analytics] Error setting user properties: $e');
      Sentry.captureException(e);
    }
  }

  /// Clear user analytics data (on logout)
  Future<void> clearUserData() async {
    try {
      await _analytics.setUserId(id: null);
      await _analytics.resetAnalyticsData();
      debugPrint('[Analytics] User data cleared');
    } catch (e) {
      debugPrint('[Analytics] Error clearing user data: $e');
    }
  }

  /// Log custom event
  Future<void> logCustomEvent({
    required String eventName,
    required Map<String, dynamic> parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters
            .map((k, v) => MapEntry(k, v.toString()))
            .cast<String, String>(),
      );
      debugPrint('[Analytics] custom event tracked: $eventName');
    } catch (e) {
      debugPrint('[Analytics] Error logging custom event: $e');
      Sentry.captureException(e);
    }
  }

  /// Alias for logCustomEvent to support existing calls
  Future<void> trackEvent(String eventName, Map<String, dynamic> parameters) async {
    await logCustomEvent(eventName: eventName, parameters: parameters);
  }

  // ============================================================================
  // ORDER FUNNEL TRACKING - Measure conversion at each step
  // ============================================================================
  // These events measure user progression through the purchase funnel.
  // Use these metrics to identify drop-off points and optimize conversion.

  /// Track when user browses products (top of funnel)
  Future<void> trackOrderFunnelBrowse({
    required String userId,
    String? categoryId,
    int? productCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'funnel_browse_products',
        parameters: {
          'user_id': userId,
          'category_id': categoryId ?? 'all',
          'product_count': (productCount ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      Sentry.captureMessage('User browsed products', level: SentryLevel.info);
      debugPrint('[Analytics] Funnel: user_browsed_products');
    } catch (e) {
      debugPrint('[Analytics] Error logging browse: $e');
    }
  }

  /// Track when user adds item to cart
  Future<void> trackOrderFunnelAddToCart({
    required String userId,
    required String productId,
    required double price,
    required int quantity,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'funnel_add_to_cart',
        parameters: {
          'user_id': userId,
          'product_id': productId,
          'price': price.toString(),
          'quantity': quantity.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      Sentry.captureMessage('Item added to cart', level: SentryLevel.info);
      debugPrint('[Analytics] Funnel: item_added_to_cart');
    } catch (e) {
      debugPrint('[Analytics] Error logging add to cart: $e');
    }
  }

  /// Track when user starts checkout
  Future<void> trackOrderFunnelCheckoutStarted({
    required String userId,
    required String cartId,
    required double cartTotal,
    required int itemCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'funnel_checkout_started',
        parameters: {
          'user_id': userId,
          'cart_id': cartId,
          'cart_total': cartTotal.toString(),
          'item_count': itemCount.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      Sentry.captureMessage('Checkout started', level: SentryLevel.info);
      debugPrint('[Analytics] Funnel: checkout_started');
    } catch (e) {
      debugPrint('[Analytics] Error logging checkout start: $e');
    }
  }

  /// Track when user completes payment (most critical funnel step)
  Future<void> trackOrderFunnelPaymentCompleted({
    required String userId,
    required String orderId,
    required double amount,
    required String paymentMethod,
    int? durationMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'funnel_payment_completed',
        parameters: {
          'user_id': userId,
          'order_id': orderId,
          'amount': amount.toString(),
          'payment_method': paymentMethod,
          'duration_ms': (durationMs ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      Sentry.captureMessage('Payment completed', level: SentryLevel.info);
      debugPrint('[Analytics] Funnel: payment_completed');
    } catch (e) {
      debugPrint('[Analytics] Error logging payment completion: $e');
    }
  }

  /// Track when order is confirmed (end of funnel - conversion)
  Future<void> trackOrderFunnelConfirmed({
    required String userId,
    required String orderId,
    required double orderValue,
    int? conversionTimeMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'funnel_order_confirmed',
        parameters: {
          'user_id': userId,
          'order_id': orderId,
          'order_value': orderValue.toString(),
          'conversion_time_ms': (conversionTimeMs ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      Sentry.captureMessage('Order confirmed (CONVERSION)', level: SentryLevel.info);
      debugPrint('[Analytics] Funnel: order_confirmed (CONVERSION COMPLETE)');
    } catch (e) {
      debugPrint('[Analytics] Error logging order confirmation: $e');
    }
  }

  // ============================================================================
  // KEY PERFORMANCE METRICS - Business-critical operations
  // ============================================================================
  // These metrics track health of critical business flows.
  // Monitor these to catch production issues early.

  /// Track payment success rate (completed / total attempts)
  Future<void> trackPaymentSuccessRate({
    required String paymentId,
    required bool isSuccess,
    String? failureReason,
    int? retryCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'payment_success_rate',
        parameters: {
          'payment_id': paymentId,
          'status': isSuccess ? 'success' : 'failed',
          'failure_reason': failureReason ?? 'none',
          'retry_count': (retryCount ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] Payment Success Rate: ${isSuccess ? 'SUCCESS' : 'FAILED'}');
    } catch (e) {
      debugPrint('[Analytics] Error logging payment success rate: $e');
    }
  }

  /// Track delivery assignment metrics (assigned / created orders)
  Future<void> trackDeliveryAssignmentRate({
    required String orderId,
    bool? isAssigned,
    int? assignmentDelayMs,
    String? assignmentStatus,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'delivery_assignment_rate',
        parameters: {
          'order_id': orderId,
          'assigned': (isAssigned ?? false).toString(),
          'assignment_delay_ms': (assignmentDelayMs ?? 0).toString(),
          'status': assignmentStatus ?? 'pending',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] Delivery Assignment: ${isAssigned ?? false ? 'ASSIGNED' : 'PENDING'}');
    } catch (e) {
      debugPrint('[Analytics] Error logging delivery assignment rate: $e');
    }
  }

  /// Track order-to-delivery time (SLA metric)
  Future<void> trackOrderDeliveryTime({
    required String orderId,
    required int totalDurationMs,
    int? packingDurationMs,
    int? shippingDurationMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_delivery_time',
        parameters: {
          'order_id': orderId,
          'total_duration_ms': totalDurationMs.toString(),
          'packing_duration_ms': (packingDurationMs ?? 0).toString(),
          'shipping_duration_ms': (shippingDurationMs ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] Order Delivery Time: ${totalDurationMs}ms total');
    } catch (e) {
      debugPrint('[Analytics] Error logging delivery time: $e');
    }
  }

  /// Track stock oversell attempts (should ALWAYS be 0 in production)
  /// This is a critical bug indicator
  Future<void> trackStockOversellAttempt({
    required String productId,
    required int requestedQty,
    required int availableQty,
    required String orderId,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'stock_oversell_attempt',
        parameters: {
          'product_id': productId,
          'requested_qty': requestedQty.toString(),
          'available_qty': availableQty.toString(),
          'order_id': orderId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      // CRITICAL: Report as error to Sentry
      Sentry.captureMessage(
        'CRITICAL: Stock oversell attempt! Product: $productId, Requested: $requestedQty, Available: $availableQty',
        level: SentryLevel.error,
      );
      debugPrint('[Analytics] CRITICAL: Stock oversell attempt detected!');
    } catch (e) {
      debugPrint('[Analytics] Error logging stock oversell: $e');
    }
  }

  /// Track refund rate (important for business health)
  Future<void> trackRefundProcessed({
    required String orderId,
    required double refundAmount,
    required String refundReason,
    int? refundProcessingTimeMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'refund_rate',
        parameters: {
          'order_id': orderId,
          'refund_amount': refundAmount.toString(),
          'reason': refundReason,
          'processing_time_ms': (refundProcessingTimeMs ?? 0).toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] Refund Processed: $orderId for \$$refundAmount');
    } catch (e) {
      debugPrint('[Analytics] Error logging refund: $e');
    }
  }

  /// Track return rate (important for product quality feedback)
  Future<void> trackReturnInitiated({
    required String orderId,
    required String productId,
    required String returnReason,
    required int quantityReturned,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'return_rate',
        parameters: {
          'order_id': orderId,
          'product_id': productId,
          'reason': returnReason,
          'quantity': quantityReturned.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('[Analytics] Return Initiated: $orderId - $productId');
    } catch (e) {
      debugPrint('[Analytics] Error logging return: $e');
    }
  }
}

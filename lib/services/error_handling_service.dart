import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'logging_service.dart';
import 'analytics_service.dart';

/// Error Handling Service
/// Centralizes error handling, logging, and reporting to Sentry
/// Wraps exceptions with context (user ID, order ID, etc.)
class ErrorHandlingService {
  static final ErrorHandlingService _instance =
      ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  final LoggingService _logger = LoggingService();
  final AnalyticsService _analytics = AnalyticsService();

  // Current user context for error tracking
  String? _currentUserId;
  String? _currentOrderId;
  String? _currentPaymentId;

  /// Set current user context (called on login)
  void setUserContext(String userId) {
    _currentUserId = userId;
    Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: userId)),
    );
    debugPrint('[ErrorHandler] User context set: $userId');
  }

  /// Set current order context (during order flow)
  void setOrderContext(String orderId, {double? amount}) {
    _currentOrderId = orderId;
    Sentry.captureMessage(
      'Order context set',
      withScope: (scope) {
        scope.setContexts('order', {'id': orderId, 'amount': amount});
      },
    );
    debugPrint('[ErrorHandler] Order context set: $orderId');
  }

  /// Set current payment context (during payment flow)
  void setPaymentContext(String paymentId, {String? method}) {
    _currentPaymentId = paymentId;
    Sentry.captureMessage(
      'Payment context set',
      withScope: (scope) {
        scope.setContexts('payment', {'id': paymentId, 'method': method});
      },
    );
    debugPrint('[ErrorHandler] Payment context set: $paymentId');
  }

  /// Clear all context (on logout)
  void clearContext() {
    _currentUserId = null;
    _currentOrderId = null;
    _currentPaymentId = null;
    Sentry.configureScope((scope) => scope.setUser(null));
    debugPrint('[ErrorHandler] Context cleared');
  }

  // ============================================================================
  // ERROR HANDLING WRAPPERS
  // ============================================================================
  // These methods wrap common operations with error context and reporting

  /// Wrap order creation with error handling
  Future<T> handleOrderCreation<T>({
    required Future<T> Function() operation,
    required String userId,
    String? orderId,
  }) async {
    setUserContext(userId);
    if (orderId != null) setOrderContext(orderId);

    try {
      _logger.info('Starting order creation', data: {'order_id': orderId});
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Order creation started',
          data: {'order_id': orderId},
          level: SentryLevel.info,
        ),
      );

      final result = await operation();

      _logger.info('Order creation succeeded', data: {'order_id': orderId});
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Order creation completed',
          data: {'order_id': orderId},
          level: SentryLevel.info,
        ),
      );

      return result;
    } catch (e, stack) {
      _logger.error(
        'Order creation failed',
        e,
        stack,
        {'order_id': orderId, 'user_id': userId},
      );

      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setContexts('order_creation_error', {
            'order_id': orderId,
            'user_id': userId,
            'error_type': e.runtimeType.toString(),
          });
        },
      );

      await _analytics.logErrorOccurred(
        errorType: 'order_creation_failed',
        errorMessage: e.toString(),
        userId: userId,
        orderId: orderId,
      );

      rethrow;
    }
  }

  /// Wrap payment processing with error handling
  Future<T> handlePaymentProcessing<T>({
    required Future<T> Function() operation,
    required String userId,
    required String orderId,
    required double amount,
    String? paymentMethod,
  }) async {
    setUserContext(userId);
    setOrderContext(orderId, amount: amount);
    setPaymentContext(orderId, method: paymentMethod);

    try {
      _logger.info('Starting payment processing', data: {
        'order_id': orderId,
        'amount': amount,
        'payment_method': paymentMethod,
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Payment processing started',
          data: {
            'order_id': orderId,
            'amount': amount,
            'method': paymentMethod,
          },
          level: SentryLevel.info,
        ),
      );

      final result = await operation();

      _logger.info('Payment processing succeeded', data: {
        'order_id': orderId,
        'amount': amount,
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Payment processing completed',
          data: {'order_id': orderId, 'amount': amount},
          level: SentryLevel.info,
        ),
      );

      return result;
    } catch (e, stack) {
      _logger.error(
        'Payment processing failed',
        e,
        stack,
        {
          'order_id': orderId,
          'user_id': userId,
          'amount': amount,
          'payment_method': paymentMethod,
        },
      );

      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setContexts('payment_error', {
            'order_id': orderId,
            'user_id': userId,
            'amount': amount,
            'payment_method': paymentMethod,
            'error_type': e.runtimeType.toString(),
          });
        },
      );

      await _analytics.logErrorOccurred(
        errorType: 'payment_failed',
        errorMessage: e.toString(),
        userId: userId,
        orderId: orderId,
        paymentId: orderId,
      );

      rethrow;
    }
  }

  /// Wrap delivery assignment with error handling
  Future<T> handleDeliveryAssignment<T>({
    required Future<T> Function() operation,
    required String orderId,
    required String riderId,
  }) async {
    try {
      _logger.info('Starting delivery assignment', data: {
        'order_id': orderId,
        'rider_id': riderId,
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Delivery assignment started',
          data: {'order_id': orderId, 'rider_id': riderId},
          level: SentryLevel.info,
        ),
      );

      final result = await operation();

      _logger.info('Delivery assignment succeeded', data: {
        'order_id': orderId,
        'rider_id': riderId,
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Delivery assignment completed',
          data: {'order_id': orderId, 'rider_id': riderId},
          level: SentryLevel.info,
        ),
      );

      return result;
    } catch (e, stack) {
      _logger.error(
        'Delivery assignment failed',
        e,
        stack,
        {'order_id': orderId, 'rider_id': riderId},
      );

      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setContexts('delivery_error', {
            'order_id': orderId,
            'rider_id': riderId,
            'error_type': e.runtimeType.toString(),
          });
        },
      );

      rethrow;
    }
  }

  /// Wrap inventory operations with error handling
  Future<T> handleInventoryOperation<T>({
    required Future<T> Function() operation,
    required String productId,
    required int quantity,
    String? operationType,
  }) async {
    try {
      _logger.info('Starting inventory operation', data: {
        'product_id': productId,
        'quantity': quantity,
        'operation': operationType,
      });

      final result = await operation();

      _logger.info('Inventory operation succeeded', data: {
        'product_id': productId,
        'quantity': quantity,
      });

      return result;
    } catch (e, stack) {
      _logger.error(
        'Inventory operation failed',
        e,
        stack,
        {
          'product_id': productId,
          'quantity': quantity,
          'operation': operationType,
        },
      );

      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setContexts('inventory_error', {
            'product_id': productId,
            'quantity': quantity,
            'operation': operationType,
            'error_type': e.runtimeType.toString(),
          });
        },
      );

      rethrow;
    }
  }

  /// Wrap wallet operations with error handling
  Future<T> handleWalletOperation<T>({
    required Future<T> Function() operation,
    required String userId,
    required double amount,
    String? operationType,
  }) async {
    setUserContext(userId);

    try {
      _logger.info('Starting wallet operation', data: {
        'user_id': userId,
        'amount': amount,
        'operation': operationType,
      });

      final result = await operation();

      _logger.info('Wallet operation succeeded', data: {
        'user_id': userId,
        'amount': amount,
      });

      return result;
    } catch (e, stack) {
      _logger.error(
        'Wallet operation failed',
        e,
        stack,
        {'user_id': userId, 'amount': amount, 'operation': operationType},
      );

      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setContexts('wallet_error', {
            'user_id': userId,
            'amount': amount,
            'operation': operationType,
            'error_type': e.runtimeType.toString(),
          });
        },
      );

      await _analytics.logErrorOccurred(
        errorType: 'wallet_operation_failed',
        errorMessage: e.toString(),
        userId: userId,
        additionalContext: {'amount': amount, 'operation': operationType},
      );

      rethrow;
    }
  }

  /// Wrap refund operations with error handling
  Future<T> handleRefundOperation<T>({
    required Future<T> Function() operation,
    required String orderId,
    required double refundAmount,
    String? reason,
  }) async {
    if (_currentOrderId == null) {
      setOrderContext(orderId, amount: refundAmount);
    }

    try {
      _logger.info('Starting refund operation', data: {
        'order_id': orderId,
        'refund_amount': refundAmount,
        'reason': reason,
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Refund initiated',
          data: {'order_id': orderId, 'amount': refundAmount, 'reason': reason},
          level: SentryLevel.info,
        ),
      );

      final result = await operation();

      _logger.info('Refund operation succeeded', data: {
        'order_id': orderId,
        'refund_amount': refundAmount,
      });

      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Refund completed',
          data: {'order_id': orderId, 'amount': refundAmount},
          level: SentryLevel.info,
        ),
      );

      return result;
    } catch (e, stack) {
      _logger.error(
        'Refund operation failed',
        e,
        stack,
        {
          'order_id': orderId,
          'refund_amount': refundAmount,
          'reason': reason,
        },
      );

      Sentry.captureException(
        e,
        stackTrace: stack,
        withScope: (scope) {
          scope.setContexts('refund_error', {
            'order_id': orderId,
            'refund_amount': refundAmount,
            'reason': reason,
            'error_type': e.runtimeType.toString(),
          });
        },
      );

      await _analytics.logErrorOccurred(
        errorType: 'refund_failed',
        errorMessage: e.toString(),
        orderId: orderId,
        additionalContext: {'refund_amount': refundAmount, 'reason': reason},
      );

      rethrow;
    }
  }

  // ============================================================================
  // GENERAL ERROR CAPTURE
  // ============================================================================

  /// Capture a general exception with context
  Future<void> captureException(
    Object error,
    StackTrace? stack, {
    String? message,
    Map<String, dynamic>? extraContext,
  }) async {
    _logger.error(message ?? 'Exception occurred', error, stack, extraContext);

    Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        scope.setContexts('general_error', {
          'user_id': _currentUserId ?? 'anonymous',
          'order_id': _currentOrderId ?? 'none',
          'payment_id': _currentPaymentId ?? 'none',
          ...?extraContext,
        });
      },
    );
  }

  /// Capture a warning message
  Future<void> captureWarning(
    String message, {
    Map<String, dynamic>? context,
  }) async {
    _logger.warning(message, data: context);

    Sentry.captureMessage(
      message,
      level: SentryLevel.warning,
      withScope: (scope) {
        scope.setContexts('warning', context ?? {});
      },
    );
  }

  /// Capture an info message (breadcrumb only)
  Future<void> captureInfo(
    String message, {
    Map<String, dynamic>? data,
  }) async {
    _logger.info(message, data: data);

    Sentry.addBreadcrumb(
      Breadcrumb(
        message: message,
        data: data,
        level: SentryLevel.info,
      ),
    );
  }
}

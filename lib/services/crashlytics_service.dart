import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crashlytics Service - Enhanced crash reporting with context
/// Wraps Firebase Crashlytics with additional context management
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Initialize Crashlytics
  /// Must be called in main.dart before runApp()
  Future<void> initialize() async {
    try {
      // Disable Crashlytics in debug mode
      await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      debugPrint('[Crashlytics] Initialized (collection enabled: ${!kDebugMode})');
    } catch (e) {
      debugPrint('[Crashlytics] Initialization error: $e');
    }
  }

  /// Enable/Disable collection at runtime
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await _crashlytics.setCrashlyticsCollectionEnabled(enabled);
      debugPrint('[Crashlytics] Collection enabled: $enabled');
    } catch (e) {
      debugPrint('[Crashlytics] Error setting collection: $e');
    }
  }

  /// Record a user crash (non-fatal error)
  Future<void> recordError({
    required Object error,
    StackTrace? stackTrace,
    String? reason,
    bool fatal = false,
    Map<String, dynamic>? context,
  }) async {
    try {
      // Add context if provided
      if (context != null) {
        for (final entry in context.entries) {
          await _crashlytics.setCustomKey(entry.key, entry.value.toString());
        }
      }

      // Record with reason
      if (reason != null) {
        await _crashlytics.recordError(
          error,
          stackTrace,
          reason: reason,
          fatal: fatal,
        );
      } else {
        await _crashlytics.recordError(
          error,
          stackTrace,
          fatal: fatal,
        );
      }

      debugPrint('[Crashlytics] Error recorded: $error (fatal: $fatal)');
    } catch (e) {
      debugPrint('[Crashlytics] Error recording error: $e');
    }
  }

  /// Record Flutter error
  Future<void> recordFlutterError({
    required FlutterErrorDetails details,
    String? context,
  }) async {
    try {
      if (context != null) {
        await _crashlytics.setCustomKey('flutter_context', context);
      }

      await _crashlytics.recordFlutterError(details);
      debugPrint('[Crashlytics] Flutter error recorded');
    } catch (e) {
      debugPrint('[Crashlytics] Error recording Flutter error: $e');
    }
  }

  /// Set user properties for crash reports
  Future<void> setUserProperties({
    required String userId,
    String? userRole,
    String? shopId,
    String? phoneNumber,
  }) async {
    try {
      await _crashlytics.setUserIdentifier(userId);

      // Set custom user properties
      final properties = {
        'user_id': userId,
        'user_role': userRole ?? 'unknown',
        'shop_id': shopId ?? 'none',
        'phone_number': phoneNumber ?? 'anonymous',
      };

      for (final entry in properties.entries) {
        await _crashlytics.setCustomKey(entry.key, entry.value);
      }

      debugPrint('[Crashlytics] User properties set: $userId');
    } catch (e) {
      debugPrint('[Crashlytics] Error setting user properties: $e');
    }
  }

  /// Clear user data (on logout)
  Future<void> clearUserData() async {
    try {
      await _crashlytics.setUserIdentifier('');
      debugPrint('[Crashlytics] User data cleared');
    } catch (e) {
      debugPrint('[Crashlytics] Error clearing user data: $e');
    }
  }

  /// Set custom error context for debugging
  Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await _crashlytics.setCustomKey(key, value.toString());
      debugPrint('[Crashlytics] Custom key set: $key=$value');
    } catch (e) {
      debugPrint('[Crashlytics] Error setting custom key: $e');
    }
  }

  /// Record order context before payment processing
  Future<void> recordOrderContext({
    required String orderId,
    required String userId,
    required double amount,
    int? itemCount,
    String? shopId,
  }) async {
    try {
      await _crashlytics.setCustomKey('order_id', orderId);
      await _crashlytics.setCustomKey('user_id', userId);
      await _crashlytics.setCustomKey('order_amount', amount.toString());
      if (itemCount != null) {
        await _crashlytics.setCustomKey('item_count', itemCount.toString());
      }
      if (shopId != null) {
        await _crashlytics.setCustomKey('shop_id', shopId);
      }
      debugPrint('[Crashlytics] Order context recorded: $orderId');
    } catch (e) {
      debugPrint('[Crashlytics] Error recording order context: $e');
    }
  }

  /// Record payment context
  Future<void> recordPaymentContext({
    required String paymentId,
    required String orderId,
    required double amount,
    String? paymentMethod,
  }) async {
    try {
      await _crashlytics.setCustomKey('payment_id', paymentId);
      await _crashlytics.setCustomKey('payment_order_id', orderId);
      await _crashlytics.setCustomKey('payment_amount', amount.toString());
      if (paymentMethod != null) {
        await _crashlytics.setCustomKey('payment_method', paymentMethod);
      }
      debugPrint('[Crashlytics] Payment context recorded: $paymentId');
    } catch (e) {
      debugPrint('[Crashlytics] Error recording payment context: $e');
    }
  }

  /// Log breadcrumb (important event before crash)
  Future<void> logBreadcrumb({
    required String message,
    String? category,
    Map<String, dynamic>? data,
  }) async {
    try {
      final breadcrumb = '[$category] $message';
      await _crashlytics.log(breadcrumb);

      if (data != null) {
        for (final entry in data.entries) {
          await _crashlytics.setCustomKey(
            '${category ?? "breadcrumb"}_${entry.key}',
            entry.value.toString(),
          );
        }
      }

      debugPrint('[Crashlytics] Breadcrumb logged: $breadcrumb');
    } catch (e) {
      debugPrint('[Crashlytics] Error logging breadcrumb: $e');
    }
  }

  /// Check if Crashlytics is enabled
  bool isEnabled() => !kDebugMode;

  /// Get Crashlytics instance (for advanced usage)
  FirebaseCrashlytics getInstance() => _crashlytics;
}

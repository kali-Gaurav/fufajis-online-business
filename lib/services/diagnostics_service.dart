import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Centralized diagnostics and logging service
/// Logs to console, Crashlytics, and local file for debugging
class DiagnosticsService {
  static final DiagnosticsService _instance = DiagnosticsService._internal();
  factory DiagnosticsService() => _instance;
  DiagnosticsService._internal();

  /// Log with severity level
  void log(
    String module,
    String message, {
    AppLogSeverity level = AppLogSeverity.info,
    dynamic error,
    StackTrace? stackTrace,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final prefix = _getPrefixForLevel(level);
    final fullMessage = '[$timestamp] [$module] $prefix $message';

    debugPrint(fullMessage);

    // Send to Crashlytics if error level
    if (level == AppLogSeverity.error && error != null) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: '$module: $message',
        printDetails: true,
      );
    }
  }

  /// Log authentication step (numbered flow)
  void logAuthStep(int step, String action, {bool success = true}) {
    final emoji = success ? '✅' : '❌';
    log('Auth', '$step️⃣ $emoji $action', level: AppLogSeverity.info);
  }

  /// Log cart item data
  void logCartItem(Map<String, dynamic> itemData, {bool valid = true}) {
    final status = valid ? '✅' : '🚨 CORRUPTED';
    final json = itemData.toString();
    log('Cart', '$status Item: $json', level: valid ? AppLogSeverity.info : AppLogSeverity.error);
  }

  /// Log distance calculation with coordinates
  void logDistance({
    required double shopLat,
    required double shopLng,
    required double userLat,
    required double userLng,
    required double distanceMeters,
  }) {
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(1);
    log('Distance',
        'Shop: ($shopLat, $shopLng) → User: ($userLat, $userLng) = $distanceKm km',
        level: AppLogSeverity.info);

    // Warning if unrealistic
    if (distanceMeters > 50000) {
      log('Distance', '⚠️ UNREALISTIC: ${distanceKm}km - check coordinates!',
          level: AppLogSeverity.error);
    }
  }

  /// Log API call details
  void logApiCall(String endpoint, {String? method = 'GET', int? statusCode, dynamic error}) {
    if (error != null) {
      log('API', '❌ $method $endpoint failed: $error', level: AppLogSeverity.error, error: error);
    } else {
      log('API', '✅ $method $endpoint ($statusCode)', level: AppLogSeverity.info);
    }
  }

  /// Performance timing
  void logPerformance(String operation, Duration duration) {
    final ms = duration.inMilliseconds;
    final level = ms > 1000 ? AppLogSeverity.warning : AppLogSeverity.info;
    final emoji = ms > 1000 ? '⚠️ SLOW' : '⚡';
    log('Performance', '$emoji $operation took ${ms}ms', level: level);
  }

  String _getPrefixForLevel(AppLogSeverity level) {
    switch (level) {
      case AppLogSeverity.debug:
        return '🔍 DEBUG';
      case AppLogSeverity.info:
        return 'ℹ️  INFO';
      case AppLogSeverity.warning:
        return '⚠️  WARNING';
      case AppLogSeverity.error:
        return '❌ ERROR';
    }
  }
}

enum AppLogSeverity { debug, info, warning, error }

/// Extension for easier logging
extension DiagnosticsExt on String {
  void logDebug(String module) => DiagnosticsService().log(module, this, level: AppLogSeverity.debug);
  void logInfo(String module) => DiagnosticsService().log(module, this, level: AppLogSeverity.info);
  void logWarning(String module) => DiagnosticsService().log(module, this, level: AppLogSeverity.warning);
  void logError(String module, [dynamic error, StackTrace? stackTrace]) =>
      DiagnosticsService().log(module, this, level: AppLogSeverity.error, error: error, stackTrace: stackTrace);
}

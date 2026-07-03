import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class CrashReporter {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Logs a custom diagnostic message that will be attached to subsequent crash reports
  static Future<void> log(String message) async {
    debugPrint('[CrashReporter] LOG: $message');
    await Sentry.addBreadcrumb(
      Breadcrumb(message: message, timestamp: DateTime.now(), level: SentryLevel.info),
    );
  }

  /// Records an uncaught exception or error to Sentry and Firebase Analytics
  static Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    bool fatal = false,
  }) async {
    debugPrint('[CrashReporter] ERROR recorded: $exception');
    if (reason != null) {
      debugPrint('[CrashReporter] Reason: $reason');
    }

    // Report to Sentry
    await Sentry.captureException(
      exception,
      stackTrace: stack,
      withScope: (scope) {
        if (reason != null) {
          scope.setExtra('reason', reason.toString());
        }
        if (fatal) {
          scope.level = SentryLevel.fatal;
        }
      },
    );

    // Log event in Firebase Analytics
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'exception': exception.toString().substring(0, exception.toString().length.clamp(0, 100)),
          'fatal': fatal ? 1 : 0,
          if (reason != null)
            'reason': reason.toString().substring(0, reason.toString().length.clamp(0, 100)),
        },
      );
    } catch (e) {
      debugPrint('[CrashReporter] Failed to send error event to Firebase: $e');
    }
  }

  /// Associates subsequent crash reports and logs with a specific user ID
  static Future<void> setUserId(String userId) async {
    debugPrint('[CrashReporter] Setting User ID: $userId');
    await Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId)));
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      debugPrint('[CrashReporter] Failed to set user ID in Firebase: $e');
    }
  }

  /// Sets key-value pairs for diagnostic context in reports
  static Future<void> setCustomKey(String key, dynamic value) async {
    debugPrint('[CrashReporter] Custom Key: $key = $value');
    await Sentry.configureScope((scope) => scope.setExtra(key, value));
    try {
      await _analytics.setUserProperty(name: key, value: value.toString());
    } catch (e) {
      debugPrint('[CrashReporter] Failed to set user property in Firebase: $e');
    }
  }
}

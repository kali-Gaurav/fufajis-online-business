import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

enum LogLevel { debug, info, warning, error, fatal }

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  void log(String message, {LogLevel level = LogLevel.info, Object? error, StackTrace? stackTrace, Map<String, dynamic>? data}) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [${level.name.toUpperCase()}] $message';
    
    // 1. Console Log (Debug only)
    if (kDebugMode) {
      debugPrint(logMessage);
      if (error != null) debugPrint('Error: $error');
    }

    // 2. Sentry (Error/Fatal/Warning)
    if (level == LogLevel.error || level == LogLevel.fatal) {
      Sentry.captureException(error ?? message, stackTrace: stackTrace, withScope: (scope) {
        if (data != null) scope.setContexts('extra_data', data);
        scope.level = _mapSentryLevel(level);
      });
    } else if (level == LogLevel.warning) {
      Sentry.captureMessage(message, level: SentryLevel.warning, withScope: (scope) {
        if (data != null) scope.setContexts('extra_data', data);
      });
    }

    // 3. Firebase Analytics (Breadcrumb)
    _analytics.logEvent(
      name: 'app_log',
      parameters: {
        'level': level.name,
        'message': message.length > 100 ? message.substring(0, 100) : message,
        ...?data?.map((k, v) => MapEntry(k, v.toString())),
      },
    );
  }

  SentryLevel _mapSentryLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return SentryLevel.debug;
      case LogLevel.info: return SentryLevel.info;
      case LogLevel.warning: return SentryLevel.warning;
      case LogLevel.error: return SentryLevel.error;
      case LogLevel.fatal: return SentryLevel.fatal;
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace, Map<String, dynamic>? data]) {
    log(message, level: LogLevel.error, error: error, stackTrace: stackTrace, data: data);
  }

  void info(String message, {Map<String, dynamic>? data}) {
    log(message, level: LogLevel.info, data: data);
  }

  void warning(String message, {Map<String, dynamic>? data}) {
    log(message, level: LogLevel.warning, data: data);
  }
}

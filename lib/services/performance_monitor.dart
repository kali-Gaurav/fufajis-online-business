import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class PerformanceMonitor {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final Map<String, Stopwatch> _activeStopwatches = {};
  static final DateTime _appStartTime = DateTime.now();

  /// Logs the initial application startup duration
  static Future<void> recordAppStartupTime() async {
    final now = DateTime.now();
    final durationMs = now.difference(_appStartTime).inMilliseconds;
    debugPrint('[PerformanceMonitor] App Startup Time: ${durationMs}ms');

    try {
      await _analytics.logEvent(
        name: 'app_startup_time',
        parameters: {'duration_ms': durationMs},
      );
    } catch (e) {
      debugPrint('[PerformanceMonitor] Failed to log startup time: $e');
    }
  }

  /// Starts a metric stopwatch with a specified name/label
  static void startTrace(String name) {
    if (_activeStopwatches.containsKey(name)) {
      debugPrint(
        '[PerformanceMonitor] Warning: Trace "$name" is already running. Restarting.',
      );
      _activeStopwatches[name]!.reset();
    } else {
      _activeStopwatches[name] = Stopwatch();
    }
    _activeStopwatches[name]!.start();
    debugPrint('[PerformanceMonitor] Trace started: "$name"');
  }

  /// Stops the metric trace and records the duration to Firebase Analytics
  static Future<int?> stopTrace(
    String name, {
    Map<String, dynamic>? additionalParameters,
  }) async {
    final stopwatch = _activeStopwatches[name];
    if (stopwatch == null) {
      debugPrint(
        '[PerformanceMonitor] Error: Trace "$name" was never started.',
      );
      return null;
    }

    stopwatch.stop();
    final durationMs = stopwatch.elapsedMilliseconds;
    _activeStopwatches.remove(name);
    debugPrint(
      '[PerformanceMonitor] Trace finished: "$name" took ${durationMs}ms',
    );

    try {
      final Map<String, Object> params = {
        'trace_name': name,
        'duration_ms': durationMs,
      };
      if (additionalParameters != null) {
        additionalParameters.forEach((key, value) {
          params[key] = value.toString();
        });
      }

      await _analytics.logEvent(name: 'performance_trace', parameters: params);
    } catch (e) {
      debugPrint('[PerformanceMonitor] Failed to log trace "$name": $e');
    }

    return durationMs;
  }

  /// Measures how long an asynchronous function takes to execute
  static Future<T> measureAsync<T>(
    String name,
    Future<T> Function() asyncFunction, {
    Map<String, dynamic>? additionalParameters,
  }) async {
    startTrace(name);
    try {
      final result = await asyncFunction();
      await stopTrace(
        name,
        additionalParameters: {...?additionalParameters, 'status': 'success'},
      );
      return result;
    } catch (e) {
      await stopTrace(
        name,
        additionalParameters: {
          ...?additionalParameters,
          'status': 'failure',
          'error': e.toString().substring(0, e.toString().length.clamp(0, 50)),
        },
      );
      rethrow;
    }
  }
}

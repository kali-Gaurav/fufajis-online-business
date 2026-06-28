import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Performance Monitor Service
/// Tracks performance metrics across the app using Stopwatch and Firebase Performance Monitoring.
///
/// Key metrics tracked:
/// - App startup time (target: <2s)
/// - Order creation latency (target: <2s)
/// - Payment webhook processing (target: <500ms)
/// - Firestore dual-write sync (target: <2s)
/// - Storage upload (target: <5s for 5MB file)
/// - Delivery assignment (target: <3s)
///
/// Usage:
/// ```dart
/// PerformanceMonitor.startTrace('order_creation');
/// // ... create order ...
/// await PerformanceMonitor.stopTrace('order_creation');
/// ```
class PerformanceMonitor {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebasePerformance _firebasePerf = FirebasePerformance.instance;
  static final Map<String, Stopwatch> _activeStopwatches = {};
  static final Map<String, Trace> _activeTraces = {};
  static final DateTime _appStartTime = DateTime.now();

  /// Logs the initial application startup duration
  /// Target: <2 seconds for app launch
  static Future<void> recordAppStartupTime() async {
    final now = DateTime.now();
    final durationMs = now.difference(_appStartTime).inMilliseconds;
    debugPrint('[PerformanceMonitor] App Startup Time: ${durationMs}ms');

    try {
      // Log to Firebase Analytics
      await _analytics.logEvent(
        name: 'app_startup_time',
        parameters: {
          'duration_ms': durationMs,
          'target_ms': 2000,
          'status': durationMs <= 2000 ? 'healthy' : 'slow',
        },
      );

      // Log to Firebase Performance Monitoring
      final trace = _firebasePerf.newTrace('app_startup');
      await trace.start();
      trace.putAttribute('duration_ms', durationMs.toString());
      trace.putAttribute('status', durationMs <= 2000 ? 'healthy' : 'slow');
      await trace.stop();
    } catch (e) {
      debugPrint('[PerformanceMonitor] Failed to log startup time: $e');
    }
  }

  /// Starts a metric stopwatch and Firebase Performance trace
  /// Name should follow pattern: 'service_operation' (e.g., 'order_creation', 'payment_webhook')
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

    // Start Firebase Performance trace
    try {
      final trace = _firebasePerf.newTrace(name);
      trace.start();
      _activeTraces[name] = trace;
    } catch (e) {
      debugPrint('[PerformanceMonitor] Failed to start Firebase trace "$name": $e');
    }

    debugPrint('[PerformanceMonitor] Trace started: "$name"');
  }

  /// Stops the metric trace and records duration to both Firebase Analytics and Performance Monitoring
  /// Returns duration in milliseconds
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
      // Log to Firebase Analytics
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

      // Log to Firebase Performance Monitoring
      if (_activeTraces.containsKey(name)) {
        final trace = _activeTraces[name]!;
        trace.putAttribute('duration_ms', durationMs.toString());

        // Add custom metrics based on trace name
        if (name.contains('order')) {
          trace.putAttribute('target_ms', '2000');
          trace.putAttribute('status', durationMs <= 2000 ? 'healthy' : 'slow');
        } else if (name.contains('payment') || name.contains('webhook')) {
          trace.putAttribute('target_ms', '500');
          trace.putAttribute('status', durationMs <= 500 ? 'healthy' : 'slow');
        } else if (name.contains('delivery')) {
          trace.putAttribute('target_ms', '3000');
          trace.putAttribute('status', durationMs <= 3000 ? 'healthy' : 'slow');
        } else if (name.contains('storage') || name.contains('upload')) {
          trace.putAttribute('target_ms', '5000');
          trace.putAttribute('status', durationMs <= 5000 ? 'healthy' : 'slow');
        }

        if (additionalParameters != null) {
          additionalParameters.forEach((key, value) {
            trace.putAttribute(key, value.toString());
          });
        }

        await trace.stop();
        _activeTraces.remove(name);
      }
    } catch (e) {
      debugPrint('[PerformanceMonitor] Failed to log trace "$name": $e');
    }

    return durationMs;
  }

  /// Measures how long an asynchronous function takes to execute
  /// Automatically wraps with Sentry context for performance debugging
  /// Usage:
  /// ```dart
  /// final order = await PerformanceMonitor.measureAsync(
  ///   'order_creation',
  ///   () => orderService.createOrder(cartData),
  /// );
  /// ```
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

  /// Clear active traces on app shutdown
  static Future<void> cleanup() async {
    for (final trace in _activeTraces.values) {
      try {
        await trace.stop();
      } catch (e) {
        debugPrint('[PerformanceMonitor] Error stopping trace: $e');
      }
    }
    _activeTraces.clear();
    _activeStopwatches.clear();
  }
}

import 'package:flutter/material.dart';
import 'package:fufaji/models/analytics_models.dart';

/// Performance optimization utilities for analytics dashboard
class AnalyticsPerformance {
  /// Cache for expensive calculations
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get cached value if still valid
  static T? getCachedValue<T>(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp != null) {
      if (DateTime.now().difference(timestamp) < _cacheDuration) {
        return _cache[key] as T?;
      } else {
        _cache.remove(key);
        _cacheTimestamps.remove(key);
      }
    }
    return null;
  }

  /// Set cached value
  static void setCachedValue<T>(String key, T value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Optimize chart data points (limit to max 50 for performance)
  static List<ChartDataPoint> optimizeChartData(
    List<ChartDataPoint> data, {
    int maxPoints = 50,
  }) {
    if (data.length <= maxPoints) {
      return data;
    }

    // Sample data evenly
    final step = data.length ~/ maxPoints;
    final optimized = <ChartDataPoint>[];

    for (int i = 0; i < data.length; i += step) {
      optimized.add(data[i]);
    }

    // Always include last point
    if (optimized.isEmpty || optimized.last != data.last) {
      optimized.add(data.last);
    }

    return optimized;
  }

  /// Calculate percentage change efficiently
  static double calculatePercentageChange(double current, double previous) {
    if (previous == 0) return 0;
    return ((current - previous) / previous) * 100;
  }

  /// Format large numbers efficiently
  static String formatLargeNumber(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  /// Debounce function calls
  static Future<T> debounce<T>(
    Future<T> Function() function, {
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    await Future.delayed(delay);
    return await function();
  }

  /// Throttle rapid updates
  static bool _lastUpdateTime = false;
  static void throttleUpdate(VoidCallback callback, {Duration delay = const Duration(milliseconds: 500)}) {
    if (!_lastUpdateTime) {
      callback();
      _lastUpdateTime = true;
      Future.delayed(delay, () {
        _lastUpdateTime = false;
      });
    }
  }
}

/// Performance monitoring for debugging
class PerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, List<int>> _durations = {};

  /// Start measuring performance
  static void start(String label) {
    _timers[label] = Stopwatch()..start();
  }

  /// Stop measuring and log duration
  static int stop(String label) {
    final timer = _timers[label];
    if (timer == null) return 0;

    timer.stop();
    final duration = timer.elapsedMilliseconds;

    _durations.putIfAbsent(label, () => []).add(duration);

    // Print if in debug mode
    if (duration > 100) {
      debugPrint('⏱️ $label: ${duration}ms');
    }

    _timers.remove(label);
    return duration;
  }

  /// Get average duration
  static double getAverageDuration(String label) {
    final durations = _durations[label];
    if (durations == null || durations.isEmpty) return 0;
    return durations.fold<int>(0, (a, b) => a + b) / durations.length;
  }

  /// Clear all measurements
  static void clear() {
    _timers.clear();
    _durations.clear();
  }

  /// Print all measurements
  static void printReport() {
    debugPrint('=== Performance Report ===');
    _durations.forEach((label, durations) {
      final avg = durations.fold<int>(0, (a, b) => a + b) / durations.length;
      final max = durations.reduce((a, b) => a > b ? a : b);
      final min = durations.reduce((a, b) => a < b ? a : b);
      debugPrint('$label: avg=${avg.toStringAsFixed(1)}ms, min=${min}ms, max=${max}ms');
    });
  }
}

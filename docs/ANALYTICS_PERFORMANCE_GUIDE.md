# Analytics Dashboard Performance Guide

## Overview
This guide documents performance optimizations implemented in Iteration 7 for the Analytics Dashboard, targeting <2 second load times and <500ms real-time updates.

## Architecture Optimizations

### 1. Data Loading Strategy

#### Lazy Loading
- Data is loaded on-demand, not all at once
- Critical data (dashboard metrics) loads first
- Secondary data (breakdowns, alerts) loads in parallel
- Use cases: RevenueBreakdown, OrderAnalytics load after main metrics

#### Parallel Loading
```dart
// Load independent data in parallel
await Future.wait([
  _loadDailyAnalytics(),
  _loadRevenueBreakdown(),
  _loadOrderAnalytics(),
  _loadDeliveryMetrics(),
  _loadLowStockAlerts(),
]);
```

#### Caching Strategy
- 5-minute cache for expensive calculations
- Cache cleared on period selection
- Automatic cache expiration based on timestamp
- Use `AnalyticsPerformance.getCachedValue()` and `setCachedValue()`

### 2. Chart Optimization

#### Data Point Limits
- Maximum 50 data points per chart (configurable)
- Data points are sampled evenly for large datasets
- Reduces rendering load and improves scrolling performance

```dart
// Optimize chart data
final optimized = AnalyticsPerformance.optimizeChartData(
  data,
  maxPoints: 50,
);
```

#### Conditional Rendering
- Dots only shown when ≤20 data points
- Grid lines use simplified calculations
- Title calculation only runs once

### 3. Widget Optimization

#### Component Extraction
- Widgets split into smaller, focused components
- Example: `_HeaderRow`, `_BottomRow`, `_PercentageBadge` in MetricCard
- Reduces rebuild scope when state changes

#### Const Constructors
- All widgets use const constructors where possible
- Prevents unnecessary rebuilds
- Example: `const EdgeInsets.all(16)`

#### Stateless Patterns
- Prefer `StatelessWidget` over `StatefulWidget`
- Use `ChangeNotifier` at provider level only
- Move local state to widget properties (immutable)

### 4. Stream Management

#### Subscription Cleanup
- All stream subscriptions tracked in `_subscriptions` list
- Subscriptions canceled in `dispose()` method
- Prevents memory leaks and dangling listeners

```dart
@override
void dispose() {
  for (final subscription in _subscriptions) {
    subscription.cancel();
  }
  _subscriptions.clear();
  super.dispose();
}
```

#### Error Handling in Streams
- Streams have error listeners
- Errors don't crash the app, logged instead
- UI displays graceful error state

### 5. Memory Management

#### Cache Cleanup
- `AnalyticsPerformance.clearCache()` called:
  - On period selection
  - On dispose
  - When cache expires (5 minutes)

#### Resource Disposal
- Dispose patterns implemented in:
  - OptimizedAnalyticsDashboardProvider
  - Dashboard screen (closes subscriptions)
  - Reports provider

### 6. Calculation Optimization

#### Percentage Change
```dart
static double calculatePercentageChange(double current, double previous) {
  if (previous == 0) return 0;
  return ((current - previous) / previous) * 100;
}
```
- Single calculation, cached result
- Handles zero division edge case

#### Number Formatting
```dart
static String formatLargeNumber(num value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}
```
- Efficient display of large numbers
- Reduces text width for better layouts

## Performance Monitoring

### Using PerformanceMonitor

```dart
// Start measuring
PerformanceMonitor.start('loadDailyMetrics');

// Do expensive operation
await loadMetrics();

// Stop and log
final duration = PerformanceMonitor.stop('loadDailyMetrics');
// Output: ⏱️ loadDailyMetrics: 1234ms
```

### Performance Report
```dart
// Get average duration for a task
final avgDuration = PerformanceMonitor.getAverageDuration('loadDailyMetrics');

// Print all measurements
PerformanceMonitor.printReport();
// Output:
// === Performance Report ===
// loadDailyMetrics: avg=1200.0ms, min=1100ms, max=1300ms
```

## Performance Targets

| Metric | Target | Status |
|--------|--------|--------|
| Dashboard Load | <2s | ✅ |
| Real-time Sync | <500ms | ✅ |
| Chart Render | <1s | ✅ |
| Memory Usage | <100MB | ✅ |
| FPS | 60 | ✅ |

## Best Practices

### 1. When Adding New Features
- Use `OptimizedMetricCard` instead of `MetricCard`
- Use `OptimizedTrendChart` instead of `TrendChart`
- Use `OptimizedAnalyticsDashboardProvider` for new screens

### 2. When Loading Data
- Use parallel `Future.wait()` for independent data
- Implement caching with `AnalyticsPerformance`
- Monitor performance with `PerformanceMonitor`

### 3. When Building Widgets
- Extract components into separate classes
- Use const constructors
- Avoid unnecessary rebuilds

### 4. When Managing Streams
- Always track subscriptions
- Cancel in dispose()
- Handle errors gracefully

### 5. When Optimizing Charts
- Limit data points to 50
- Conditionally show dots (≤20 points)
- Cache calculated values

## Testing Performance

### Unit Tests
```dart
test('should load dashboard under 2 seconds', () async {
  final watch = Stopwatch()..start();
  await provider.loadDailyMetrics();
  watch.stop();
  expect(watch.elapsedMilliseconds, lessThan(2000));
});
```

### Integration Tests
- Test full screen navigation and rendering
- Measure time from tap to display
- Monitor memory before/after operations

## Debugging Performance

### Enable Performance Logs
```dart
PerformanceMonitor.start('operation');
// ... do work
final duration = PerformanceMonitor.stop('operation');
```

### Check Cache Hit Rate
```dart
// In development, log cache hits/misses
if (AnalyticsPerformance.getCachedValue<T>(key) != null) {
  debugPrint('Cache hit: $key');
} else {
  debugPrint('Cache miss: $key');
}
```

### Memory Profiling
- Use Dart DevTools Memory profiler
- Look for growing object counts
- Check for subscription leaks

## Common Performance Issues & Solutions

### Issue: Dashboard loads slowly
**Solution:**
1. Check if caching is working (`getCachedValue()`)
2. Verify parallel loading is used
3. Check if data point optimization is active
4. Profile with `PerformanceMonitor`

### Issue: Charts stutter when scrolling
**Solution:**
1. Reduce data points (use `optimizeChartData()`)
2. Hide dots when >20 points
3. Use `const` constructors
4. Profile FPS with DevTools

### Issue: Memory increases over time
**Solution:**
1. Verify stream subscriptions are canceled
2. Check cache is cleared on dispose
3. Look for circular references
4. Use WeakReferences where appropriate

### Issue: Real-time updates lag
**Solution:**
1. Verify Firestore stream latency
2. Check network conditions
3. Reduce number of listeners
4. Use stream debouncing for rapid updates

## Future Optimizations

### Phase 5b (Planned)
- [ ] Implement virtual scrolling for long lists
- [ ] Add image caching layer
- [ ] Implement request deduplication
- [ ] Add offline data synchronization

### Phase 5c (Future)
- [ ] Implement adaptive quality based on network
- [ ] Add predictive caching
- [ ] Implement priority queue for data loading
- [ ] Add A/B testing for performance metrics

## References

- Flutter Performance Best Practices: https://flutter.dev/docs/perf/best-practices
- Dart Performance Guide: https://dart.dev/guides/performance
- BLoC Pattern: https://bloclibrary.dev
- Provider Documentation: https://pub.dev/packages/provider

---

**Last Updated:** 2026-07-12  
**Version:** 1.0  
**Status:** Ready for Production

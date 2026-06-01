# Phase 20: Analytics & Crash Reporting - Implementation Checklist

## Overview
Implement comprehensive analytics and crash reporting.

## Current Status
- ✅ AnalyticsService: Partially implemented
- ⏳ CrashReporter: Needs implementation
- ⏳ PerformanceMonitor: Needs implementation
- ⏳ User properties tracking: Needs implementation
- ⏳ Event tracking: Needs implementation

## Task 20.1: Complete AnalyticsService Implementation
**Status:** Partially Complete
**File:** `lib/services/analytics_service.dart`

### Implementation Steps:
1. [ ] Complete Firebase Analytics setup
2. [ ] Implement screen view tracking
3. [ ] Implement event tracking
4. [ ] Add event parameters
5. [ ] Test analytics tracking
6. [ ] Verify data in Firebase Console

### Code Template:
```dart
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  
  factory AnalyticsService() {
    return _instance;
  }
  
  AnalyticsService._internal();
  
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Initialize analytics
  Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      debugPrint('Analytics initialized');
    } catch (e) {
      debugPrint('Error initializing analytics: $e');
    }
  }

  // Track screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      debugPrint('Screen view logged: $screenName');
    } catch (e) {
      debugPrint('Error logging screen view: $e');
    }
  }

  // Track event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: name,
        parameters: parameters,
      );
      debugPrint('Event logged: $name');
    } catch (e) {
      debugPrint('Error logging event: $e');
    }
  }

  // Track product view
  Future<void> logProductView({
    required String productId,
    required String productName,
    required String category,
    required double price,
  }) async {
    try {
      await logEvent(
        name: 'view_item',
        parameters: {
          'item_id': productId,
          'item_name': productName,
          'item_category': category,
          'price': price,
          'currency': 'INR',
        },
      );
    } catch (e) {
      debugPrint('Error logging product view: $e');
    }
  }

  // Track add to cart
  Future<void> logAddToCart({
    required String productId,
    required String productName,
    required double price,
    required int quantity,
  }) async {
    try {
      await logEvent(
        name: 'add_to_cart',
        parameters: {
          'item_id': productId,
          'item_name': productName,
          'price': price,
          'quantity': quantity,
          'currency': 'INR',
        },
      );
    } catch (e) {
      debugPrint('Error logging add to cart: $e');
    }
  }

  // Track purchase
  Future<void> logPurchase({
    required String orderId,
    required double value,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await logEvent(
        name: 'purchase',
        parameters: {
          'transaction_id': orderId,
          'value': value,
          'currency': 'INR',
          'items': items.length,
        },
      );
    } catch (e) {
      debugPrint('Error logging purchase: $e');
    }
  }

  // Track search
  Future<void> logSearch({
    required String searchTerm,
    int? resultsCount,
  }) async {
    try {
      await logEvent(
        name: 'search',
        parameters: {
          'search_term': searchTerm,
          if (resultsCount != null) 'results_count': resultsCount,
        },
      );
    } catch (e) {
      debugPrint('Error logging search: $e');
    }
  }

  // Track share
  Future<void> logShare({
    required String contentType,
    required String contentId,
  }) async {
    try {
      await logEvent(
        name: 'share',
        parameters: {
          'content_type': contentType,
          'item_id': contentId,
        },
      );
    } catch (e) {
      debugPrint('Error logging share: $e');
    }
  }

  // Set user properties
  Future<void> setUserProperties({
    required String userId,
    required String userRole,
    required String membershipTier,
    required String district,
  }) async {
    try {
      await _analytics.setUserId(userId);
      await _analytics.setUserProperty(name: 'user_role', value: userRole);
      await _analytics.setUserProperty(name: 'membership_tier', value: membershipTier);
      await _analytics.setUserProperty(name: 'district', value: district);
      debugPrint('User properties set');
    } catch (e) {
      debugPrint('Error setting user properties: $e');
    }
  }

  // Clear user data
  Future<void> clearUserData() async {
    try {
      await _analytics.resetAnalyticsData();
      debugPrint('Analytics data cleared');
    } catch (e) {
      debugPrint('Error clearing analytics data: $e');
    }
  }
}
```

## Task 20.2: Implement CrashReporter
**Status:** Not Started
**File:** `lib/services/crash_reporter.dart`

### Code Template:
```dart
class CrashReporter {
  static final CrashReporter _instance = CrashReporter._internal();
  
  factory CrashReporter() {
    return _instance;
  }
  
  CrashReporter._internal();

  Future<void> initialize() async {
    try {
      // Set up Crashlytics
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      
      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      };
      
      // Pass all uncaught async errors
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      
      debugPrint('Crash reporter initialized');
    } catch (e) {
      debugPrint('Error initializing crash reporter: $e');
    }
  }

  // Log error
  Future<void> logError({
    required dynamic error,
    required StackTrace stackTrace,
    String? reason,
    bool fatal = false,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
      );
      debugPrint('Error logged: $error');
    } catch (e) {
      debugPrint('Error logging error: $e');
    }
  }

  // Log message
  Future<void> logMessage(String message) async {
    try {
      await FirebaseCrashlytics.instance.log(message);
      debugPrint('Message logged: $message');
    } catch (e) {
      debugPrint('Error logging message: $e');
    }
  }

  // Set user identifier
  Future<void> setUserId(String userId) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
      debugPrint('User ID set: $userId');
    } catch (e) {
      debugPrint('Error setting user ID: $e');
    }
  }

  // Set custom key
  Future<void> setCustomKey(String key, dynamic value) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
      debugPrint('Custom key set: $key = $value');
    } catch (e) {
      debugPrint('Error setting custom key: $e');
    }
  }

  // Log exception
  Future<void> logException(Exception exception, StackTrace stackTrace) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace,
        fatal: false,
      );
      debugPrint('Exception logged: $exception');
    } catch (e) {
      debugPrint('Error logging exception: $e');
    }
  }
}
```

## Task 20.3: Implement PerformanceMonitor
**Status:** Not Started
**File:** `lib/services/performance_monitor.dart`

### Code Template:
```dart
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  
  factory PerformanceMonitor() {
    return _instance;
  }
  
  PerformanceMonitor._internal();
  
  final FirebasePerformance _performance = FirebasePerformance.instance;
  final Map<String, Stopwatch> _timers = {};

  Future<void> initialize() async {
    try {
      await _performance.setPerformanceCollectionEnabled(true);
      debugPrint('Performance monitor initialized');
    } catch (e) {
      debugPrint('Error initializing performance monitor: $e');
    }
  }

  // Start trace
  void startTrace(String traceName) {
    try {
      _timers[traceName] = Stopwatch()..start();
      debugPrint('Trace started: $traceName');
    } catch (e) {
      debugPrint('Error starting trace: $e');
    }
  }

  // Stop trace
  Future<void> stopTrace(String traceName) async {
    try {
      final stopwatch = _timers[traceName];
      if (stopwatch != null) {
        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds;
        
        final trace = _performance.newTrace(traceName);
        await trace.setMetric('duration', duration);
        await trace.stop();
        
        _timers.remove(traceName);
        debugPrint('Trace stopped: $traceName (${duration}ms)');
      }
    } catch (e) {
      debugPrint('Error stopping trace: $e');
    }
  }

  // Track screen load time
  Future<void> trackScreenLoadTime({
    required String screenName,
    required Duration duration,
  }) async {
    try {
      final trace = _performance.newTrace('screen_load_$screenName');
      await trace.setMetric('load_time', duration.inMilliseconds);
      await trace.stop();
      debugPrint('Screen load time tracked: $screenName (${duration.inMilliseconds}ms)');
    } catch (e) {
      debugPrint('Error tracking screen load time: $e');
    }
  }

  // Track API response time
  Future<void> trackApiResponseTime({
    required String endpoint,
    required Duration duration,
    required int statusCode,
  }) async {
    try {
      final trace = _performance.newTrace('api_$endpoint');
      await trace.setMetric('response_time', duration.inMilliseconds);
      await trace.setMetric('status_code', statusCode);
      await trace.stop();
      debugPrint('API response time tracked: $endpoint (${duration.inMilliseconds}ms)');
    } catch (e) {
      debugPrint('Error tracking API response time: $e');
    }
  }

  // Track memory usage
  Future<void> trackMemoryUsage() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final totalMemory = info.totalMemory ?? 0;
      
      final trace = _performance.newTrace('memory_usage');
      await trace.setMetric('total_memory', totalMemory);
      await trace.stop();
      debugPrint('Memory usage tracked: $totalMemory bytes');
    } catch (e) {
      debugPrint('Error tracking memory usage: $e');
    }
  }

  // Track app startup time
  Future<void> trackAppStartupTime(Duration duration) async {
    try {
      final trace = _performance.newTrace('app_startup');
      await trace.setMetric('startup_time', duration.inMilliseconds);
      await trace.stop();
      debugPrint('App startup time tracked: ${duration.inMilliseconds}ms');
    } catch (e) {
      debugPrint('Error tracking app startup time: $e');
    }
  }
}
```

## Task 20.4: Implement User Properties Tracking
**Status:** Not Started

### Code Template:
```dart
// Add to AnalyticsService
Future<void> setUserProperties({
  required String userId,
  required String userRole,
  required String membershipTier,
  required String district,
  required String appVersion,
  required String deviceModel,
}) async {
  try {
    await _analytics.setUserId(userId);
    
    // User role
    await _analytics.setUserProperty(
      name: 'user_role',
      value: userRole, // customer, owner, delivery
    );
    
    // Membership tier
    await _analytics.setUserProperty(
      name: 'membership_tier',
      value: membershipTier, // bronze, silver, gold, platinum
    );
    
    // Location
    await _analytics.setUserProperty(
      name: 'district',
      value: district,
    );
    
    // App version
    await _analytics.setUserProperty(
      name: 'app_version',
      value: appVersion,
    );
    
    // Device model
    await _analytics.setUserProperty(
      name: 'device_model',
      value: deviceModel,
    );
    
    debugPrint('User properties set for $userId');
  } catch (e) {
    debugPrint('Error setting user properties: $e');
  }
}
```

## Task 20.5: Implement Firebase Analytics Integration
**Status:** Not Started

### Integration Points:

#### 1. Track Screen Views
```dart
// In each screen's initState
@override
void initState() {
  super.initState();
  AnalyticsService().logScreenView(
    screenName: 'home_screen',
    screenClass: 'HomeScreen',
  );
}
```

#### 2. Track User Events
```dart
// Track product view
AnalyticsService().logProductView(
  productId: product.id,
  productName: product.name,
  category: product.category,
  price: product.price,
);

// Track add to cart
AnalyticsService().logAddToCart(
  productId: product.id,
  productName: product.name,
  price: product.price,
  quantity: quantity,
);

// Track purchase
AnalyticsService().logPurchase(
  orderId: order.id,
  value: order.totalAmount,
  items: order.items.map((item) => {
    'item_id': item.productId,
    'item_name': item.productName,
    'price': item.price,
    'quantity': item.quantity,
  }).toList(),
);
```

#### 3. Track Custom Events
```dart
// Track search
AnalyticsService().logSearch(
  searchTerm: 'rice',
  resultsCount: 45,
);

// Track share
AnalyticsService().logShare(
  contentType: 'product',
  contentId: product.id,
);

// Track custom event
AnalyticsService().logEvent(
  name: 'wallet_used',
  parameters: {
    'amount': 500.0,
    'order_id': order.id,
  },
);
```

## Testing Checklist

### Unit Tests
- [ ] Analytics event logging
- [ ] Crash reporting
- [ ] Performance tracking
- [ ] User properties setting

### Integration Tests
- [ ] Screen view tracking works
- [ ] Event tracking works
- [ ] Crash reporting works
- [ ] Performance metrics collected
- [ ] User properties tracked

### Manual Testing
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Verify events in Firebase Console
- [ ] Verify crashes in Crashlytics
- [ ] Verify performance metrics
- [ ] Verify user properties

## Firebase Console Setup

### 1. Enable Firebase Analytics
- Go to Firebase Console
- Select your project
- Go to Analytics
- Enable Analytics

### 2. Enable Crashlytics
- Go to Firebase Console
- Select your project
- Go to Crashlytics
- Enable Crashlytics

### 3. Enable Performance Monitoring
- Go to Firebase Console
- Select your project
- Go to Performance
- Enable Performance Monitoring

## Success Criteria

- [ ] Analytics events are tracked correctly
- [ ] Crashes are reported to Crashlytics
- [ ] Performance metrics are monitored
- [ ] User properties are tracked
- [ ] Analytics dashboard shows data
- [ ] All events have correct parameters
- [ ] Crash reports are detailed
- [ ] Performance alerts work
- [ ] All tests pass
- [ ] No critical bugs

## Estimated Time: 20-30 hours

### Breakdown:
- Analytics service: 6-8 hours
- Crash reporter: 4-6 hours
- Performance monitor: 4-6 hours
- User properties: 2-4 hours
- Integration: 4-6 hours

## Key Events to Track

### User Events
- app_open
- app_close
- user_login
- user_logout
- user_signup

### Product Events
- view_item
- view_item_list
- add_to_cart
- remove_from_cart
- view_cart

### Order Events
- begin_checkout
- add_payment_info
- purchase
- refund

### Wallet Events
- wallet_viewed
- wallet_used
- points_redeemed
- cashback_earned

### Notification Events
- notification_received
- notification_opened
- notification_dismissed

## Next Steps

After completing Phase 20:
1. Review all implementations
2. Run comprehensive tests
3. Fix any bugs
4. Optimize performance
5. Deploy to production
6. Monitor analytics and crashes
7. Gather user feedback
8. Plan future enhancements


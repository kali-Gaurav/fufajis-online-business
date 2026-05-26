# Phase 16: Notifications System - Implementation Checklist

## Overview
Implement comprehensive notification system with FCM, notification center, and settings.

## Current Status
- ✅ NotificationProvider: Implemented
- ✅ NotificationCenter: 80% complete
- ✅ NotificationSettingsScreen: 80% complete
- ✅ OfflineNotificationQueueService: Implemented
- ⏳ FCM setup: Needs completion
- ⏳ Notification types: Needs implementation
- ⏳ Deep linking: Needs implementation

## Task 16.1: Complete NotificationCenter UI
**Status:** 80% Complete
**File:** `lib/screens/customer/notification_center.dart`

### Remaining Work:
- [ ] Complete notification list UI
- [ ] Add notification type icons
- [ ] Implement mark as read functionality
- [ ] Add delete functionality
- [ ] Implement pagination
- [ ] Add empty state UI
- [ ] Test with various notification types

### Code to Add:
```dart
// Add notification type icon helper
Widget _getNotificationIcon(NotificationType? type) {
  switch (type) {
    case NotificationType.orderUpdate:
      return Icon(Icons.local_shipping, color: Colors.blue);
    case NotificationType.promotion:
      return Icon(Icons.local_offer, color: Colors.orange);
    case NotificationType.priceDrop:
      return Icon(Icons.trending_down, color: Colors.green);
    case NotificationType.shopUpdate:
      return Icon(Icons.store, color: Colors.purple);
    case NotificationType.systemMessage:
      return Icon(Icons.info, color: Colors.grey);
    default:
      return Icon(Icons.notifications, color: Colors.blue);
  }
}

// Add notification tile
ListTile(
  leading: _getNotificationIcon(notification.type),
  title: Text(notification.title),
  subtitle: Text(notification.body),
  trailing: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        _formatTime(notification.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (!notification.isRead)
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
    ],
  ),
  onTap: () {
    if (!notification.isRead) {
      notificationProvider.markAsRead(user.id, notification.id);
    }
    if (notification.deepLink != null) {
      context.push(notification.deepLink!);
    }
  },
)
```

## Task 16.2: FCM Setup and Configuration
**Status:** Not Started
**File:** `lib/services/notification_service.dart`

### Implementation Steps:
1. [ ] Configure FCM in Firebase Console
2. [ ] Download google-services.json
3. [ ] Add FCM configuration to pubspec.yaml
4. [ ] Implement token refresh handling
5. [ ] Set up topic subscriptions
6. [ ] Test foreground notifications
7. [ ] Test background notifications

### Firebase Console Setup:
1. Go to Firebase Console
2. Select your project
3. Go to Cloud Messaging
4. Create a new topic for each notification type
5. Download google-services.json
6. Place in android/app/ directory

### Code to Add:
```dart
// lib/services/notification_service.dart
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  Future<void> initialize() async {
    // Request permission
    await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    // Get token
    final token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundNotification(message);
    });
    
    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });
    
    // Handle initial message
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }
  
  void _handleForegroundNotification(RemoteMessage message) {
    debugPrint('Foreground notification: ${message.notification?.title}');
    // Show local notification
  }
  
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.data}');
    // Handle deep link
  }
}
```

## Task 16.3: Complete NotificationSettingsScreen
**Status:** 80% Complete
**File:** `lib/screens/customer/notification_settings_screen.dart`

### Remaining Work:
- [ ] Complete the settings UI
- [ ] Add notification type toggles
- [ ] Implement quiet hours picker
- [ ] Add sound selection
- [ ] Add vibration toggle
- [ ] Implement save functionality
- [ ] Test settings persistence

### Code Template:
```dart
// Add to notification settings screen
Column(
  children: [
    // Order Updates Toggle
    SwitchListTile(
      title: const Text('Order Updates'),
      subtitle: const Text('Receive updates about your orders'),
      value: notificationProvider.settings.orderUpdates,
      onChanged: (value) {
        notificationProvider.updateOrderUpdates(value);
      },
    ),
    
    // Promotions Toggle
    SwitchListTile(
      title: const Text('Promotions'),
      subtitle: const Text('Receive promotional offers'),
      value: notificationProvider.settings.promotions,
      onChanged: (value) {
        notificationProvider.updatePromotions(value);
      },
    ),
    
    // Price Drops Toggle
    SwitchListTile(
      title: const Text('Price Drops'),
      subtitle: const Text('Get notified when prices drop'),
      value: notificationProvider.settings.priceDrops,
      onChanged: (value) {
        notificationProvider.updatePriceDrops(value);
      },
    ),
    
    // Quiet Hours
    ListTile(
      title: const Text('Quiet Hours'),
      subtitle: Text(
        '${notificationProvider.settings.quietHoursStart.format(context)} - '
        '${notificationProvider.settings.quietHoursEnd.format(context)}',
      ),
      onTap: () => _showQuietHoursPicker(context),
    ),
  ],
)
```

## Task 16.4: Implement Notification Types
**Status:** Not Started
**File:** `lib/services/notification_service.dart`

### Notification Types to Implement:
1. [ ] Order notifications (Placed, Confirmed, Shipped, Delivered)
2. [ ] Promotion notifications (New deals, Price drops)
3. [ ] Alert notifications (Low stock, Expiry, Inventory)
4. [ ] System notifications (App updates, Maintenance)

### Code Template:
```dart
// Notification type enums
enum NotificationType {
  orderPlaced,
  orderConfirmed,
  orderShipped,
  orderDelivered,
  newPromotion,
  priceDrop,
  lowStock,
  expiryAlert,
  systemUpdate,
}

// Send notification function
Future<void> sendNotification({
  required String userId,
  required NotificationType type,
  required String title,
  required String body,
  Map<String, dynamic>? data,
  String? deepLink,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'type': type.toString(),
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': data,
          'deepLink': deepLink,
        });
  } catch (e) {
    debugPrint('Error sending notification: $e');
  }
}
```

## Task 16.5: Offline Notification Queue
**Status:** Service Complete, Integration Needed
**File:** `lib/services/offline_notification_queue_service.dart`

### Integration Points:
- [ ] Verify offline queue implementation
- [ ] Test offline notification queueing
- [ ] Test notification sync when online
- [ ] Add offline indicator to notification center
- [ ] Test with various network conditions

### Code to Verify:
```dart
// Check that offline queue service has these methods:
// - queueNotification()
// - deliverQueuedNotifications()
// - getQueuedNotifications()
// - clearQueue()
```

## Firebase Functions to Create

### Function 1: Send Order Notifications
**File:** `functions/src/order-notifications.ts`

```typescript
export const sendOrderNotification = functions
  .firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    if (oldData.status !== newData.status) {
      const userId = newData.customerId;
      const status = newData.status;
      
      let title = '';
      let body = '';
      
      switch (status) {
        case 'confirmed':
          title = 'Order Confirmed';
          body = 'Your order has been confirmed';
          break;
        case 'shipped':
          title = 'Order Shipped';
          body = 'Your order is on the way';
          break;
        case 'delivered':
          title = 'Order Delivered';
          body = 'Your order has been delivered';
          break;
      }
      
      if (title) {
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            type: 'orderUpdate',
            title: title,
            body: body,
            timestamp: admin.firestore.Timestamp.now(),
            isRead: false,
            data: {
              orderId: context.params.orderId,
              status: status,
            },
            deepLink: `/orders/${context.params.orderId}`,
          });
      }
    }
  });
```

## Testing Checklist

### Unit Tests
- [ ] Notification model creation
- [ ] Notification type parsing
- [ ] Settings serialization/deserialization
- [ ] Quiet hours calculation

### Widget Tests
- [ ] Notification center displays correctly
- [ ] Notification list renders
- [ ] Settings screen renders
- [ ] Empty state shows

### Integration Tests
- [ ] FCM token is obtained
- [ ] Foreground notifications are handled
- [ ] Background notifications are handled
- [ ] Notification taps trigger deep links
- [ ] Offline notifications are queued
- [ ] Queued notifications are delivered

### Manual Testing
- [ ] Test on Android device
- [ ] Test on iOS device
- [ ] Test foreground notifications
- [ ] Test background notifications
- [ ] Test offline queueing
- [ ] Test notification settings
- [ ] Test quiet hours

## Success Criteria

- [ ] Notifications display in real-time
- [ ] Notification settings are saved and respected
- [ ] Offline notifications are queued and synced
- [ ] Notification center shows all notifications
- [ ] Unread count updates correctly
- [ ] All notification types work
- [ ] Deep linking works
- [ ] Quiet hours are respected
- [ ] All tests pass
- [ ] No critical bugs

## Estimated Time: 30-40 hours

### Breakdown:
- Complete notification center UI: 6-8 hours
- FCM setup: 4-6 hours
- Notification settings: 4-6 hours
- Notification types: 6-8 hours
- Offline queue integration: 4-6 hours
- Firebase Functions: 4-6 hours
- Testing: 6-8 hours

## Next Phase
After completing Phase 16, move to Phase 17: Admin Panel


# Complete Notification + Chat System - Integration Guide

## 🎯 QUICK START

You now have 3 new services to integrate:
1. **OrderNotificationService** - Auto-triggers notifications on order events
2. **ChatSuggestionsService** - Provides smart questions in chat
3. **ChatWithSuggestions Widget** - Enhanced chat UI with suggestions

---

## 📋 STEP-BY-STEP INTEGRATION

### Step 1: Integrate OrderNotificationService into OrderService

**File**: `lib/services/order_service.dart`

#### 1a. Add import at top:
```dart
import 'order_notification_service.dart';
```

#### 1b. Create instance in OrderService:
```dart
class OrderService {
  final OrderNotificationService _orderNotification = OrderNotificationService();
  // ... rest of class
}
```

#### 1c. Hook into createOrder() method:
Find the `createOrder()` method and add after successful Firestore write:

```dart
Future<void> createOrder(OrderModel order) async {
  try {
    // ... existing order creation code ...
    
    // EXISTING: Save order to Firestore
    await _firestore.collection('orders').doc(order.id).set(order.toMap());
    
    // ADD THIS: Trigger notifications
    await _orderNotification.notifyOrderConfirmed(order);
    
    debugPrint('[OrderService] Order created: ${order.id}');
  } catch (e) {
    debugPrint('[OrderService] Error creating order: $e');
    rethrow;
  }
}
```

#### 1d. Hook into updateOrderStatus() method:
Find where order status is updated and add:

```dart
Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
  try {
    final orderDoc = await _firestore.collection('orders').doc(orderId).get();
    final order = OrderModel.fromMap(orderDoc.data()!);
    final previousStatus = order.status;
    
    // Update status in Firestore
    order.status = newStatus;
    await _firestore.collection('orders').doc(orderId).update({
      'status': newStatus.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // ADD THIS: Trigger status change notification
    await _orderNotification.notifyOrderStatusChanged(order, previousStatus);
    
    debugPrint('[OrderService] Order status updated: $newStatus');
  } catch (e) {
    debugPrint('[OrderService] Error updating status: $e');
    rethrow;
  }
}
```

#### 1e. Hook into delivery confirmation:
When marking order as delivered, add:

```dart
// When order is marked as delivered
await _orderNotification.notifyDeliveryComplete(order);
```

---

### Step 2: Integrate ChatWithSuggestions Widget into Chat Screen

**File**: `lib/screens/customer/support_chat_screen.dart`

#### 2a. Add imports:
```dart
import '../../widgets/chat_with_suggestions.dart';
import '../../services/chat_suggestions_service.dart';
```

#### 2b. Replace existing chat UI with enhanced version:

```dart
// REPLACE the chat body with:
@override
Widget build(BuildContext context) {
  return ChatWithSuggestions(
    order: widget.order,  // Pass the order
    chatMessages: _buildChatMessageList(),  // Your existing message widget
    messageController: _messageController,
    onQuestionSelected: (question) {
      // Optional: Track which suggestions user selects
      debugPrint('[Chat] User selected: $question');
    },
    onSendMessage: (message) async {
      // Send message logic
      await _chatService.sendMessage(
        chatId: widget.chatId,
        message: message,
        senderId: currentUser.id,
        type: 'text',
      );
    },
  );
}
```

---

### Step 3: Display Invoice in Chat

**File**: `lib/models/chat_message_model.dart`

Ensure your ChatMessageModel has an invoice field:

```dart
class ChatMessage {
  final String id;
  final String type; // text, image, invoice, systemMessage
  final String content;
  
  // Add invoice support
  final Map<String, dynamic>? invoice;
  
  ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    this.invoice,
    // ... other fields
  });
}
```

---

### Step 4: Update NotificationProvider

**File**: `lib/providers/notification_provider.dart`

Add method to get suggestions for current order:

```dart
class NotificationProvider extends ChangeNotifier {
  final ChatSuggestionsService _suggestionsService = ChatSuggestionsService();
  
  List<SuggestedQuestion> getSuggestionsForOrder(OrderModel order) {
    return _suggestionsService.getSuggestedQuestions(order);
  }
}
```

---

## 🧪 TESTING THE INTEGRATION

### Test Case 1: Order Confirmation Flow
```
1. Customer places order
2. Verify:
   ✓ In-app notification appears
   ✓ Chat created automatically
   ✓ Welcome message in chat
   ✓ Suggested questions shown
   ✓ WhatsApp message received (if configured)
```

### Test Case 2: Status Update
```
1. Employee marks order as "packed"
2. Verify:
   ✓ Customer gets notification
   ✓ System message in chat: "Order is being packed"
   ✓ Notification shows in notification center
```

### Test Case 3: Chat Suggestions
```
1. Open chat for order in "outForDelivery" status
2. Verify:
   ✓ Suggested questions appear (Where's my order?, When will it arrive?)
   ✓ Tapping suggestion shows response
   ✓ Can ask follow-up questions
```

### Test Case 4: Invoice in Chat
```
1. Mark order as delivered
2. Verify:
   ✓ Invoice message appears in chat
   ✓ Shows breakdown (subtotal, tax, delivery, discount, total)
   ✓ Download button works
```

---

## 🔌 FIREBASE CONFIGURATION

### Collections to Create:
```
Firestore
├── users/
│   └── {userId}/
│       ├── notifications/
│       │   └── {notificationId}
│       └── settings/
│           └── notifications
├── chats/
│   └── {chatId}/
│       └── messages/
│           └── {messageId}
├── orders/ (existing)
└── notification_delivery_log/ (new for audit)
```

### Firestore Rules for New Collections:

```firestore
// notification_delivery_log - audit trail
match /notification_delivery_log/{logId} {
  allow read: if isAdmin();
  allow create: if isSignedIn();
  allow delete: if false;
}
```

---

## 📱 NOTIFICATION TEMPLATES

### Order Confirmed
```
Title: ✅ Order #A2B3 Confirmed
Body: We received your order. Expected delivery: Tomorrow by 10 PM
Data: {
  type: 'orderConfirmed',
  orderId: 'order_123',
  estimatedDelivery: '2026-06-10T22:00:00Z'
}
```

### Out for Delivery
```
Title: 🚗 Your order is out for delivery!
Body: Expected by 4 PM. Real-time tracking »
Data: {
  type: 'outForDelivery',
  orderId: 'order_123'
}
```

### Delivered
```
Title: ✅ Delivered!
Body: Order #A2B3 delivered. Download invoice »
Data: {
  type: 'delivered',
  orderId: 'order_123'
}
```

---

## ⚙️ CONFIGURATION OPTIONS

### In OrderNotificationService:

```dart
// Customize notification content
OrderNotificationService().notifyOrderConfirmed(order);
// Changes order status to "confirmed" and sends notifications

// Suggest reorder
OrderNotificationService().suggestReorder(
  customerId: 'user_123',
  productName: 'Milk',
  productId: 'product_456',
  daysAgo: 3,
);

// Notify price drop
OrderNotificationService().notifyPriceDrop(
  customerId: 'user_123',
  productName: 'Atta',
  oldPrice: 300,
  newPrice: 250,
);
```

---

## 🎨 UI CUSTOMIZATION

### Customize Suggestion Chips

In `ChatWithSuggestions.dart`, modify `_buildSuggestionChip()`:

```dart
// Change colors, sizes, shapes
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
    borderRadius: BorderRadius.circular(20),
  ),
  // ... rest of widget
)
```

### Customize Invoice Display

In `ChatInvoiceMessage`, modify styles:

```dart
// Change invoice appearance, add branding, reorder fields
// Modify colors, fonts, layout
```

---

## 📊 MONITORING & ANALYTICS

### Track Notification Delivery

The system automatically logs all notification deliveries. Query:

```firestore
db.collection('notification_delivery_log')
  .where('type', '==', 'orderConfirmed')
  .where('timestamp', '>=', startDate)
  .get()
```

### Monitor Chat Suggestions Usage

Add to `ChatSuggestionsService`:

```dart
Future<void> logSuggestionUsed(String suggestionId, String orderId) async {
  await FirebaseFirestore.instance
    .collection('analytics')
    .collection('chat_suggestions')
    .add({
      'suggestionId': suggestionId,
      'orderId': orderId,
      'timestamp': FieldValue.serverTimestamp(),
    });
}
```

---

## 🚀 PRODUCTION CHECKLIST

- [ ] All services imported and instantiated
- [ ] Order notifications integrated into OrderService
- [ ] Chat UI updated with ChatWithSuggestions
- [ ] Firestore collections created
- [ ] Security rules updated
- [ ] WhatsApp integration tested (if enabled)
- [ ] SMS service configured (if enabled)
- [ ] Invoice generation working
- [ ] Notification permission requests added
- [ ] FCM topic subscriptions working
- [ ] Offline queue (Hive) tested
- [ ] Push notifications tested on real device
- [ ] Chat suggestions appear correctly for each order status
- [ ] Invoice downloads work
- [ ] System messages appear in chat on status changes
- [ ] Notification center displays all notifications
- [ ] Delivery tracking updates appear in real-time

---

## 🐛 TROUBLESHOOTING

### "Notification not appearing"
- Check FCM token is stored correctly
- Verify app has notification permissions
- Check Firestore rules allow write access
- Check device internet connectivity

### "Chat suggestions not showing"
- Verify order model is passed correctly
- Check ChatSuggestionsService is imported
- Verify order status is recognized
- Check message controller is not focused (suggestions hide when typing)

### "Invoice not sending"
- Verify InvoiceService generates PDF
- Check file storage path exists
- Verify Firestore write permissions
- Check chat message model supports invoice type

### "WhatsApp notifications failing"
- Verify WhatsApp Business Account setup
- Check API credentials are valid
- Verify phone number format is correct
- Check message template is approved

---

## 📝 NEXT STEPS

1. **Implement Phase 2** - Enhanced chat features
   - Typing indicators
   - Message search
   - Attachment support

2. **Implement Phase 3** - Broadcast system
   - Cloud Function for broadcasting
   - Promotion scheduling
   - A/B testing

3. **Implement Phase 4** - Smart prompts
   - AI-powered responses
   - Context-aware suggestions
   - Multi-language support

4. **Analytics**
   - Track notification open rates
   - Monitor chat response times
   - Measure customer satisfaction

---

## 📞 SUPPORT

For issues or questions:
1. Check the test cases above
2. Review error logs in Firestore
3. Test with Firebase Emulator
4. Check WhatsApp/SMS service status
5. Verify Firestore security rules

---

## 🎯 SUCCESS METRICS

After integration, track:
- **Notification delivery rate**: Should be >95%
- **Chat message response time**: Should be <5 minutes
- **Suggestion tap rate**: Should be >30%
- **Invoice download rate**: Should be >70%
- **Customer satisfaction**: Track via feedback requests


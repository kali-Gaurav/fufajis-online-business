# Complete Notification + Chat + Invoice System - Implementation Plan

## 📋 OVERVIEW
Build an end-to-end notification, messaging, and automated invoice delivery system for a real e-commerce app.

---

## 🎯 CORE FEATURES

### 1. **Notification System**
- ✅ Push notifications via FCM (Firebase Cloud Messaging)
- ✅ Local notifications when app is open
- ✅ Offline queue with Hive (retry when online)
- ✅ WhatsApp/SMS fallback channels
- ⏳ Automatic triggers on order status changes
- ⏳ Broadcast promotions to customers
- ⏳ Smart suggested questions/prompts
- ⏳ Notification settings (quiet hours, frequency)

### 2. **Chat System**
- ✅ Order-linked customer support chat
- ✅ Role-based access (only customers can initiate)
- ✅ Firestore real-time messaging
- ✅ Message types: text, image, invoice, system
- ⏳ Auto-welcome message on order chat creation
- ⏳ Typing indicators
- ⏳ Internal notes (staff-only)
- ⏳ Auto-invoice delivery through chat
- ⏳ Voice notes support
- ⏳ Suggested quick-reply templates

### 3. **Invoice System**
- ✅ PDF generation (A4 and thermal formats)
- ✅ QR code for order tracking
- ✅ Tax calculations
- ⏳ Auto-generation on payment success
- ⏳ Auto-delivery via chat on package delivery
- ⏳ Auto-send via WhatsApp
- ⏳ Email delivery option
- ⏳ Return policy attachment

### 4. **Suggested Questions/Prompts**
- ⏳ Order status tracking ("Where is my order?")
- ⏳ Return/refund questions
- ⏳ Payment issues ("Order didn't go through")
- ⏳ Delivery concerns ("Package damaged")
- ⏳ Product recommendations
- ⏳ Smart timing (suggest only when relevant)

---

## 🔄 NOTIFICATION WORKFLOW

### Order Placement Flow
```
Customer places order
    ↓
OrderService.createOrder() ✅
    ↓
[MISSING] Send confirmation notification
    ↓
[MISSING] Create order-linked chat
    ↓
[MISSING] Send WhatsApp confirmation
    ↓
[MISSING] Generate & store invoice
```

### Order Status Update Flow
```
Employee updates order status (packed, outForDelivery, delivered)
    ↓
OrderService.updateStatus() ✅
    ↓
[MISSING] Trigger status change notification
    ↓
[MISSING] Insert system message in chat
    ↓
[MISSING] Send WhatsApp status update
    ↓
[IF DELIVERED] Send invoice via chat
```

### Broadcast Promotion Flow
```
Owner creates broadcast promotion
    ↓
BroadcastNotificationScreen ✅
    ↓
[MISSING] Send to Cloud Function
    ↓
[MISSING] Cloud Function sends to FCM topic
    ↓
All subscribed customers receive notification
```

---

## 💬 CHAT WORKFLOW

### Customer Initiates Chat
```
Customer starts support chat
    ↓
ChatService.createChat() ✅
    ↓
Auto-welcome message sent
    ↓
Employee assigned (optional)
    ↓
Messages in real-time ✅
```

### Order-Linked Chat
```
Order placed
    ↓
Chat created automatically ✅
    ↓
[MISSING] Welcome: "Hi! Questions about your order?"
    ↓
Customer can ask about:
  - Order status
  - Return/refund
  - Delivery concerns
    ↓
[MISSING] Quick-reply suggestions appear
```

### Invoice via Chat
```
Package delivered
    ↓
Employee confirms delivery
    ↓
[MISSING] Invoice PDF generated
    ↓
[MISSING] Invoice sent as chat message
    ↓
[MISSING] Download button in chat
    ↓
[MISSING] Also sent via WhatsApp
```

---

## 📱 UI/UX COMPONENTS NEEDED

### Customer Side
1. **Order Status Notifications**
   - "Your order is confirmed!" 
   - "Your order is being packed"
   - "Out for delivery"
   - "Delivered!" + Download invoice link

2. **Suggested Questions**
   - Prompt appears in chat: "Common questions..."
   - Quick buttons: "Where's my order?", "Return this item", "Track delivery"

3. **Chat Interface**
   - Message list with timestamps
   - Order summary at top
   - Quick-reply templates
   - Invoice display with download

4. **Notification Center**
   - List of all notifications
   - Mark as read
   - Group by type (orders, promotions, system)

### Employee/Owner Side
1. **Chat Management**
   - List of active conversations
   - Unread count badges
   - Status: open, active, closed
   - Mark as resolved

2. **Broadcast Notifications**
   - Form to create promotion
   - Select audience (all users, specific district, specific category)
   - Schedule or send now
   - Track delivery status

3. **Order Status Updates**
   - Batch update orders
   - Auto-send notifications on status change
   - View notification delivery log

---

## 🏗️ ARCHITECTURE

### Service Layer
```
NotificationService (exists ✅)
├── Initialize FCM
├── Send local notifications
├── Handle deep linking
└── Show notification

NotificationProvider (exists ✅)
├── Real-time Firestore listeners
├── Notification settings management
├── Topic subscriptions
└── Offline queue

ChatService (exists ✅)
├── Create/update conversations
├── Send/receive messages
├── Search messages
└── Manage participants

OrderService (exists ✅)
├── Create orders
├── Update status
└── [MISSING] Trigger notifications

InvoiceService (exists ✅)
├── Generate PDF
├── Store in Firestore
└── [MISSING] Auto-trigger on delivery

[NEW] OrderNotificationService
├── Trigger on order events
├── Send via multiple channels
└── Log delivery attempts

[NEW] ChatNotificationService
├── Welcome messages
├── Suggested prompts
└── Invoice messages
```

### Firebase Collections
```
users/{userId}/
├── notifications/
│   └── {notificationId}
├── settings/
│   └── notifications (preferences)
└── chat/ (shortcut to chats)

chats/{chatId}/
├── messages/{messageId}
├── metadata (conversation info)
└── participants

orders/{orderId}/
├── items/
├── tracking/
└── invoice (reference)

notification_queue/ (offline)
notification_delivery_log/ (audit)
```

---

## 🎯 IMPLEMENTATION PHASES

### Phase 1: Notification Triggers (Priority: HIGH)
- [ ] Create OrderNotificationService
- [ ] Hook into OrderService.createOrder()
- [ ] Hook into OrderService.updateStatus()
- [ ] Send notifications on each order event
- [ ] Create system messages in chat
- [ ] Test with real Firebase project

### Phase 2: Chat Enhancement (Priority: HIGH)
- [ ] Auto-create chat on order placement
- [ ] Auto-welcome message
- [ ] Quick-reply suggestions
- [ ] Invoice message insertion
- [ ] Typing indicators UI

### Phase 3: Invoice Automation (Priority: MEDIUM)
- [ ] Trigger on payment success
- [ ] Auto-generate PDF
- [ ] Send via chat message
- [ ] Send via WhatsApp
- [ ] Add email delivery option

### Phase 4: Broadcast System (Priority: MEDIUM)
- [ ] Create Cloud Function for broadcasting
- [ ] Integrate BroadcastNotificationScreen
- [ ] FCM topic subscriptions
- [ ] Delivery tracking
- [ ] Analytics

### Phase 5: Smart Prompts (Priority: LOW)
- [ ] Suggested questions on order screen
- [ ] Quick-reply templates in chat
- [ ] Context-aware suggestions
- [ ] AI-powered responses (optional)

### Phase 6: Voice Notes & Advanced (Priority: LOW)
- [ ] Voice note recording
- [ ] Speech-to-text
- [ ] Attachment support in chat
- [ ] Message search/filter

---

## 📊 NOTIFICATION TYPES

```dart
enum NotificationType {
  // Order lifecycle
  orderConfirmed,        // "Your order #123 is confirmed!"
  orderPacked,           // "Your order is being packed"
  outForDelivery,        // "Your order is out for delivery"
  delivered,             // "Your order delivered! ✅"
  cancelled,             // "Order cancelled"
  
  // Customer support
  returnInitiated,       // "Return request received"
  refundProcessed,       // "Refund of ₹X processed"
  
  // Promotions
  priceDropped,          // "Price dropped on Milk ₹45→₹40"
  backInStock,           // "Atta is back in stock!"
  promotion,             // "50% off on Rice this weekend!"
  
  // System
  paymentReceived,       // "Payment confirmed for order #123"
  invoiceReady,          // "Invoice ready for download"
  deliveryIssue,         // "Delivery attempted but failed"
  
  // Smart suggestions
  reorderSuggestion,     // "Your staples need refill!"
  similarProducts,       // "You might like these products"
}
```

---

## 🔔 NOTIFICATION TEMPLATE EXAMPLES

### Order Confirmed
```
Title: "✅ Order #A2B3 Confirmed"
Body: "We received your order. Expected delivery: Tomorrow by 10 PM"
Data: {
  type: "orderConfirmed",
  orderId: "order_123",
  estimatedDelivery: "2026-06-10T22:00:00Z"
}
Action: Tap → Order Details Screen
```

### Out for Delivery
```
Title: "🚗 Your order is out for delivery!"
Body: "Your order is on the way. Expected by 4 PM. Track real-time »"
Data: {
  type: "outForDelivery",
  orderId: "order_123",
  trackingUrl: "..."
}
Action: Tap → Tracking Map
```

### Delivered + Invoice
```
Title: "✅ Delivered! Download Invoice"
Body: "Order #A2B3 delivered by Raj Kumar. Thank you for shopping!"
Data: {
  type: "delivered",
  orderId: "order_123",
  invoiceUrl: "gs://..."
}
Action: Tap → Order Details with Invoice
```

### Suggested Reorder
```
Title: "🛒 Smart Kitchen: Milk running low?"
Body: "You usually buy milk every 3 days. Your last purchase was 2 days ago."
Data: {
  type: "reorderSuggestion",
  productId: "milk_123",
  suggestionType: "stapleRefill"
}
Action: Tap → Product Detail with Quick "Add to Cart"
```

### Promotion
```
Title: "🎉 Weekend Special!"
Body: "50% off on Rice, Flour & Oils. Limited time offer »"
Data: {
  type: "promotion",
  promotionId: "promo_456",
  categoryId: "staples",
  discount: 50
}
Action: Tap → Category with Filter Applied
```

---

## 💾 FIRESTORE DATA STRUCTURES

### Notification Document
```dart
{
  id: "notif_001",
  title: "✅ Order Confirmed",
  body: "Your order #A2B3 is confirmed",
  type: "orderConfirmed",
  
  // Recipients
  recipientId: "user_123",
  recipientRole: "customer",
  
  // Content
  data: {
    orderId: "order_123",
    estimatedDelivery: "2026-06-10T22:00:00Z"
  },
  
  // Delivery tracking
  channels: {
    fcm: { sent: true, timestamp: "..." },
    whatsapp: { sent: false, error: "..." },
    sms: { sent: false, reason: "disabled" },
    inApp: { sent: true, timestamp: "..." }
  },
  
  // Status
  isRead: false,
  readAt: null,
  createdAt: "2026-06-09T14:00:00Z",
  expiresAt: "2026-06-16T14:00:00Z"
}
```

### Chat Message with Invoice
```dart
{
  id: "msg_789",
  orderId: "order_123",
  
  type: "invoice", // text | image | invoice | systemMessage | internalNote
  senderId: "user_456", // Employee ID
  content: "Here's your invoice for order #A2B3",
  
  invoice: {
    documentId: "invoice_123",
    fileName: "Invoice_A2B3.pdf",
    storageUrl: "gs://...",
    amount: 1250,
    tax: 150,
    total: 1400
  },
  
  attachments: [...],
  createdAt: "2026-06-10T18:30:00Z"
}
```

---

## 🧪 TESTING SCENARIOS

### Test 1: Order Placed → Notification Triggers
1. Place order as customer
2. Verify:
   - Chat created automatically
   - Welcome message appears
   - FCM notification sent
   - In-app notification created

### Test 2: Order Status Update → Broadcast + Chat
1. Employee marks order as "packed"
2. Verify:
   - Notification sent to customer
   - System message in chat: "Order is being packed"
   - WhatsApp notification sent
   - Notification appears in both FCM and in-app

### Test 3: Package Delivered → Invoice Sent
1. Employee confirms delivery
2. Verify:
   - Invoice PDF generated
   - Sent as chat message
   - Available for download in order screen
   - WhatsApp link sent

### Test 4: Chat Quick Replies
1. Customer taps "Where's my order?"
2. Verify:
   - Message sent to chat
   - System response with tracking
   - Order status displayed

### Test 5: Offline → Online → Delivery
1. Disable internet, place order
2. Enable internet
3. Verify:
   - Queued notifications sent from Hive cache
   - No duplicate notifications
   - All channels eventually delivered

---

## 🚀 DEPLOYMENT CHECKLIST

- [ ] Update NotificationService with icon fallback (already done ✅)
- [ ] Create OrderNotificationService
- [ ] Integrate with OrderService
- [ ] Create Cloud Functions for broadcasting
- [ ] Set up WhatsApp Business Account (Phase 2+)
- [ ] Test FCM with real Firebase project
- [ ] Set up Firestore security rules for notifications
- [ ] Create notification templates
- [ ] Train staff on broadcast notifications
- [ ] Set up monitoring/logging
- [ ] Create user documentation
- [ ] Beta test with select users

---

## 📈 METRICS TO TRACK

- Notification delivery rate (FCM vs WhatsApp vs SMS)
- Push notification open rate
- Chat message response time
- Customer satisfaction with notifications
- Broadcast promotion conversion rate
- Invoice download rate
- False positive/negative alerts

---

## 🎓 EXAMPLE IMPLEMENTATION

See Phase 1 implementation files:
- `OrderNotificationService.dart` - Notification triggers
- `OrderChatAutomation.dart` - Chat creation & messages
- Enhanced `OrderService.dart` - Integration points


# Complete Integration Wiring Diagram

## 🔌 HOW ALL COMPONENTS WIRE TOGETHER

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CUSTOMER PLACES ORDER                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                        OrderService.createOrder()
                                    ↓
        ┌───────────────────────────────────────────────────────┐
        │                                                         │
        ↓                                                         ↓
  Save to Firestore                          [NEW] OrderNotificationService
        ↓                                      .notifyOrderConfirmed()
  Validate & Deduct Wallet                                       ↓
        ↓                                    ┌─────────────────────────────┐
  Allocate Stock                             │                             │
        ↓                                    ↓                             ↓
  📝 Order Record Created                 ChatService          NotificationService
                                         .createChat()         .sendFCMNotif()
                                             ↓                      ↓
                                       ✅ Chat Created      📱 Push Notification
                                             ↓              Sent to Customer
                                     System Message:
                                   "Hi! Questions about
                                    your order?"
                                             ↓
                                    ChatSuggestionsService
                                    .getSuggestedQuestions()
                                             ↓
                                    💡 4-5 Suggestions
                                       appear in chat


┌─────────────────────────────────────────────────────────────────────────┐
│                     ORDER STATUS UPDATE (e.g., "packed")                 │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                    OrderService.updateOrderStatus()
                                    ↓
                    Update Firestore: status = "packed"
                                    ↓
        ┌───────────────────────────────────────────────────────┐
        │                                                         │
        ↓                                                         ↓
  [NEW] OrderNotificationService                        WhatsApp Service
  .notifyOrderStatusChanged()                                   ↓
        ↓                                              Send WhatsApp: "packed"
     ┌──┴──┬──────────┬──────────┐
     ↓     ↓          ↓          ↓
  FCM    Chat    Firestore   WhatsApp
  Notif  System  Audit Log   Message
  "📦    Message "status:    "Your order
  Packed"  in      packed,    is packed"
         Chat     timestamp"


┌─────────────────────────────────────────────────────────────────────────┐
│                 CUSTOMER OPENS CHAT - SEES SUGGESTIONS                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                         ChatWithSuggestions Widget
                         (Custom built for this)
                                    ↓
                ┌───────────────────────────────────┐
                │                                   │
                ↓                                   ↓
          Order Header               ChatSuggestionsService
          (Order #, Status)          .getSuggestedQuestions()
          with Status Badge                       ↓
          (Colored: green/red)       📋 Suggested Questions
                                       based on order status:
                                       • "Where's my order?"
                                       • "Can I cancel?"
                                       • "When will it arrive?"
                                       
                                       ↓ (User taps one)
                                       
                                       Check if auto-response
                                       ↓
                                       Show dialog OR
                                       Send message
                                       
        
        Customer Message Input
        (Hide suggestions when typing)
              ↓
         Send message
              ↓
         ChatService.sendMessage()
              ↓
         Store in Firestore
         & notify employee


┌─────────────────────────────────────────────────────────────────────────┐
│              ORDER DELIVERED - INVOICE DELIVERY AUTOMATION               │
└─────────────────────────────────────────────────────────────────────────┘
                                    ↓
                OrderService.updateOrderStatus("delivered")
                                    ↓
        ┌───────────────────────────────────────────────────────┐
        │                                                         │
        ↓                                                         ↓
  [NEW] OrderNotificationService              InvoiceService
  .notifyDeliveryComplete()                  .generateInvoice()
        ↓                                             ↓
    ┌───┴───┬────────┬────────┐             📄 PDF Generated
    ↓       ↓        ↓        ↓
  FCM    Chat     WhatsApp  Firebase
  Notif   Message  Link     Storage
  "✅   "Invoice              ↓
  Del."  attached!"   Send WhatsApp:
         + Download   "Invoice ready"
         button       + Link


┌─────────────────────────────────────────────────────────────────────────┐
│                     COMPLETE DATA FLOW DIAGRAM                          │
└─────────────────────────────────────────────────────────────────────────┘

SERVICES INTEGRATION:

OrderService (existing + enhanced)
    │
    ├─→ [NEW] OrderNotificationService
    │         │
    │         ├─→ ChatService (existing)
    │         │   └─→ Firestore: chats/{chatId}/messages
    │         │
    │         ├─→ ChatSuggestionsService (new)
    │         │   └─→ In-memory suggestions
    │         │
    │         ├─→ NotificationService (existing)
    │         │   └─→ Local notifications
    │         │
    │         ├─→ WhatsAppNotificationService (existing)
    │         │   └─→ Twilio/WhatsApp API
    │         │
    │         └─→ Firestore
    │             └─→ notification_delivery_log
    │
    └─→ Firestore
        └─→ orders/{orderId}
            └─→ orders/{orderId}/chats/{chatId}
                └─→ chats/{chatId}/messages


┌─────────────────────────────────────────────────────────────────────────┐
│                    UI COMPONENT HIERARCHY                                │
└─────────────────────────────────────────────────────────────────────────┘

ChatWithSuggestions (NEW WIDGET)
    │
    ├─→ _buildOrderHeader()
    │   └─→ Order #, Status badge, View Details button
    │
    ├─→ _buildSuggestionsPanel()
    │   ├─→ "💡 Suggested Questions" header
    │   └─→ [Horizontal list of suggestion chips]
    │       └─→ _buildSuggestionChip() × 4
    │           ├─→ Emoji + Question text
    │           └─→ onTap → Show dialog or send
    │
    ├─→ [ChatMessages widget] (existing)
    │   ├─→ Text messages
    │   ├─→ System messages (order status changes)
    │   └─→ ChatInvoiceMessage (NEW)
    │       ├─→ Invoice breakdown
    │       └─→ Download button
    │
    └─→ _buildMessageInput()
        ├─→ Attachment button
        ├─→ Text input (TextField)
        ├─→ Send button
        └─→ onChanged → Hide/show suggestions


┌─────────────────────────────────────────────────────────────────────────┐
│                    FIRESTORE COLLECTION STRUCTURE                        │
└─────────────────────────────────────────────────────────────────────────┘

Firestore Database:

orders/
├── {orderId}
│   ├── id, orderNumber, customerId, status
│   ├── items[], totalAmount, createdAt, updatedAt
│   ├── deliveredAt, otpHash, riderName, trackingLocation
│   └── chats/ (subcollection)
│       └── {chatId}
│           ├── id, createdAt, participantIds
│           └── messages/ (subcollection)
│               └── {messageId}
│                   ├── senderId, text, type (text|invoice|system)
│                   ├── invoice {amount, tax, delivery, discount, total}
│                   ├── timestamp, read

chats/
├── {chatId}
│   ├── id, orderId, createdAt, lastMessage
│   ├── participantIds: [customerId, employeeId, ...]
│   └── messages/ (subcollection)

notification_delivery_log/ (NEW)
├── {logId}
│   ├── type: "orderConfirmed" | "statusChanged" | "deliveryComplete"
│   ├── orderId, customerId
│   ├── channels: ["fcm", "whatsapp", "sms", "inapp"]
│   ├── status: "sent" | "failed" | "pending"
│   ├── deliveryTimestamp
│   └── metadata: {errorMessage?, retryCount?, ...}

notifications/
├── {userId}/
│   └── {notificationId}
│       ├── type, title, body, orderId
│       ├── read: boolean
│       ├── createdAt


┌─────────────────────────────────────────────────────────────────────────┐
│                    EXECUTION FLOW - CONCRETE EXAMPLE                     │
└─────────────────────────────────────────────────────────────────────────┘

[14:00] Customer places order #A2B3
  ↓
  OrderService.createOrder(order)
  ↓
  Order saved: orders/order_001 {
    orderNumber: "A2B3",
    customerId: "cust_123",
    status: "OrderStatus.pending",
    ...
  }
  ↓
  [NEW] OrderNotificationService.notifyOrderConfirmed(order)
  ↓
  ├─→ ChatService.createChat(orderId, customerId)
  │   ├─→ Create chat document
  │   ├─→ Add system message: "Hi! Questions about your order?"
  │   └─→ Return chatId: "chat_20260609_001"
  │
  ├─→ NotificationService.sendLocalNotification(order)
  │   └─→ Show in-app: "✅ Order #A2B3 Confirmed"
  │
  ├─→ Send FCM to topic "order_20260609_001"
  │   └─→ Payload: {type: "orderConfirmed", orderId: "order_001"}
  │
  ├─→ WhatsAppNotificationService.sendInvoice(phoneNumber)
  │   └─→ API call to Twilio
  │       └─→ Message sent to +919876543210
  │
  └─→ FirebaseFirestore.collection('notification_delivery_log').add({
      type: "orderConfirmed",
      orderId: "order_001",
      channels: ["fcm", "whatsapp", "inapp"],
      status: "sent",
      deliveryTimestamp: now
  })

[14:15] Customer opens chat
  ↓
  ChatWithSuggestions widget builds
  ↓
  ├─→ _buildOrderHeader()
  │   └─→ Shows: "Order #A2B3 | ✅ Confirmed"
  │
  ├─→ ChatSuggestionsService.getSuggestedQuestions(order)
  │   ├─→ Order status is "pending" → return [
  │   │   SuggestedQuestion(question: "✏️ Can I modify my order?", ...),
  │   │   SuggestedQuestion(question: "❌ Can I cancel?", ...),
  │   │   SuggestedQuestion(question: "📍 Where is my order?", ...),
  │   │   SuggestedQuestion(question: "📍 Will it deliver to my address?", ...)
  │   │ ]
  │   └─→ Display as 4 chips
  │
  ├─→ Display chat messages (including system message from step 1)
  │
  └─→ Message input area
      └─→ When user taps "Can I modify?" chip:
          ├─→ getChatbotResponse("Can I modify?", order)
          ├─→ Response: "Yes, you can modify your order before confirmation..."
          ├─→ Show in dialog
          └─→ User can proceed or ask more questions

[15:30] Employee marks order as "outForDelivery"
  ↓
  OrderService.updateOrderStatus("outForDelivery")
  ↓
  Update Firestore: orders/order_001.status = "OrderStatus.outForDelivery"
  ↓
  [NEW] OrderNotificationService.notifyOrderStatusChanged(order, previousStatus)
  ↓
  ├─→ Generate OTP, store hash
  │
  ├─→ ChatService.addSystemMessage(chatId, "Order is out for delivery!")
  │   └─→ Firebase: chats/chat_001/messages/{msgId} {
  │       type: "system",
  │       text: "Order is out for delivery!",
  │       timestamp: now
  │     }
  │
  ├─→ NotificationService.sendLocalNotification("🚗 Out for Delivery")
  │
  ├─→ Send FCM to topic "order_001"
  │   └─→ Payload: {type: "statusChanged", status: "outForDelivery"}
  │
  ├─→ WhatsAppNotificationService.sendDeliveryOtpWithTracking()
  │   └─→ Send OTP via WhatsApp
  │
  └─→ Update ChatSuggestionsService cache for this order
      └─→ Next time chat opens, shows: "Where's my order?", "ETA?", etc.

[Customer opens chat again - suggestions have changed!]
  ↓
  ChatWithSuggestions rebuilds
  ├─→ ChatSuggestionsService.getSuggestedQuestions(order)
  │   ├─→ Order status is now "outForDelivery" → return [
  │   │   SuggestedQuestion(question: "📍 Where is my order?", ...),
  │   │   SuggestedQuestion(question: "⏰ What time will it arrive?", ...),
  │   │   SuggestedQuestion(question: "📞 Contact rider", ...)
  │   │ ]
  │
  └─→ Display NEW suggested questions (context-aware!)


┌─────────────────────────────────────────────────────────────────────────┐
│                        SUCCESS METRICS                                   │
└─────────────────────────────────────────────────────────────────────────┘

After integration, track these KPIs:

✅ Notification System
   • Delivery rate: >95%
   • Avg delivery time: <2 seconds
   • FCM vs WhatsApp split: Monitor channel effectiveness

✅ Chat System
   • Chat creation rate: 100% (every order has chat)
   • Avg response time: <5 minutes (staff)
   • Message throughput: Monitor Firestore usage

✅ Suggestions System
   • Suggestion tap rate: >30%
   • Auto-response accuracy: >90%
   • Escalation rate: <10%

✅ Invoice System
   • Invoice generation: 100% on delivery
   • Download rate: >70%
   • WhatsApp delivery: >90%

✅ Customer Experience
   • CSAT score: >4.5/5
   • Support ticket reduction: >40%
   • Chat sentiment: Positive >80%


═══════════════════════════════════════════════════════════════════════════

## Summary

Everything is wired together through:

1. **OrderService** (existing) - triggers notifications on order events
2. **OrderNotificationService** (new) - orchestrates multi-channel delivery
3. **ChatService** (existing) - manages real-time messaging
4. **ChatSuggestionsService** (new) - provides context-aware questions
5. **ChatWithSuggestions** (new) - enhanced UI with suggestions
6. **Firestore** - central source of truth

When an order event happens:
Order created → Notifications triggered → Chat created → Suggestions appear

The entire system is event-driven, reliable, and scalable.

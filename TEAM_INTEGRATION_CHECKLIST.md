# Order Core Engine - Team Integration Checklist

**For**: Teams 2-8 (Fulfillment, Delivery, Analytics, Invoicing, Returns, Notifications, Mobile)  
**Reference**: `ORDER_CORE_IMPLEMENTATION_GUIDE.md`  
**Date**: June 2026

---

## Team 2: Fulfillment (Packing & QA)

### Setup Checklist
- [ ] Clone latest code from `lib/repositories/order_repository.dart`
- [ ] Import OrderModel, OrderStatus, OrderRepository
- [ ] Add `import 'package:fufajis_online/repositories/order_repository.dart';`
- [ ] Set up singleton instance: `final repo = OrderRepository();`

### Integration Points

#### 1. Get Pending Orders for Employee
```dart
final employeeId = currentUser.id;
final pendingOrders = await repo.getPendingOrdersForEmployee(employeeId);

// Display in employee work queue screen
// Filter by: pending, confirmed, processing
```

#### 2. Listen to Real-time Orders
```dart
repo.watchOrdersByStatus('OrderStatus.processing')
    .listen((orders) {
      // Update employee dashboard
      // Show new orders as they arrive
    });
```

#### 3. Mark Order as Packed
```dart
// After physical packing verification:
await repo.updateOrderStatus(
  orderId,
  'OrderStatus.packed',
  note: 'Order packed and verified',
  actorId: employeeId,
  actorRole: 'employee',
  actorName: currentEmployee.name,
);
```

#### 4. Store Packing Proof
```dart
// After taking photos:
await repo.updateOrder(orderId, {
  'packingProof': {
    'photoUrls': [url1, url2, url3],
    'packedAt': FieldValue.serverTimestamp(),
    'packedBy': employeeId,
    'qcApproved': true,
    'approvedBy': supervisorId,
  },
});
```

#### 5. Handle Packing Errors
```dart
// If item is damaged/expired:
try {
  await repo.updateOrder(orderId, {
    'items': items.map((item) {
      if (item.productId == damageProductId) {
        return {...item, 'status': 'damaged'};
      }
      return item;
    }).toList(),
  });
  
  // Request customer approval for substitute
  // Or trigger cancellation if no substitute
} catch (e) {
  print('Update failed: $e');
}
```

### QA Checklist
- [ ] Verify employee sees only their assigned orders
- [ ] Verify photos upload and store correctly
- [ ] Verify status updates appear in customer's app instantly
- [ ] Verify timeline shows "Packed" entry with timestamp
- [ ] Verify system prevents packing already-packed orders
- [ ] Verify offline packing queues correctly
- [ ] Verify supervisor can approve/reject packing

---

## Team 3: Delivery (Logistics & Tracking)

### Setup Checklist
- [ ] Clone latest code from `lib/repositories/order_repository.dart`
- [ ] Import OrderModel, OrderRepository
- [ ] Add location services: `import 'package:geolocator/geolocator.dart';`
- [ ] Set up background location tracking

### Integration Points

#### 1. Get Delivery Agent's Assignments
```dart
final agentId = currentUser.id;
final assignedOrders = await repo.getAssignedOrdersForDeliveryAgent(agentId);

// Show pickup list for the day
// Display address, customer name, phone
// Show preferred time slot
```

#### 2. Mark Order as Out For Delivery
```dart
// When agent picks up order:
await repo.updateOrderStatus(
  orderId,
  'OrderStatus.outForDelivery',
  note: 'Picked up from shop',
  actorId: agentId,
  actorRole: 'delivery_agent',
  actorName: currentAgent.name,
);
```

#### 3. Update Live Location
```dart
// Background service polls GPS every 30 seconds:
Timer.periodic(Duration(seconds: 30), (_) async {
  final position = await Geolocator.getCurrentPosition();
  
  await repo.updateDeliveryStatus(
    orderId,
    position.latitude,
    position.longitude,
    'OrderStatus.outForDelivery',
  );
  
  // Customer receives update with ETA
});
```

#### 4. OTP Delivery Verification
```dart
// Before handing package:
final order = await repo.getOrderById(orderId);
print('OTP: ${order!.otp}');

// After customer provides OTP:
if (customerOtp == order.otp) {
  await repo.markDelivered(
    orderId,
    otpVerified: 'verified',
    deliveredAt: DateTime.now(),
  );
  
  // Order marked as DELIVERED
  // Return window opens (7 days)
  // Payment collected if COD
} else {
  print('Invalid OTP, try again');
}
```

#### 5. Handle Delivery Issues
```dart
// If order can't be delivered:
if (customerNotHome) {
  // Reschedule delivery
  await repo.updateOrder(orderId, {
    'scheduledDeliveryDate': tomorrow,
    'timeSlot': rescheduledSlot,
    'notes': 'Customer not home',
  });
} else if (customerRefused) {
  // Initiate return to shop
  await repo.updateOrderStatus(
    orderId,
    'OrderStatus.returned',
    note: 'Customer refused delivery',
    actorId: agentId,
  );
}
```

### Real-time Tracking
```dart
// Customer sees live location:
repo.watchOrder(orderId)
    .listen((order) {
      // Update map marker
      mapController.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(order.liveLocation.latitude,
                 order.liveLocation.longitude),
        ),
      );
    });
```

### QA Checklist
- [ ] Verify GPS polling runs in background (even if app closed)
- [ ] Verify location updates appear on customer map in <5 seconds
- [ ] Verify OTP generated and displayed correctly
- [ ] Verify OTP expires after 3 failed attempts
- [ ] Verify delivery timestamp recorded accurately
- [ ] Verify offline delivery updates queue correctly
- [ ] Verify agent can reschedule delivery
- [ ] Verify COD payment recorded correctly

---

## Team 4: Analytics & Reporting

### Setup Checklist
- [ ] Clone latest code from `lib/repositories/order_repository.dart`
- [ ] Import OrderRepository, OrderStats
- [ ] Set up daily jobs for metrics calculation
- [ ] Create analytics collection in Firestore

### Integration Points

#### 1. Daily Revenue Tracking
```dart
// Run daily (00:01 AM):
final dailyRevenue = await repo.getDailyRevenue();
final dailyCount = await repo.getDailyOrderCount();

// Store in analytics collection:
await FirebaseFirestore.instance
    .collection('analytics')
    .doc('daily_${DateTime.now().toString().split(' ')[0]}')
    .set({
      'date': DateTime.now(),
      'totalRevenue': dailyRevenue,
      'orderCount': dailyCount,
      'averageOrderValue': dailyRevenue / dailyCount,
    });
```

#### 2. Customer Lifetime Value
```dart
// Calculate for each customer:
Future<void> updateCustomerLTV(String customerId) async {
  final stats = await repo.getCustomerOrderStats(customerId);
  
  final churnRisk = stats.lastOrderDate!.isBefore(
    DateTime.now().subtract(Duration(days: 90)),
  ) ? 'high' : 'low';
  
  await FirebaseFirestore.instance
      .collection('customer_analytics')
      .doc(customerId)
      .set({
        'totalOrders': stats.totalOrders,
        'lifetimeValue': stats.totalSpent,
        'averageOrderValue': stats.averageOrderValue,
        'lastOrderDate': stats.lastOrderDate,
        'churnRisk': churnRisk,
        'repurchaseProbability': calculateRepurchaseProbability(stats),
      });
}
```

#### 3. Product Popularity
```dart
// Listen to delivered orders and count items:
repo.watchOrdersByStatus('OrderStatus.delivered')
    .listen((deliveredOrders) {
      final productCounts = <String, int>{};
      
      for (final order in deliveredOrders) {
        for (final item in order.items) {
          productCounts[item.productId] = 
            (productCounts[item.productId] ?? 0) + item.quantity;
        }
      }
      
      // Update product popularity metrics
      updateProductMetrics(productCounts);
    });
```

#### 4. Order Fulfillment SLA
```dart
// Track delivery time:
for (final order in allOrders) {
  if (order.status == OrderStatus.delivered) {
    final sla = order.deliveredAt!.difference(order.createdAt);
    
    final slaStatus = sla.inHours <= 24 ? 'met' : 'breached';
    
    await analytics.collection('sla_metrics').add({
      'orderId': order.id,
      'fulfillmentHours': sla.inHours,
      'status': slaStatus,
      'createdDate': order.createdAt,
    });
  }
}
```

#### 5. Refund & Return Analysis
```dart
// Track return rate:
final allDeliveredOrders = await repo.getOrdersByStatus('OrderStatus.delivered');
final allReturnedOrders = await repo.getOrdersByStatus('OrderStatus.returned');

final returnRate = (allReturnedOrders.length / allDeliveredOrders.length) * 100;

await analytics.collection('quality_metrics').doc('returns').set({
  'totalDelivered': allDeliveredOrders.length,
  'totalReturned': allReturnedOrders.length,
  'returnRate': returnRate,
  'topReturnReasons': calculateTopReasons(allReturnedOrders),
});
```

### Dashboard Queries
```dart
// For admin dashboard:
final yesterday = DateTime.now().subtract(Duration(days: 1));
final sevenDaysAgo = DateTime.now().subtract(Duration(days: 7));

final yesterday_revenue = await analytics
    .collection('daily_metrics')
    .where('date', isGreaterThan: yesterday)
    .get();

final sevenDay_trend = await analytics
    .collection('daily_metrics')
    .where('date', isGreaterThan: sevenDaysAgo)
    .orderBy('date')
    .get();
```

### QA Checklist
- [ ] Verify daily revenue calculated correctly
- [ ] Verify customer LTV updates overnight
- [ ] Verify product metrics reflect all delivered items
- [ ] Verify SLA tracking accurate (time is from created to delivered)
- [ ] Verify return rate calculation (delivered orders only)
- [ ] Verify dashboard loads within 2 seconds
- [ ] Verify analytics queries use indexes
- [ ] Verify no duplicate metrics stored

---

## Team 5: Invoicing & Documents

### Setup Checklist
- [ ] Clone latest code from `lib/repositories/order_repository.dart`
- [ ] Add PDF generation: `import 'package:pdf/pdf.dart';`
- [ ] Add printing: `import 'package:printing/printing.dart';`
- [ ] Set up Firebase Storage for invoice PDFs

### Integration Points

#### 1. Listen to Delivered Orders
```dart
// Generate invoices for delivered orders:
repo.watchOrdersByStatus('OrderStatus.delivered')
    .listen((deliveredOrders) async {
      for (final order in deliveredOrders) {
        // Skip if invoice already generated
        if (order.invoiceUrl != null) continue;
        
        // Generate invoice
        await generateAndStoreInvoice(order);
      }
    });
```

#### 2. Generate Invoice PDF
```dart
Future<String> generateAndStoreInvoice(OrderModel order) async {
  // Create PDF document
  final pdf = pw.Document();
  
  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        children: [
          pw.Text('Invoice #${order.orderNumber}'),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(),
            children: [
              // Header row
              pw.TableRow(
                children: [
                  pw.Text('Item'),
                  pw.Text('Qty'),
                  pw.Text('Price'),
                  pw.Text('Total'),
                ],
              ),
              // Item rows
              for (final item in order.items)
                pw.TableRow(
                  children: [
                    pw.Text(item.productName),
                    pw.Text('${item.quantity}'),
                    pw.Text('₹${item.price}'),
                    pw.Text('₹${item.totalPrice}'),
                  ],
                ),
              // Total row
              pw.TableRow(
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(),
                  pw.SizedBox(),
                  pw.Text('₹${order.totalAmount}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Thank you for your order!'),
        ],
      ),
    ),
  );
  
  // Save to Firebase Storage
  final pdfBytes = await pdf.save();
  final storageRef = FirebaseStorage.instance
      .ref('invoices/${order.id}.pdf');
  
  await storageRef.putData(pdfBytes);
  final downloadUrl = await storageRef.getDownloadURL();
  
  // Update order with invoice URL
  await repo.updateOrder(order.id, {
    'invoiceUrl': downloadUrl,
  });
  
  // Send email to customer
  await sendInvoiceEmail(order.customerEmail, downloadUrl);
  
  return downloadUrl;
}
```

#### 3. Email Invoice
```dart
Future<void> sendInvoiceEmail(String email, String invoiceUrl) async {
  // Use cloud function or email service
  await FirebaseFunctions.instance
      .httpsCallable('sendInvoiceEmail')
      .call({
        'to': email,
        'invoiceUrl': invoiceUrl,
        'subject': 'Your Invoice from Fufaji',
      });
}
```

#### 4. Generate Packing Slip
```dart
// Similar to invoice but for fulfillment center:
Future<void> generatePackingSlip(OrderModel order) async {
  // Include: order number, items, qty, address
  // Print via thermal printer at shop
}
```

#### 5. Generate Return Label
```dart
// When order is returned:
Future<void> generateReturnLabel(OrderModel order) async {
  // Include: order number, return RMA, address, QR code
  // Email to customer
  // Print for delivery agent
}
```

### QA Checklist
- [ ] Verify invoice PDF generated for all delivered orders
- [ ] Verify PDF includes all order details (items, prices, total)
- [ ] Verify download link works
- [ ] Verify invoice URL stored in order document
- [ ] Verify email sent successfully
- [ ] Verify packing slip prints to thermal printer
- [ ] Verify return label has QR code
- [ ] Verify no invoice generated if already exists

---

## Team 6: Returns & Refunds

### Setup Checklist
- [ ] Clone latest code from `lib/repositories/order_repository.dart`
- [ ] Import OrderModel, OrderStatus
- [ ] Set up return window timers (7 days)
- [ ] Connect to refund processing system

### Integration Points

#### 1. Listen to Delivery Events
```dart
// Start return window when delivered:
repo.watchOrder(orderId)
    .listen((order) async {
      if (order.status == OrderStatus.delivered && 
          !order.returnWindowOpened) {
        // Open return window for 7 days
        await startReturnWindow(orderId);
      }
    });
```

#### 2. Process Return Request
```dart
Future<void> requestReturn(String orderId, String reason) async {
  final order = await repo.getOrderById(orderId);
  
  // Validate: must be within 7 days
  final deliveredAt = order!.deliveredAt!;
  final daysSinceDelivery = DateTime.now()
      .difference(deliveredAt)
      .inDays;
  
  if (daysSinceDelivery > 7) {
    throw Exception('Return window closed');
  }
  
  // Create return request
  await FirebaseFirestore.instance
      .collection('returns')
      .add({
        'orderId': orderId,
        'customerId': order.customerId,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
  
  // Update order status
  await repo.updateOrderStatus(
    orderId,
    'OrderStatus.returned',
    note: reason,
  );
  
  // Generate return label
  await generateReturnLabel(order);
}
```

#### 3. Track Return Shipment
```dart
// Delivery agent picks up return:
await repo.updateOrder(orderId, {
  'returnPickupStatus': 'picked_up',
  'returnPickupDate': FieldValue.serverTimestamp(),
  'returnTrackingNumber': trackingNumber,
});

// Return arrives at warehouse:
await repo.updateOrder(orderId, {
  'returnPickupStatus': 'received_warehouse',
  'returnReceivedDate': FieldValue.serverTimestamp(),
});
```

#### 4. Quality Check & Refund
```dart
// QC team inspects returned item:
await repo.updateOrder(orderId, {
  'returnQCStatus': 'approved', // or 'rejected'
  'returnQCDate': FieldValue.serverTimestamp(),
  'returnQCNotes': 'Item in good condition',
});

// Approve refund:
if (qcApproved) {
  // Process refund
  await processRefund(order);
  
  // Update order to REFUNDED
  await repo.updateOrderStatus(
    orderId,
    'OrderStatus.refunded',
    note: 'Return processed, refund initiated',
  );
  
  // Add to wallet
  await walletService.addToWallet(
    userId: order.customerId,
    amount: order.totalAmount,
    transactionType: 'return_refund',
    orderReference: orderId,
  );
}
```

#### 5. Return Dashboard
```dart
// Pending returns:
final pendingReturns = await FirebaseFirestore.instance
    .collection('returns')
    .where('status', isEqualTo: 'pending')
    .orderBy('createdAt')
    .get();

// Return rate metrics:
final week_returns = await FirebaseFirestore.instance
    .collection('orders')
    .where('status', isEqualTo: 'OrderStatus.returned')
    .where('createdAt', isGreaterThan: sevenDaysAgo)
    .get();
```

### QA Checklist
- [ ] Verify return window opens on delivery
- [ ] Verify return window closes after 7 days
- [ ] Verify return label generated correctly
- [ ] Verify return shipment tracked
- [ ] Verify QC approval triggers refund
- [ ] Verify refund added to customer wallet
- [ ] Verify order marked as REFUNDED
- [ ] Verify analytics updated with return data

---

## Team 7: Notifications & Messaging

### Setup Checklist
- [ ] Clone latest code from `lib/providers/order_provider.dart`
- [ ] Import NotificationService
- [ ] Set up SMS service (Twilio)
- [ ] Set up push notifications (Firebase)

### Integration Points

#### 1. Listen to Order Status Changes
```dart
// OrderProvider already notifies on status changes
// In your notification service, listen to OrderProvider:

orderProvider.addListener(() {
  if (orderProvider.currentOrder?.status != previousStatus) {
    final order = orderProvider.currentOrder!;
    
    // Send appropriate notification
    sendStatusNotification(order);
  }
});
```

#### 2. Status-Based Notifications
```dart
void sendStatusNotification(OrderModel order) {
  final messages = {
    OrderStatus.confirmed: {
      'title': 'Order Confirmed',
      'body': 'Your order #${order.orderNumber} is being prepared',
      'icon': 'ic_confirmed',
    },
    OrderStatus.processing: {
      'title': 'Order Being Prepared',
      'body': 'Your items are being picked and packed',
      'icon': 'ic_processing',
    },
    OrderStatus.packed: {
      'title': 'Order Ready',
      'body': 'Your order is ready for delivery',
      'icon': 'ic_packed',
    },
    OrderStatus.outForDelivery: {
      'title': 'On the Way',
      'body': 'Your delivery is on the way. Tap for live tracking',
      'icon': 'ic_delivery',
      'tracking_url': generateTrackingUrl(order.id),
    },
    OrderStatus.delivered: {
      'title': 'Delivered',
      'body': 'Your order has been delivered. Rate your experience',
      'icon': 'ic_delivered',
      'action': 'show_rating_dialog',
    },
    OrderStatus.cancelled: {
      'title': 'Order Cancelled',
      'body': 'Your order has been cancelled. Refund initiated.',
      'icon': 'ic_cancelled',
    },
  };
  
  final notification = messages[order.status];
  
  // Send push notification
  sendPushNotification(
    userId: order.customerId,
    title: notification['title'],
    body: notification['body'],
    data: {
      'type': 'order_update',
      'orderId': order.id,
      ...notification,
    },
  );
  
  // Send SMS for major milestones
  if ([OrderStatus.confirmed, OrderStatus.outForDelivery, OrderStatus.delivered]
      .contains(order.status)) {
    sendSMS(
      phone: order.customerPhone,
      message: 'Fufaji: ${notification['body']} #${order.orderNumber}',
    );
  }
}
```

#### 3. Handle Offline Notifications
```dart
// If user offline when status changes:
if (!hasInternet) {
  // Queue notification locally
  await offlineNotificationQueue.add({
    'userId': order.customerId,
    'orderId': order.id,
    'status': order.status.toString(),
    'timestamp': DateTime.now(),
  });
}

// When online, send queued notifications:
Future<void> syncOfflineNotifications() async {
  final queued = await offlineNotificationQueue.getAll();
  
  for (final notification in queued) {
    await sendPushNotification(notification);
    await offlineNotificationQueue.delete(notification.id);
  }
}
```

#### 4. In-App Toast Notifications
```dart
// Show toast in customer app when status changes:
if (order.status.hasChanged(previousStatus)) {
  Flushbar(
    title: 'Order Update',
    message: '${order.status.displayName}: ${order.status.description}',
    duration: Duration(seconds: 5),
    backgroundColor: order.status.color,
    icon: Icon(order.status.icon),
    mainButton: TextButton(
      onPressed: () => navigateToOrderDetail(order.id),
      child: Text('VIEW'),
    ),
  ).show(context);
}
```

#### 5. Email Notifications
```dart
// For important milestones:
if (order.status == OrderStatus.delivered) {
  await sendEmail(
    to: order.customerEmail,
    subject: 'Your order from Fufaji has been delivered!',
    template: 'order_delivered',
    variables: {
      'customerName': order.customerName,
      'orderNumber': order.orderNumber,
      'items': order.items.map((i) => i.productName).join(', '),
      'invoiceUrl': order.invoiceUrl,
      'trackingUrl': generateTrackingUrl(order.id),
    },
  );
}
```

### QA Checklist
- [ ] Verify push notification sent for each status change
- [ ] Verify SMS sent for major milestones
- [ ] Verify in-app toast shown instantly
- [ ] Verify offline notifications queued
- [ ] Verify offline notifications sent when online
- [ ] Verify notification text is clear and actionable
- [ ] Verify tracking link in push works
- [ ] Verify email notifications sent with invoice

---

## Team 8: Mobile App (Customer UI)

### Setup Checklist
- [ ] Clone latest code from `lib/providers/order_provider.dart`
- [ ] Import OrderModel, OrderStatus, OrderProvider
- [ ] Add `provider` package for state management
- [ ] Create screens for order list, detail, tracking

### Integration Points

#### 1. Load Customer Orders
```dart
@override
void initState() {
  super.initState();
  
  // Load orders for current customer
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<OrderProvider>().loadCustomerOrders(
      customerId: AuthProvider.instance.currentUser!.id,
    );
  });
}
```

#### 2. Display Order List
```dart
Consumer<OrderProvider>(
  builder: (context, orderProvider, _) {
    if (orderProvider.isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (orderProvider.orders.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80),
            SizedBox(height: 16),
            Text('No orders yet', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.push('/shop'),
              child: Text('Start Shopping'),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: orderProvider.orders.length,
      itemBuilder: (context, index) {
        final order = orderProvider.orders[index];
        
        return OrderListTile(
          order: order,
          onTap: () => context.push('/orders/${order.id}'),
        );
      },
    );
  },
)
```

#### 3. Display Order Detail
```dart
@override
void initState() {
  super.initState();
  
  // Listen to single order updates
  context.read<OrderProvider>().listenToOrder(widget.orderId);
}

Consumer<OrderProvider>(
  builder: (context, orderProvider, _) {
    final order = orderProvider.currentOrder;
    if (order == null) return SizedBox();
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header: Order number, status
          Container(
            padding: EdgeInsets.all(16),
            color: order.status.color.withOpacity(0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(order.status.icon, color: order.status.color),
                    SizedBox(width: 8),
                    Text(
                      order.status.displayName,
                      style: TextStyle(
                        color: order.status.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                // Progress bar
                LinearProgressIndicator(
                  value: order.status.progressPercentage / 100,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(order.status.color),
                  minHeight: 8,
                ),
              ],
            ),
          ),
          
          // Timeline
          OrderTimeline(order: order),
          
          // Items
          OrderItemsList(order: order),
          
          // Pricing breakdown
          OrderPricingBreakdown(order: order),
          
          // Actions (cancel, return, etc.)
          OrderActions(order: order),
        ],
      ),
    );
  },
)
```

#### 4. Live Tracking
```dart
Consumer<OrderProvider>(
  builder: (context, orderProvider, _) {
    final order = orderProvider.currentOrder;
    if (order?.status != OrderStatus.outForDelivery) {
      return SizedBox();
    }
    
    return Column(
      children: [
        // Google Maps showing live location
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              order!.liveLocation!.latitude,
              order.liveLocation!.longitude,
            ),
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: MarkerId('delivery_agent'),
              position: LatLng(
                order.liveLocation!.latitude,
                order.liveLocation!.longitude,
              ),
              infoWindow: InfoWindow(
                title: 'Delivery Agent',
                snippet: order.deliveryAgentName,
              ),
            ),
            Marker(
              markerId: MarkerId('destination'),
              position: LatLng(
                order.deliveryAddress.coordinates.latitude,
                order.deliveryAddress.coordinates.longitude,
              ),
              infoWindow: InfoWindow(title: 'Your Location'),
            ),
          },
        ),
        
        SizedBox(height: 16),
        
        // Estimated delivery time
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimated Delivery'),
                SizedBox(height: 8),
                Text(
                  'In approximately 15 minutes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                Text('Delivery Agent'),
                SizedBox(height: 4),
                Text('${order.deliveryAgentName} - ${order.deliveryAgentPhone}'),
              ],
            ),
          ),
        ),
      ],
    );
  },
)
```

#### 5. Cancel Order
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Cancel Order?'),
    content: Text('Are you sure? Refund will be processed.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('KEEP ORDER'),
      ),
      ElevatedButton(
        onPressed: () async {
          final success = await orderProvider.cancelOrder(
            order.id,
            'Customer request',
          );
          
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Order cancelled')),
            );
            Navigator.pop(context);
          }
        },
        child: Text('CANCEL ORDER'),
      ),
    ],
  ),
)
```

#### 6. Request Return
```dart
// Show after delivery window opens:
if (order.canReturn) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Request Return',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: 'Reason for return',
                hintText: 'e.g., Product damaged, Wrong item received',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final success = await orderProvider.requestReturn(
                  order.id,
                  reasonController.text,
                );
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Return requested')),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('REQUEST RETURN'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

#### 7. Rate Order
```dart
// Show after delivery:
if (order.status == OrderStatus.delivered && order.rating == null) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rate Your Order'),
            SizedBox(height: 16),
            RatingBar(
              initialRating: 3,
              minRating: 1,
              itemCount: 5,
              itemBuilder: (context, _) => Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) => selectedRating = rating,
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Comments (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await submitRating(order.id, selectedRating, comment);
                Navigator.pop(context);
              },
              child: Text('SUBMIT RATING'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

### QA Checklist
- [ ] Verify orders load on app launch
- [ ] Verify order list shows all customer orders
- [ ] Verify order detail displays correctly
- [ ] Verify status updates appear instantly
- [ ] Verify timeline shows all status changes
- [ ] Verify live tracking map shows real location
- [ ] Verify ETA updates as delivery progresses
- [ ] Verify cancel button works
- [ ] Verify return button works after delivery
- [ ] Verify rating dialog shows after delivery
- [ ] Verify offline orders queue correctly
- [ ] Verify offline orders synced when online
- [ ] Verify push notifications appear
- [ ] Verify notification taps open correct order

---

## Common Issues & Solutions

### Issue: "Invalid status transition" error
**Cause**: Trying to update order to a status that's not allowed from current status  
**Solution**: Check `OrderStatusEngine` for valid transitions  
**Example**: Can't go from PACKED to PENDING

### Issue: Order not appearing for customer
**Cause**: Query not filtered by customerId  
**Solution**: Always use `getCustomerOrders(customerId)` not `getAllOrders()`

### Issue: Inventory not restored on cancellation
**Cause**: Cancellation happened outside transaction  
**Solution**: Use `repo.cancelOrder()` which handles transaction

### Issue: Timeline entries missing
**Cause**: `updateOrderStatus()` not called  
**Solution**: Always use `repo.updateOrderStatus()` not direct Firestore writes

### Issue: Live tracking not updating
**Cause**: GPS polling interval too long  
**Solution**: Set to 30 seconds or less; use stream instead of polling

### Issue: Push notifications not received
**Cause**: User opted out or token expired  
**Solution**: Check Firebase Messaging logs; refresh token on app start

---

## Support Resources

1. **Implementation Guide**: `ORDER_CORE_IMPLEMENTATION_GUIDE.md`
2. **Code Comments**: JSDoc on all public methods
3. **Unit Tests**: Reference implementations in `order_repository_test.dart`
4. **Example Code**: Provided in sections above
5. **Firebase Console**: Check security rules, indexes, document structure

---

**Last Updated**: June 2026  
**Version**: 1.0  
**Status**: Ready for Integration

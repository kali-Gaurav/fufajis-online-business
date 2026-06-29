# Firebase Quick Start Guide - Fufaji

Fast reference for common Firebase operations.

## Setup (One-time)

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseInitializationService.initialize();
  final cacheService = FirebaseOfflineCacheService();
  await cacheService.initialize();
  runApp(const MyApp());
}
```

## Authentication

### Send OTP
```dart
final auth = FirebasePhoneAuthService();
await auth.sendOTP('+919876543210');
```

### Verify OTP
```dart
final userCredential = await auth.verifyOTP('123456');
final user = userCredential.user;
```

### Get Current User
```dart
final user = auth.getCurrentUser();
final token = await auth.getUserToken(forceRefresh: true);
```

### Logout
```dart
await auth.logout();
```

---

## Firestore Operations

### Create Document
```dart
final firestore = FirestoreDataService();

// Auto-generate ID
final docId = await firestore.addDocument(
  'orders',
  {
    'customerId': userId,
    'totalAmount': 600,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
  },
);

// Or with specific ID
await firestore.setDocument(
  'orders',
  orderId,
  orderData,
);
```

### Read Document
```dart
final order = await firestore.getDocument('orders', orderId);
print(order?['totalAmount']);
```

### Read Collection
```dart
final orders = await firestore.getCollection(
  'orders',
  whereField: 'customerId',
  whereValue: userId,
  orderBy: 'createdAt',
  descending: true,
  limit: 50,
);
```

### Update Document
```dart
await firestore.updateDocument(
  'orders',
  orderId,
  {
    'status': 'delivered',
    'updatedAt': FieldValue.serverTimestamp(),
  },
);
```

### Delete Document
```dart
await firestore.deleteDocument('orders', orderId);
```

### Batch Write (Multiple Documents)
```dart
await firestore.batchWrite({
  'orders/order1': {'status': 'confirmed'},
  'orders/order2': {'status': 'cancelled'},
  'inventory/prod1': {'quantity': 50},
});
```

### Transaction (Atomic Operation)
```dart
await firestore.runTransaction((transaction) async {
  // Create order
  transaction.set(
    FirebaseFirestore.instance.collection('orders').doc(orderId),
    orderData,
  );
  
  // Deduct inventory
  transaction.update(
    FirebaseFirestore.instance.collection('inventory').doc(productId),
    {'quantity': FieldValue.increment(-2)},
  );
});
```

### Real-time Listener (Single Document)
```dart
firestore.streamDocument('orders', orderId).listen((order) {
  print('Order updated: $order');
});
```

### Real-time Listener (Collection)
```dart
firestore.streamCollection(
  'orders',
  whereField: 'customerId',
  whereValue: userId,
).listen((orders) {
  setState(() => userOrders = orders);
});
```

### Increment Field
```dart
await firestore.incrementField('wallet', userId, 'balance', 100);
```

### Array Operations
```dart
// Add to array
await firestore.addToArrayField('orders', orderId, 'tags', 'urgent');

// Remove from array
await firestore.removeFromArrayField('orders', orderId, 'tags', 'urgent');
```

---

## Repository Pattern (Recommended)

```dart
// Use repository for business logic + caching
final repo = FirebaseRepository(
  firestoreService: _firestore,
  cacheService: _cache,
);

// Create order (auto caching + validation)
final orderId = await repo.createOrder({
  'customerId': userId,
  'items': [...],
  'totalAmount': 600,
});

// Get user profile (with cache)
final profile = await repo.getUserProfile(userId);

// Stream orders (real-time)
repo.streamUserOrders(userId).listen((orders) {
  print('Orders: $orders');
});
```

---

## Caching (Offline Support)

### Save to Cache
```dart
final cache = FirebaseOfflineCacheService();
await cache.initialize();

// Cache with TTL
await cache.save(
  'user_${userId}',
  userData,
  ttl: Duration(hours: 24),
);

// Cache Firestore document
await cache.cacheDocument('orders', orderId, orderData);
```

### Get from Cache
```dart
// Returns null if expired
final cached = cache.get('user_${userId}');

// Get cached document
final order = cache.getCachedDocument('orders', orderId);
```

### Queue Offline Actions
```dart
// Queue action when offline
await cache.queueOfflineAction(
  action: 'create_order',
  data: orderData,
  timestamp: DateTime.now(),
);

// When back online, get pending actions
final pending = cache.getPendingOfflineActions();

// Mark as synced
await cache.markActionSynced(actionId);
```

---

## Common Patterns

### Create & Update with Timestamp
```dart
await firestore.setDocument('orders', orderId, {
  ...orderData,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
}, merge: true);
```

### Increment Counter
```dart
await firestore.incrementField(
  'analytics',
  'order_count',
  'value',
  1,
);
```

### Delete Multiple Documents
```dart
final docs = await firestore.getCollection('tempData');
for (final doc in docs) {
  await firestore.deleteDocument('tempData', doc['id']);
}
```

### Query with Multiple Filters
```dart
final results = await firestore.getCollection(
  'orders',
  multipleWhere: [
    {'field': 'customerId', 'value': userId, 'operator': '=='},
    {'field': 'status', 'value': 'delivered', 'operator': '=='},
    {'field': 'createdAt', 'value': weekAgoDate, 'operator': '>='},
  ],
  orderBy: 'createdAt',
  descending: true,
);
```

### Paginated Query
```dart
int pageSize = 20;
var lastDoc;

Future<List<Map>> getNextPage() async {
  var query = FirebaseFirestore.instance
      .collection('orders')
      .limit(pageSize + 1);
  
  if (lastDoc != null) {
    query = query.startAfterDocument(lastDoc);
  }
  
  final docs = await query.get();
  lastDoc = docs.docs.last;
  return docs.docs.map((d) => d.data()).toList();
}
```

---

## Error Handling

```dart
try {
  final order = await firestore.getDocument('orders', orderId);
} on FirebaseException catch (e) {
  print('Firebase error: ${e.code} - ${e.message}');
} catch (e) {
  print('Error: $e');
}
```

---

## Security Rules (Quick Reference)

```javascript
// Public read (no auth needed)
allow read: if true;

// Owner only
allow read: if request.auth.uid == resource.data.userId;

// Specific role
allow write: if request.auth.token.admin == true;

// Admin or owner
allow update: if request.auth.token.admin == true
           || request.auth.uid == resource.data.userId;

// Backend only (deny client writes)
allow write: if false;

// With additional conditions
allow update: if request.auth.uid == resource.data.userId
           && !('role' in request.resource.data);
```

---

## Monitoring

### Check Cache Stats
```dart
final stats = cache.getCacheStats();
print('Cache size: ${stats['cacheBoxSize']}');
print('Pending actions: ${stats['pendingActions']}');
```

### Clean Expired Cache
```dart
await cache.cleanupExpiredEntries();
```

### Run Integration Tests
```dart
final helper = FirebaseIntegrationTestHelper(
  firestoreService: _firestore,
);
final results = await helper.runAllTests();
```

---

## Tips

1. **Always use repository pattern** for consistency
2. **Cache frequently accessed data** to reduce read costs
3. **Batch writes** when possible (cheaper)
4. **Use transactions** for multi-document operations
5. **Set up indexes** for complex queries
6. **Test security rules** before production
7. **Monitor Firestore quota** in Firebase Console
8. **Use real-time listeners** sparingly
9. **Clean up listeners** when widget disposes
10. **Always handle errors** with try-catch

---

## Common Firestore Costs

| Operation | Cost |
|-----------|------|
| Document read | 1 read |
| Document write | 1 write |
| Document delete | 1 write |
| Query | 1+ reads (per doc) |
| Real-time listener | 1 read per change |
| Transaction | Multiple operations |

**Reduce costs:**
- Use batch writes
- Cache data locally
- Paginate large queries
- Use transactions for atomicity

---

## Debug Mode

```dart
// Enable Firestore logging
FirebaseFirestore.setLoggingEnabled(true);

// Check Firebase status
final status = FirebaseInitializationService.getStatus();
print('Firebase status: $status');
```

---

**For detailed docs:** See `FIREBASE_INTEGRATION_COMPLETE.md`

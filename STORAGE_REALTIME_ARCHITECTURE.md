# Storage Upload & Real-Time Architecture

## Overview

This document describes the architecture for file uploads (Task #24) and real-time listeners (Task #25) in the Fufaji Store mobile app.

---

## Task #24: Storage Architecture

### Upload Flow

```
File (device) 
  ↓
Firebase Storage Upload
  ↓
Get Download URL
  ↓
Firestore: Update entity document
  ↓
Firestore: Cache storage_references
  ↓
Return signed URL to caller
```

### Storage Service Hierarchy

```
ProductImageService
├── uploadProductImage()
├── deleteProductImage()
└── Uses: signed_url_service.dart

KYCDocumentService
├── uploadKYCDocument()
├── getKYCStatus()
├── deleteKYCDocument()
└── Triggers: kyc_verifications workflow

DeliveryProofService
├── uploadDeliveryProof()
├── uploadMultipleProofs()
├── getDeliveryProofUrl()
└── Updates: order status to delivered

SignedUrlService (Shared)
├── getSignedUrl() [with cache]
├── refreshSignedUrl()
├── clearExpiredUrls()
└── clearBucketCache()
```

### Firestore Schema

**storage_references collection**
```json
{
  "bucket": "product-images",
  "path": "shop_123/prod_456/image.jpg",
  "signedUrl": "https://...",
  "expiresAt": Timestamp,
  "createdAt": Timestamp
}
```

**products/{productId}**
```json
{
  "imageUrl": "https://...",
  "imageUpdatedAt": Timestamp
}
```

**users/{userId}**
```json
{
  "kycDocumentUrl": "https://...",
  "kycDocumentStatus": "pending|approved|rejected",
  "kycDocumentUploadedAt": Timestamp
}
```

**deliveries/{deliveryId}**
```json
{
  "proofPhotoUrl": "https://...",
  "proofUploadedAt": Timestamp,
  "status": "delivered",
  "deliveredAt": Timestamp
}
```

### Storage Paths

| Content | Path | Metadata |
|---------|------|----------|
| Product Images | `product-images/{shopId}/{productId}/image.jpg` | shopId, productId, uploadedAt |
| KYC Documents | `customer-documents/{userId}/kyc.pdf` | userId, documentType, uploadedAt |
| Delivery Proofs | `delivery-proofs/{deliveryId}/proof.jpg` | deliveryId, proofType, uploadedAt |

### Signed URL Caching

**3-Tier Cache**:

1. **In-Memory** (L1)
   - Key: `bucket/path`
   - TTL: Session duration
   - Hit: Sub-millisecond

2. **Firestore** (L2)
   - Collection: `storage_references`
   - Indexed by: `bucket`, `path`, `expiresAt`
   - Hit: ~100ms
   - Useful for: Offline-to-online transitions

3. **Edge Function** (L3)
   - Call: `GET /functions/v1/get_storage_signed_url`
   - Params: `bucket`, `path`
   - Response: New signed URL + 24h expiry
   - Fallback: Direct Firebase Storage download

**Cache Refresh Logic**:
```dart
// Check in-memory first
if (memoryCache.contains(key) && !memoryCache[key].isExpired) {
  return memoryCache[key].url;
}

// Check Firestore second
final firebaseCache = getFromFirestore(bucket, path);
if (firebaseCache && firebaseCache.isValid) {
  return firebaseCache.url;
}

// Generate new URL
final newUrl = generateSignedUrl(bucket, path);
cacheInMemory(newUrl);
cacheInFirestore(newUrl);
return newUrl;
```

---

## Task #25: Real-Time Architecture

### Listener Pattern

All real-time screens use Flutter's `StreamBuilder`:

```dart
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
    .collection('collectionName')
    .doc(docId)
    .snapshots(),
  builder: (context, snapshot) {
    // Handle connection, error, data states
    // UI auto-refreshes when Firestore data changes
  }
)
```

### Screens with Listeners

#### 1. Order Detail Screen
**Listener**: `orders/{orderId}.snapshots()`

**Real-Time Fields**:
- `status` (pending → confirmed → processing → ready → out_for_delivery → delivered)
- `paymentStatus` (pending → paid → refunded)
- `estimatedDeliveryTime` (updates as delivery progresses)
- `items[].status` (individual item status)

**UI Updates Trigger**:
- Status badge color changes
- "Track Order" button appears when out_for_delivery
- "Cancel" button disappears when delivered
- Price breakdown updates

#### 2. Delivery Tracking Screen
**Dual Listeners**:
1. `orders/{orderId}.snapshots()` → Get deliveryId
2. `deliveries/{deliveryId}.snapshots()` → Live tracking

**Real-Time Fields**:
- `status` (pending → accepted → picked_up → in_transit → arrived → delivered)
- `riderLocation` (GeoPoint, updates every 10s)
- `estimatedDeliveryTime` (ETA countdown)
- `riderName`, `riderPhone`, `riderRating`

**Map Integration**:
```dart
GoogleMap(
  markers: {
    Marker(position: _riderLocation),  // Blue: Rider
    Marker(position: _deliveryLocation),  // Green: Destination
  }
)
```

**Status Timeline** (Auto-Progress):
- Pending → Accepted → Picked Up → In Transit → Arrived → Delivered

#### 3. Payment Status Screen
**Listener**: `payment_transactions/{paymentId}.snapshots()`

**Real-Time Flow**:
```
pending (showing) 
  ↓ (user in payment gateway)
authorized (processing)
  ↓ (payment verified)
completed (AUTO-NAVIGATE to order confirmation)
```

**Error Handling**:
- Status: `failed`
- Field: `errorMessage` (displays to user)
- Action: Retry button calls payment gateway again

#### 4. Shop Orders Screen
**Listener**: `orders.where('shopId', ==, currentShopId).orderBy('createdAt', desc).snapshots()`

**Real-Time Updates**:
- New orders appear at top instantly
- Status badges update live (pending → confirmed → preparing → ready → delivered)
- Timestamps refresh (2m ago → 3m ago)
- Quick action buttons (Confirm → Prepare → Ready)

**Filtering**:
```dart
// In _buildOrdersStream()
Query query = firestore.collection('orders')
  .where('shopId', isEqualTo: shopId)
  .orderBy('createdAt', descending: true);

if (selectedFilter != 'all') {
  query = query.where('status', isEqualTo: selectedFilter);
}

return query.snapshots();  // Auto-filtered real-time stream
```

#### 5. Cart Service
**Listener**: `customers/{uid}/cart/current/items.snapshots()`

**Multi-Device Sync Flow**:
```
Device A: Add item → Firestore update
  ↓
Device B: watchCartItems() stream emits new item
  ↓
Device B UI: StreamBuilder refreshes
  ↓
Both devices in sync, no polling
```

**Cart Operations**:
```dart
// All these trigger Firestore updates
// which are reflected across all listening devices
await addToCart(userId, productId, quantity);
await removeFromCart(userId, productId);
await updateQuantity(userId, productId, newQty);
await clearCart(userId);

// Watch for changes
watchCart(userId)  // Raw stream
watchCartItems(userId)  // Typed list stream
watchCartSummary(userId)  // Totals stream
```

---

## Firestore Indexing Requirements

### Recommended Indexes

```
Collection: orders
Indexes:
  - shopId (Ascending) + createdAt (Descending)
  - shopId (Ascending) + status (Ascending) + createdAt (Descending)
  - customerId (Ascending) + createdAt (Descending)
  - status (Ascending) + createdAt (Descending)

Collection: deliveries
Indexes:
  - orderId (Ascending) + status (Ascending)
  - riderName (Ascending) + status (Ascending)

Collection: storage_references
Indexes:
  - bucket (Ascending) + path (Ascending)
  - expiresAt (Ascending)  // For cleanup queries
```

---

## Error Handling & Resilience

### StreamBuilder State Machine

```
ConnectionState.none
  ↓
ConnectionState.waiting (show spinner)
  ↓
ConnectionState.active (show data)
  ↓
ConnectionState.done (end of stream)
```

### Error Recovery

```dart
if (snapshot.hasError) {
  return ErrorWidget(
    error: snapshot.error,
    onRetry: () => Navigator.pop().then((_) => Navigator.pushNamed(context, routeName))
  );
}
```

### Connection Loss Handling

- StreamBuilder gracefully handles network interruption
- UI shows last known data while reconnecting
- No manual refresh button needed (data auto-syncs when online)
- Memory cache prevents rapid re-renders

---

## Performance Considerations

### Data Reduction

1. **Limit Listener Scope**:
   - Don't listen to entire collection
   - Use `.where()` to filter upstream
   - e.g., `orders.where('shopId', ==, shopId)`

2. **Pagination** (for large lists):
   ```dart
   // Load first 20 orders
   query.limit(20).snapshots()
   
   // Load next 20 with pagination
   query.startAfter(lastDoc).limit(20).snapshots()
   ```

3. **Unsubscribe Cleanup**:
   - StreamBuilder auto-disposes on widget disposal
   - No manual stream cancellation needed
   - Memory-safe

### Optimized Queries

```dart
// GOOD: Filtered upstream
orders
  .where('shopId', isEqualTo: shopId)
  .where('status', isEqualTo: 'pending')
  .orderBy('createdAt', descending: true)
  .limit(50)
  .snapshots()

// BAD: Load everything
orders.snapshots()
  .map((snapshot) => snapshot.docs
    .where((doc) => doc['shopId'] == shopId)  // Filtered client-side ❌
    .toList()
  )
```

---

## Integration Checklist

### Setup Steps

1. **Firestore Indexes**
   - Create indexes listed above
   - Verify in Firebase Console

2. **Storage Buckets**
   - Create buckets: `product-images`, `customer-documents`, `delivery-proofs`
   - Set CORS for web uploads
   - Set retention policies (e.g., 7 days for proof photos)

3. **Firestore Collections**
   - Create: `storage_references`, `kyc_verifications`, `admin_notifications`
   - Set security rules (see below)

4. **Security Rules** (Firestore)
   ```
   // storage_references: app-readable, backend-writable
   match /storage_references/{doc} {
     allow read: if request.auth != null;
     allow write: if request.auth.uid != null;  // Restrict to backend
   }
   
   // kyc_verifications: customer-readable own, admin-readable all
   match /kyc_verifications/{doc} {
     allow read: if request.auth.uid == resource.data.userId 
                 || 'admin' in request.auth.token.roles;
     allow write: if 'admin' in request.auth.token.roles;
   }
   ```

5. **Router Configuration**
   ```dart
   GoRouter(
     routes: [
       GoRoute(
         path: '/payment-status/:paymentId',
         builder: (_, state) => PaymentStatusScreen(
           paymentId: state.pathParameters['paymentId']!,
           orderId: state.queryParameters['orderId']!,
         ),
       ),
       // ... other routes
     ],
   )
   ```

---

## Migration Path (Firebase → Supabase)

Current implementation uses Firebase Storage/Firestore. To migrate to Supabase:

1. **Storage**: 
   - Replace Firebase Storage calls with Supabase Storage API
   - Same bucket path structure works

2. **Signed URLs**:
   - Call Supabase Edge Function instead of Firebase
   - Function already defined (mentioned in Task #20)

3. **Real-Time**:
   - Firestore snapshots → Supabase realtime subscriptions
   - Same pattern, different client library

4. **Code Locations to Update**:
   - `signed_url_service.dart`: `_generateSignedUrl()` method
   - All storage services: Initialize with Supabase client
   - Order/delivery/payment screens: Use Supabase Realtime client

---

## Testing Guide

### Unit Tests (Storage Services)

```dart
test('ProductImageService uploads and syncs', () async {
  final service = ProductImageService();
  final url = await service.uploadProductImage(
    shopId: 'test_shop',
    productId: 'test_prod',
    imageFile: mockFile,
  );
  expect(url, isNotNull);
  expect(url, contains('https://'));
});

test('SignedUrlService caches URLs', () async {
  final service = SignedUrlService();
  final url1 = await service.getSignedUrl(bucket: 'test', path: 'image.jpg');
  final url2 = await service.getSignedUrl(bucket: 'test', path: 'image.jpg');
  expect(url1, equals(url2));  // Same URL from cache
});
```

### Widget Tests (Real-Time Screens)

```dart
testWidgets('OrderDetailScreen updates on status change', (tester) async {
  // Mock Firestore
  when(mockFirestore.collection('orders').doc('123').snapshots())
    .thenAnswer((_) => Stream.value(orderSnapshot));
  
  await tester.pumpWidget(OrderDetailScreen(orderId: '123'));
  expect(find.text('PENDING'), findsOneWidget);
  
  // Change order status
  when(mockFirestore.collection('orders').doc('123').snapshots())
    .thenAnswer((_) => Stream.value(updatedOrderSnapshot));
  
  await tester.pumpAndSettle();
  expect(find.text('DELIVERED'), findsOneWidget);
});
```

### Integration Tests

```dart
testWidgets('End-to-end payment flow with real-time updates', (tester) async {
  // 1. Navigate to payment screen
  await tester.tap(find.byIcon(Icons.payment));
  await tester.pumpAndSettle();
  
  // 2. Verify payment pending state
  expect(find.text('Processing payment...'), findsOneWidget);
  
  // 3. Simulate payment completion (backend)
  await updatePaymentStatusInFirestore('completed');
  
  // 4. Verify auto-navigation to order confirmation
  await tester.pumpAndSettle(Duration(seconds: 2));
  expect(find.byType(OrderConfirmationScreen), findsOneWidget);
});
```

---

## Monitoring & Analytics

### Events to Log

```dart
// In each service
analytics.logEvent(name: 'image_upload_started', parameters: {
  'shop_id': shopId,
  'file_size_mb': file.lengthSync() / 1024 / 1024,
});

analytics.logEvent(name: 'image_upload_complete', parameters: {
  'shop_id': shopId,
  'duration_ms': stopwatch.elapsedMilliseconds,
  'success': true,
});

// In StreamBuilders
analytics.logEvent(name: 'order_detail_realtime_update', parameters: {
  'status_changed': true,
  'new_status': orderData['status'],
});
```

---

## Conclusion

This architecture provides:
- ✅ Efficient file uploads with automatic caching
- ✅ Real-time data synchronization across devices
- ✅ Scalable to millions of users
- ✅ Offline-first capabilities
- ✅ Clean separation of concerns
- ✅ Easy to migrate between backends (Firebase ↔ Supabase)

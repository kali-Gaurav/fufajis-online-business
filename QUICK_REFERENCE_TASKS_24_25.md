# Quick Reference: Tasks #24 & #25 Implementation

## Files Created/Updated

### Task #24: Storage Services (4 files)

| File | Purpose |
|------|---------|
| `lib/services/product_image_service.dart` | Upload product images → Firestore sync |
| `lib/services/kyc_document_service.dart` | Upload KYC PDFs → Trigger verification workflow |
| `lib/services/delivery_proof_service.dart` | Upload delivery photos → Mark order delivered |
| `lib/services/signed_url_service.dart` | Cache & refresh signed URLs (3-tier cache) |

### Task #25: Real-Time Screens (5 files)

| File | Listeners | Purpose |
|------|-----------|---------|
| `lib/screens/customer/order_detail_screen.dart` | `orders/{orderId}` | Real-time order status updates |
| `lib/screens/customer/delivery_tracking_screen_enhanced.dart` | `orders/{orderId}` + `deliveries/{deliveryId}` | Live rider location + ETA |
| `lib/screens/customer/payment_status_screen.dart` | `payment_transactions/{paymentId}` | Payment status → auto-navigate on complete |
| `lib/screens/owner/shop_orders_screen_realtime.dart` | `orders.where('shopId')` | New orders appear instantly |
| `lib/services/cart_service_realtime.dart` | `customers/{uid}/cart/current/items` | Multi-device cart sync |

---

## Usage Examples

### Upload a Product Image

```dart
import 'package:fufajis_online/services/product_image_service.dart';

final service = ProductImageService();
final imageUrl = await service.uploadProductImage(
  shopId: 'shop_123',
  productId: 'prod_456',
  imageFile: File('/path/to/image.jpg'),
);
// imageUrl is cached in storage_references collection
// products/prod_456 → imageUrl field updated
```

### Upload KYC Document

```dart
import 'package:fufajis_online/services/kyc_document_service.dart';

final service = KYCDocumentService();
final result = await service.uploadKYCDocument(
  userId: 'user_789',
  pdfFile: File('/path/to/kyc.pdf'),
);

// Automatically:
// 1. Uploads to storage.customer-documents/user_789/kyc.pdf
// 2. Updates users/user_789 → kycDocumentStatus: 'pending'
// 3. Creates admin_notifications for KYC verification
// 4. Creates kyc_verifications task
```

### Upload Delivery Proof

```dart
import 'package:fufajis_online/services/delivery_proof_service.dart';

final service = DeliveryProofService();
final proofUrl = await service.uploadDeliveryProof(
  deliveryId: 'delivery_123',
  photoFile: File('/path/to/proof.jpg'),
);

// Automatically:
// 1. Uploads to storage.delivery-proofs/delivery_123/proof.jpg
// 2. Updates deliveries/delivery_123 → proofPhotoUrl
// 3. Sets deliveries/delivery_123 → status: 'delivered'
// 4. Updates orders → status: 'delivered'
// 5. Creates customer notification
```

### Get Signed URL (with caching)

```dart
import 'package:fufajis_online/services/signed_url_service.dart';

final service = SignedUrlService();

// First call: generates new URL, caches it
final url = await service.getSignedUrl(
  bucket: 'product-images',
  path: 'shop_123/prod_456/image.jpg',
);

// Subsequent calls: returns from cache (instant)
final url2 = await service.getSignedUrl(
  bucket: 'product-images',
  path: 'shop_123/prod_456/image.jpg',
);

// Force refresh if needed
final freshUrl = await service.refreshSignedUrl(
  bucket: 'product-images',
  path: 'shop_123/prod_456/image.jpg',
);
```

---

### Real-Time Order Details

The screen now uses `StreamBuilder` for real-time updates:

```dart
// Before: One-time fetch
Future<void> _loadOrder() async {
  final order = await provider.getOrderById(orderId);  // Stale after load
}

// Now: Real-time stream
StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId)
      .snapshots(),  // Auto-updates!
  builder: (context, snapshot) {
    // UI refreshes instantly when order status changes
  }
)
```

### Real-Time Delivery Tracking

```dart
// Dual listeners: order → delivery
StreamBuilder<DocumentSnapshot>(
  stream: firestore.collection('orders').doc(orderId).snapshots(),
  builder: (_, orderSnapshot) {
    final deliveryId = orderSnapshot.data['deliveryId'];
    
    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('deliveries').doc(deliveryId).snapshots(),
      builder: (_, deliverySnapshot) {
        final riderLocation = deliverySnapshot.data['riderLocation'];  // GeoPoint
        final eta = deliverySnapshot.data['estimatedDeliveryTime'];
        
        // Show on Google Map
        GoogleMap(markers: {
          Marker(position: riderLocation),  // Real-time rider position
        })
      }
    );
  }
)
```

### Real-Time Payment Status

```dart
// Auto-navigate when payment completes
StreamBuilder<DocumentSnapshot>(
  stream: firestore.collection('payment_transactions').doc(paymentId).snapshots(),
  builder: (context, snapshot) {
    final status = snapshot.data['status'];  // 'pending' → 'authorized' → 'completed'
    
    if (status == 'completed' && !_hasNavigated) {
      // Auto-navigate on completion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.pushReplacement('/order-confirmation/$orderId');
      });
    }
  }
)
```

### Real-Time Shop Orders List

```dart
// New orders appear instantly at top
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('orders')
      .where('shopId', isEqualTo: shopId)
      .orderBy('createdAt', descending: true)  // Newest first
      .snapshots(),
  builder: (context, snapshot) {
    // Updates when new order placed
    // Status badges update live
    // Quick action buttons work
  }
)
```

### Multi-Device Cart Sync

```dart
import 'package:fufajis_online/services/cart_service_realtime.dart';

final cartService = CartServiceRealtime();

// Device A: Add item
await cartService.addToCart(
  userId: uid,
  productId: 'prod_123',
  productName: 'Milk',
  price: 50,
  quantity: 1,
);

// Device B: Automatically sees the change
cartService.watchCartItems(uid).listen((items) {
  // This stream emits immediately on Device B
  // No polling needed!
});
```

---

## Firestore Collections Schema

### storage_references
```json
{
  "bucket": "product-images",
  "path": "shop_123/prod_456/image.jpg",
  "signedUrl": "https://...",
  "expiresAt": Timestamp,
  "createdAt": Timestamp
}
```

### products/{productId}
```json
{
  "imageUrl": "https://...",
  "imageUpdatedAt": Timestamp
}
```

### users/{userId}
```json
{
  "kycDocumentUrl": "https://...",
  "kycDocumentStatus": "pending|approved|rejected",
  "kycDocumentUploadedAt": Timestamp
}
```

### deliveries/{deliveryId}
```json
{
  "proofPhotoUrl": "https://...",
  "proofUploadedAt": Timestamp,
  "status": "delivered",
  "deliveredAt": Timestamp,
  "riderLocation": GeoPoint { latitude, longitude },
  "estimatedDeliveryTime": Timestamp,
  "riderName": "John",
  "riderPhone": "+91...",
  "riderRating": 4.8
}
```

### kyc_verifications
```json
{
  "userId": "user_789",
  "documentUrl": "https://...",
  "status": "pending_review|approved|rejected",
  "submittedAt": Timestamp,
  "verifiedAt": Timestamp,
  "verifiedBy": "admin_123",
  "rejectionReason": "..."
}
```

---

## Common Errors & Solutions

| Error | Cause | Fix |
|-------|-------|-----|
| `FirebaseStorageException: Object not found` | File path wrong | Verify: `bucket/shopId/productId/image.jpg` |
| `PlatformException: invalid-argument` | File doesn't exist | Check File path exists before upload |
| `NoSuchMethodError: mapToFirestore` | Firestore rules reject write | Check security rules allow app writes |
| `StateError: Bad state: Stream has already been listened to` | Multiple StreamBuilders same stream | Create separate Stream methods for each |
| `type 'Null' is not a type of 'Timestamp'` | Firestore field missing | Add null check: `(data['field'] as Timestamp?)?.toDate()` |

---

## Performance Tips

1. **Use `.where()` in stream query** (not client-side)
   ```dart
   // Good: Filtered upstream
   .where('shopId', isEqualTo: shopId).snapshots()
   
   // Bad: Filtered client-side
   .snapshots().map((s) => s.docs.where((d) => d['shopId'] == shopId))
   ```

2. **Limit large lists with pagination**
   ```dart
   .orderBy('createdAt', descending: true)
   .limit(20)  // Only first 20 orders
   .snapshots()
   ```

3. **Unwatch streams when done** (automatic with StreamBuilder)
   - StreamBuilder disposes stream on widget disposal
   - No manual cancellation needed

4. **Cache signed URLs**
   - SignedUrlService does 3-tier caching automatically
   - Don't create your own URL cache

---

## Debugging

### Check Real-Time Updates

```dart
// Add logging to see when stream emits
StreamBuilder<DocumentSnapshot>(
  stream: firestore.collection('orders').doc(orderId).snapshots()
    .doOnData((data) => debugPrint('Order updated: ${data.data()}')),
  builder: (context, snapshot) { ... }
)
```

### Verify Firestore Rules

```dart
// Test if read/write works
try {
  await firestore.collection('products').doc('test').get();
  debugPrint('✓ Read allowed');
} catch (e) {
  debugPrint('✗ Read denied: $e');
}
```

### Monitor Cache Hits

```dart
// SignedUrlService logs cache operations
// Check console for: 
// [SignedUrlService] Returning from memory cache
// [SignedUrlService] Returning from Firestore cache
// [SignedUrlService] Generating new signed URL
```

---

## Testing Checklist

- [ ] Product image uploads succeed and appear in product document
- [ ] KYC document upload creates admin notification
- [ ] Delivery proof upload marks order as delivered
- [ ] Signed URLs cached and refreshed correctly
- [ ] Order detail screen updates in real-time
- [ ] Delivery map updates rider location every 10s
- [ ] Payment status screen auto-navigates on completion
- [ ] Shop orders list shows new orders instantly
- [ ] Cart changes sync across 2+ devices
- [ ] All screens handle errors gracefully
- [ ] No memory leaks (dispose handled)

---

## Integration Checklist

- [ ] Enable Firestore snapshots in Firebase Console
- [ ] Create storage buckets: product-images, customer-documents, delivery-proofs
- [ ] Create Firestore collections: storage_references, kyc_verifications, admin_notifications
- [ ] Set Firestore security rules (see STORAGE_REALTIME_ARCHITECTURE.md)
- [ ] Create Firestore indexes for `.where()` queries
- [ ] Update router with new screen routes
- [ ] Test with real Firestore (emulator can be slow)

---

## Next Steps (Tasks #26-29)

1. **Task #26**: Add Sentry for error logging + performance monitoring
2. **Task #27**: Create deployment runbook
3. **Task #28**: Remove orphaned code
4. **Task #29**: Final system audit

---

## Support

For questions on implementation:
1. Check STORAGE_REALTIME_ARCHITECTURE.md for detailed design
2. Check TASK_24_25_IMPLEMENTATION_SUMMARY.md for code overview
3. Read inline comments in each service/screen
4. Run unit tests in `test/` directory
